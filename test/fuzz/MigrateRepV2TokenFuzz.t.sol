// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import {Test} from "forge-std/Test.sol";

import {MigrateRepV2Token} from "../../src/MigrateRepV2Token.sol";

/// @dev Focused property tests for project-specific behavior and its interaction with the
///      inherited ERC-20. OpenZeppelin already fuzzes its own internals; these do not.
contract MigrateRepV2TokenFuzz is Test {
    MigrateRepV2Token internal token;

    address internal constant DISTRIBUTOR = address(0xD1571B);
    uint256 internal constant ONE = 1 ether;
    uint256 internal constant CAP = 1000;

    function setUp() public {
        token = new MigrateRepV2Token(DISTRIBUTOR, CAP);
    }

    /// @dev Lowest generated recipient address, above the precompile range.
    uint160 internal constant RECIPIENT_BASE = uint160(0x10000000);

    /// @dev Width of one seed's disjoint address block.
    uint160 internal constant SEED_STRIDE = uint160(1_000_000);

    /// @dev Deterministic recipients that are unique by construction (consecutive integers in a
    ///      per-seed block) and never address(0). `forbidden` — the token under test — is skipped
    ///      explicitly, so no property depends on an address collision being unlikely.
    function _uniqueExcluding(uint256 n, uint256 seed, address forbidden) internal pure returns (address[] memory a) {
        require(n <= SEED_STRIDE, "seed block too small");
        a = new address[](n);
        // Confine the seed to a block index so a fuzzed seed cannot overflow into another range.
        uint160 next = RECIPIENT_BASE + uint160(seed % 1_000_000) * SEED_STRIDE;
        for (uint256 i = 0; i < n; ++i) {
            while (next == 0 || address(next) == forbidden) {
                ++next;
            }
            a[i] = address(next);
            ++next;
        }
    }

    function _unique(uint256 n, uint256 seed) internal view returns (address[] memory a) {
        a = _uniqueExcluding(n, seed, address(token));
    }

    function _distribute(address[] memory a) internal {
        vm.prank(DISTRIBUTOR);
        token.distribute(a);
    }

    /// @dev A transfer moves value without changing total supply.
    function testFuzz_transfer_conserves_supply(address to, uint256 amount) public {
        vm.assume(to != address(0));
        address alice = address(0xA11CE);
        vm.assume(to != alice);

        address[] memory r = new address[](1);
        r[0] = alice;
        _distribute(r);

        amount = bound(amount, 0, ONE);
        uint256 supplyBefore = token.totalSupply();
        uint256 toBefore = token.balanceOf(to);

        vm.prank(alice);
        assertTrue(token.transfer(to, amount));

        assertEq(token.balanceOf(alice), ONE - amount);
        assertEq(token.balanceOf(to), toBefore + amount);
        assertEq(token.totalSupply(), supplyBefore);
        assertEq(token.totalSupply(), token.maximumSupply());
    }

    /// @dev approve + transferFrom respects allowance accounting (finite and infinite).
    function testFuzz_approve_and_transferFrom(uint256 approval, uint256 amount) public {
        address alice = address(0xA11CE);
        address bob = address(0xB0B);

        address[] memory r = new address[](1);
        r[0] = alice;
        _distribute(r);

        vm.prank(alice);
        token.approve(bob, approval);

        uint256 cappedByBalance = approval < ONE ? approval : ONE;
        amount = bound(amount, 0, cappedByBalance);

        vm.prank(bob);
        assertTrue(token.transferFrom(alice, bob, amount));

        assertEq(token.balanceOf(bob), amount);
        assertEq(token.balanceOf(alice), ONE - amount);
        if (approval == type(uint256).max) {
            assertEq(token.allowance(alice, bob), type(uint256).max);
        } else {
            assertEq(token.allowance(alice, bob), approval - amount);
        }
    }

    /// @dev Distributing n unique recipients gives each exactly one token and keeps exact accounting.
    function testFuzz_distribution_cap_accounting(uint256 n, uint256 seed) public {
        n = bound(n, 1, token.MAX_BATCH_SIZE());
        address[] memory r = _unique(n, seed);
        _distribute(r);

        assertEq(token.totalInitialRecipients(), n);
        assertLe(token.totalInitialRecipients(), token.recipientCap());
        assertEq(token.balanceOf(address(token)), (CAP - n) * ONE);
        assertEq(token.totalSupply(), token.maximumSupply());
        for (uint256 i = 0; i < n; ++i) {
            assertEq(token.balanceOf(r[i]), ONE);
            assertTrue(token.wasInitialRecipient(r[i]));
        }
    }

    /// @dev Reserve decreases by exactly one unit per successful recipient.
    function testFuzz_reserve_decrease_per_distribution(uint256 n, uint256 seed) public {
        n = bound(n, 1, token.MAX_BATCH_SIZE());
        uint256 before = token.balanceOf(address(token));
        _distribute(_unique(n, seed));
        assertEq(token.balanceOf(address(token)), before - n * ONE);
    }

    /// @dev Initial-recipient history is permanent, even after moving the token away.
    function testFuzz_permanent_recipient_history(address who, address to) public {
        vm.assume(who != address(0) && to != address(0) && who != to);
        vm.assume(who != address(token) && to != address(token));

        address[] memory r = new address[](1);
        r[0] = who;
        _distribute(r);
        assertTrue(token.wasInitialRecipient(who));

        vm.prank(who);
        token.transfer(to, ONE);
        assertTrue(token.wasInitialRecipient(who)); // unchanged by transfer

        // A prior initial recipient can never be an initial recipient again.
        address[] memory again = new address[](1);
        again[0] = who;
        vm.prank(DISTRIBUTOR);
        vm.expectRevert(abi.encodeWithSelector(MigrateRepV2Token.RecipientAlreadyDistributed.selector, who));
        token.distribute(again);
    }

    /// @dev A zero recipient anywhere in the batch reverts the entire call with no state change.
    function testFuzz_atomic_failure(uint256 n, uint256 badIndex, uint256 seed) public {
        n = bound(n, 1, 20);
        badIndex = bound(badIndex, 0, n - 1);

        address[] memory r = _unique(n, seed);
        r[badIndex] = address(0);

        uint256 recipientsBefore = token.totalInitialRecipients();
        uint256 reserveBefore = token.balanceOf(address(token));

        vm.prank(DISTRIBUTOR);
        vm.expectRevert(abi.encodeWithSelector(MigrateRepV2Token.ZeroRecipient.selector, badIndex));
        token.distribute(r);

        assertEq(token.totalInitialRecipients(), recipientsBefore);
        assertEq(token.balanceOf(address(token)), reserveBefore);
        assertEq(token.totalSupply(), token.maximumSupply());
        for (uint256 i = 0; i < n; ++i) {
            if (r[i] != address(0)) {
                assertFalse(token.wasInitialRecipient(r[i]));
                assertEq(token.balanceOf(r[i]), 0);
            }
        }
    }

    /// @dev The lifetime cap is never exceeded across multiple distribution calls.
    function testFuzz_cap_never_exceeded(uint256 seed) public {
        MigrateRepV2Token capped = new MigrateRepV2Token(DISTRIBUTOR, 300);
        // Adjacent seed blocks are disjoint by construction; bounding also keeps `seed + 1` in range.
        seed = bound(seed, 0, 999_998);

        // Two batches that together would exceed the cap of 300.
        address[] memory first = _uniqueExcluding(200, seed, address(capped));
        vm.prank(DISTRIBUTOR);
        capped.distribute(first);

        // The cap check runs before recipient validation, so a second full-size batch is
        // rejected on lifetime accounting alone (200 + 200 = 400 > 300).
        address[] memory second = _uniqueExcluding(200, seed + 1, address(capped));
        vm.prank(DISTRIBUTOR);
        vm.expectRevert(abi.encodeWithSelector(MigrateRepV2Token.RecipientCapExceeded.selector, 400, 300));
        capped.distribute(second);

        assertEq(capped.totalInitialRecipients(), 200);
        assertLe(capped.totalInitialRecipients(), capped.recipientCap());
    }

    /// @dev The token contract at any valid index reverts the entire batch with the exact index,
    ///      leaving no balance, no history flag, no counter change, and no contract-balance change.
    function testFuzz_token_contract_recipient_is_atomic(uint256 n, uint256 badIndex, uint256 seed) public {
        n = bound(n, 1, 20);
        badIndex = bound(badIndex, 0, n - 1);

        address[] memory r = _unique(n, seed);
        r[badIndex] = address(token);

        uint256 recipientsBefore = token.totalInitialRecipients();
        uint256 contractBalanceBefore = token.balanceOf(address(token));

        vm.prank(DISTRIBUTOR);
        vm.expectRevert(abi.encodeWithSelector(MigrateRepV2Token.TokenContractRecipient.selector, badIndex));
        token.distribute(r);

        assertEq(token.totalInitialRecipients(), recipientsBefore);
        assertFalse(token.wasInitialRecipient(address(token)));
        assertEq(token.balanceOf(address(token)), contractBalanceBefore);
        assertEq(token.totalSupply(), token.maximumSupply());
        for (uint256 i = 0; i < n; ++i) {
            if (r[i] != address(token)) {
                assertFalse(token.wasInitialRecipient(r[i]));
                assertEq(token.balanceOf(r[i]), 0);
            }
        }
    }
}
