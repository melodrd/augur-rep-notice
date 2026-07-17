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

    function _unique(uint256 n, uint256 seed) internal pure returns (address[] memory a) {
        a = new address[](n);
        for (uint256 i = 0; i < n; ++i) {
            a[i] = address(uint160(uint256(keccak256(abi.encode(seed, i)))));
        }
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
        // Two batches that together would exceed the cap of 300.
        address[] memory first = _unique(200, seed);
        vm.prank(DISTRIBUTOR);
        capped.distribute(first);

        // The cap check runs before recipient validation, so a second full-size batch is
        // rejected on lifetime accounting alone (200 + 200 = 400 > 300).
        address[] memory second = _unique(200, uint256(keccak256(abi.encode(seed))));
        vm.prank(DISTRIBUTOR);
        vm.expectRevert(abi.encodeWithSelector(MigrateRepV2Token.RecipientCapExceeded.selector, 400, 300));
        capped.distribute(second);

        assertEq(capped.totalInitialRecipients(), 200);
        assertLe(capped.totalInitialRecipients(), capped.recipientCap());
    }
}
