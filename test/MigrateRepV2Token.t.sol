// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

import {MigrateRepV2Token} from "../src/MigrateRepV2Token.sol";

/// @dev Shared fixture: a token whose distributor is a known address and whose cap is large
///      enough for the maximum-batch tests. Individual tests deploy tighter caps as needed.
contract MigrateRepV2TokenTest is Test {
    MigrateRepV2Token internal token;

    address internal constant DISTRIBUTOR = address(0xD1571B);
    address internal constant ALICE = address(0xA11CE);
    address internal constant BOB = address(0xB0B);
    uint256 internal constant ONE = 1 ether;
    uint256 internal constant CAP = 1000;

    function setUp() public {
        token = new MigrateRepV2Token(DISTRIBUTOR, CAP);
    }

    // --- helpers ---

    /// @dev Lowest generated recipient address. Above the precompile range and far below any
    ///      CREATE-derived contract address.
    uint160 internal constant RECIPIENT_BASE = uint160(0x10000000);

    /// @dev Width of one seed's address range. Each seed owns a disjoint block, so recipients
    ///      from different seeds can never collide.
    uint160 internal constant SEED_STRIDE = uint160(1_000_000);

    /// @dev Deterministic recipients that are unique by construction (consecutive integers in a
    ///      per-seed block) and never address(0). `forbidden` — normally the token under test —
    ///      is skipped explicitly. Correctness never depends on an address collision being
    ///      cryptographically unlikely.
    function _recipientsExcluding(uint256 n, uint256 seed, address forbidden)
        internal
        pure
        returns (address[] memory a)
    {
        require(n <= SEED_STRIDE, "seed block too small");
        a = new address[](n);
        uint160 next = RECIPIENT_BASE + uint160(seed) * SEED_STRIDE;
        for (uint256 i = 0; i < n; ++i) {
            while (next == 0 || address(next) == forbidden) {
                ++next;
            }
            a[i] = address(next);
            ++next;
        }
    }

    /// @dev Recipients valid for the shared `token` fixture.
    function _recipients(uint256 n, uint256 seed) internal view returns (address[] memory a) {
        a = _recipientsExcluding(n, seed, address(token));
    }

    function _one(address who) internal pure returns (address[] memory a) {
        a = new address[](1);
        a[0] = who;
    }

    function _distribute(address[] memory a) internal {
        vm.prank(DISTRIBUTOR);
        token.distribute(a);
    }

    // ------------------------------------------------------------------
    // Construction and metadata
    // ------------------------------------------------------------------

    function test_metadata_and_constants() public view {
        assertEq(token.name(), "CHECK AUGUR MIGRATION");
        assertEq(token.symbol(), "CHECKAUGUR");
        assertEq(token.decimals(), 18);
        assertEq(token.TOKEN_PER_RECIPIENT(), 1 ether);
        assertEq(token.MAX_BATCH_SIZE(), 200);
    }

    function test_initial_state() public view {
        assertEq(token.distributor(), DISTRIBUTOR);
        assertEq(token.recipientCap(), CAP);
        assertEq(token.maximumSupply(), CAP * ONE);
        assertEq(token.totalSupply(), CAP * ONE);
        assertEq(token.balanceOf(address(token)), CAP * ONE);
        assertEq(token.balanceOf(DISTRIBUTOR), 0);
        assertEq(token.balanceOf(address(this)), 0);
        assertEq(token.totalInitialRecipients(), 0);
        assertFalse(token.distributionFinalized());
    }

    /// @dev Constructor validation and its exact precedence: zero distributor, token-contract
    ///      distributor, zero cap, then supply overflow — asserted with the first-failing selector
    ///      even when several inputs are invalid at once. A deployer can predict the address its next
    ///      CREATE produces and pass it as the distributor; that deployment would be permanently
    ///      unusable (only the token could call distribute/finalize, and it has no self-call), so it
    ///      is rejected. The prediction is self-checking here: were it wrong, the
    ///      TokenContractDistributor cases would not revert as expected.
    function test_constructor_validation_and_precedence() public {
        uint256 overflowCap = type(uint256).max / ONE + 1;

        vm.expectRevert(MigrateRepV2Token.ZeroDistributor.selector);
        new MigrateRepV2Token(address(0), CAP);

        // zero distributor wins over a simultaneously-zero cap
        vm.expectRevert(MigrateRepV2Token.ZeroDistributor.selector);
        new MigrateRepV2Token(address(0), 0);

        vm.expectRevert(MigrateRepV2Token.TokenContractDistributor.selector);
        new MigrateRepV2Token(vm.computeCreateAddress(address(this), vm.getNonce(address(this))), CAP);

        // token-contract distributor wins over a zero cap
        vm.expectRevert(MigrateRepV2Token.TokenContractDistributor.selector);
        new MigrateRepV2Token(vm.computeCreateAddress(address(this), vm.getNonce(address(this))), 0);

        // token-contract distributor wins over supply overflow
        vm.expectRevert(MigrateRepV2Token.TokenContractDistributor.selector);
        new MigrateRepV2Token(vm.computeCreateAddress(address(this), vm.getNonce(address(this))), overflowCap);

        vm.expectRevert(MigrateRepV2Token.ZeroRecipientCap.selector);
        new MigrateRepV2Token(DISTRIBUTOR, 0);

        vm.expectRevert(MigrateRepV2Token.RecipientCapOverflow.selector);
        new MigrateRepV2Token(DISTRIBUTOR, overflowCap);
    }

    /// @dev An ordinary EOA distributor is unaffected by the self-address rejection.
    function test_constructor_accepts_eoa_distributor() public {
        MigrateRepV2Token eoa = new MigrateRepV2Token(ALICE, CAP);
        assertEq(eoa.distributor(), ALICE);
    }

    /// @dev A contract distributor remains valid. A reviewed multisignature may legitimately hold
    ///      distribution authority; only the token contract itself is rejected.
    function test_constructor_accepts_contract_distributor() public {
        // This test contract is a contract address other than the token being deployed.
        MigrateRepV2Token viaContract = new MigrateRepV2Token(address(this), CAP);
        assertEq(viaContract.distributor(), address(this));
        assertGt(address(this).code.length, 0);

        // It is usable: the contract distributor can actually distribute.
        address[] memory r = _one(ALICE);
        viaContract.distribute(r);
        assertEq(viaContract.balanceOf(ALICE), ONE);
    }

    function test_constructor_accepts_max_nonoverflowing_cap() public {
        uint256 maxCap = type(uint256).max / ONE;
        MigrateRepV2Token big = new MigrateRepV2Token(DISTRIBUTOR, maxCap);
        assertEq(big.maximumSupply(), maxCap * ONE);
        assertEq(big.totalSupply(), maxCap * ONE);
    }

    function test_deployer_has_no_implicit_authority() public {
        // The deployer (this contract) is not the distributor and cannot distribute.
        address[] memory r = _one(ALICE);
        vm.expectRevert(abi.encodeWithSelector(MigrateRepV2Token.UnauthorizedCaller.selector, address(this)));
        token.distribute(r);
    }

    // ------------------------------------------------------------------
    // Standard ERC-20 integration (inherited OpenZeppelin behavior)
    //
    // The contract overrides none of the ERC-20 surface, so OpenZeppelin's own suite owns exhaustive
    // coverage. These tests confirm the inherited behavior is reachable and intact through this
    // contract; the invariant suite additionally exercises transfer/approve/transferFrom in bulk.
    // ------------------------------------------------------------------

    function test_standard_erc20_passthrough_works() public {
        _distribute(_one(ALICE));

        // transfer moves balance and returns true
        vm.prank(ALICE);
        assertTrue(token.transfer(BOB, ONE));
        assertEq(token.balanceOf(BOB), ONE);
        assertEq(token.balanceOf(ALICE), 0);

        // zero-value transfer succeeds and emits Transfer
        vm.expectEmit(true, true, false, true, address(token));
        emit IERC20.Transfer(BOB, ALICE, 0);
        vm.prank(BOB);
        assertTrue(token.transfer(ALICE, 0));

        // approve stores the allowance, emits Approval, and returns true
        vm.expectEmit(true, true, false, true, address(token));
        emit IERC20.Approval(BOB, ALICE, 3 * ONE);
        vm.prank(BOB);
        assertTrue(token.approve(ALICE, 3 * ONE));
        assertEq(token.allowance(BOB, ALICE), 3 * ONE);

        // finite transferFrom moves the token and decreases the allowance
        vm.prank(ALICE);
        assertTrue(token.transferFrom(BOB, ALICE, ONE));
        assertEq(token.balanceOf(ALICE), ONE);
        assertEq(token.allowance(BOB, ALICE), 2 * ONE);

        // ordinary token movement never changes total supply
        assertEq(token.totalSupply(), CAP * ONE);
    }

    function test_max_allowance_is_treated_as_infinite() public {
        _distribute(_one(ALICE));
        vm.prank(ALICE);
        token.approve(BOB, type(uint256).max);
        vm.prank(BOB);
        token.transferFrom(ALICE, BOB, ONE);
        // OpenZeppelin does not decrease an infinite (max) allowance.
        assertEq(token.allowance(ALICE, BOB), type(uint256).max);
    }

    /// @dev Standard OpenZeppelin errors are preserved for transfer and allowance failures, not
    ///      wrapped in project-specific errors.
    function test_standard_erc20_errors_are_not_wrapped() public {
        _distribute(_one(ALICE));

        vm.prank(ALICE);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidReceiver.selector, address(0)));
        token.transfer(address(0), ONE);

        vm.prank(BOB); // BOB holds nothing
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, BOB, 0, ONE));
        token.transfer(ALICE, ONE);

        vm.prank(ALICE);
        token.approve(BOB, ONE - 1);
        vm.prank(BOB);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, BOB, ONE - 1, ONE));
        token.transferFrom(ALICE, BOB, ONE);
    }

    // ------------------------------------------------------------------
    // Distribution
    // ------------------------------------------------------------------

    function test_one_recipient_receives_exactly_one_token() public {
        _distribute(_one(ALICE));
        assertEq(token.balanceOf(ALICE), ONE);
        assertTrue(token.wasInitialRecipient(ALICE));
        assertEq(token.totalInitialRecipients(), 1);
    }

    function test_multiple_recipients_succeed() public {
        address[] memory r = _recipients(5, 1);
        _distribute(r);
        for (uint256 i = 0; i < r.length; ++i) {
            assertEq(token.balanceOf(r[i]), ONE);
            assertTrue(token.wasInitialRecipient(r[i]));
        }
        assertEq(token.totalInitialRecipients(), 5);
    }

    function test_multiple_distribution_calls_succeed() public {
        _distribute(_recipients(3, 1));
        _distribute(_recipients(4, 2));
        assertEq(token.totalInitialRecipients(), 7);
    }

    function test_only_distributor_may_distribute() public {
        address[] memory r = _one(ALICE);
        vm.prank(ALICE);
        vm.expectRevert(abi.encodeWithSelector(MigrateRepV2Token.UnauthorizedCaller.selector, ALICE));
        token.distribute(r);
    }

    function test_empty_batch_fails() public {
        address[] memory r = new address[](0);
        vm.prank(DISTRIBUTOR);
        vm.expectRevert(MigrateRepV2Token.EmptyRecipientArray.selector);
        token.distribute(r);
    }

    function test_zero_recipient_fails_with_exact_index() public {
        address[] memory r = new address[](3);
        r[0] = ALICE;
        r[1] = BOB;
        r[2] = address(0);
        vm.prank(DISTRIBUTOR);
        vm.expectRevert(abi.encodeWithSelector(MigrateRepV2Token.ZeroRecipient.selector, 2));
        token.distribute(r);
    }

    function test_duplicate_in_one_batch_fails() public {
        address[] memory r = new address[](2);
        r[0] = ALICE;
        r[1] = ALICE;
        vm.prank(DISTRIBUTOR);
        vm.expectRevert(abi.encodeWithSelector(MigrateRepV2Token.RecipientAlreadyDistributed.selector, ALICE));
        token.distribute(r);
    }

    // ------------------------------------------------------------------
    // Token contract as recipient
    // ------------------------------------------------------------------

    /// @dev Distributing to the token contract would self-transfer the unit, leaving the contract
    ///      balance unchanged while still consuming one unit of recipientCap and permanently
    ///      recording the token contract as an initial recipient. It is rejected outright.
    function test_token_contract_recipient_fails_with_exact_index() public {
        uint256 balanceBefore = token.balanceOf(address(token));

        address[] memory r = _one(address(token));
        vm.prank(DISTRIBUTOR);
        vm.expectRevert(abi.encodeWithSelector(MigrateRepV2Token.TokenContractRecipient.selector, 0));
        token.distribute(r);

        assertEq(token.totalInitialRecipients(), 0);
        assertFalse(token.wasInitialRecipient(address(token)));
        assertEq(token.balanceOf(address(token)), balanceBefore);
        assertEq(token.balanceOf(address(token)), CAP * ONE);
    }

    /// @dev The rejection is atomic: valid recipients earlier in the batch keep no balance, no
    ///      history flag, and no counter contribution.
    function test_token_contract_recipient_reverts_whole_batch() public {
        uint256 balanceBefore = token.balanceOf(address(token));

        address[] memory r = new address[](3);
        r[0] = ALICE;
        r[1] = BOB;
        r[2] = address(token);

        vm.prank(DISTRIBUTOR);
        vm.expectRevert(abi.encodeWithSelector(MigrateRepV2Token.TokenContractRecipient.selector, 2));
        token.distribute(r);

        assertFalse(token.wasInitialRecipient(ALICE));
        assertFalse(token.wasInitialRecipient(BOB));
        assertFalse(token.wasInitialRecipient(address(token)));
        assertEq(token.balanceOf(ALICE), 0);
        assertEq(token.balanceOf(BOB), 0);
        assertEq(token.totalInitialRecipients(), 0);
        assertEq(token.balanceOf(address(token)), balanceBefore);
        assertEq(token.totalSupply(), CAP * ONE);
    }

    /// @dev Only the token contract itself is rejected. An ordinary contract recipient — a
    ///      multisignature, custody address, or smart wallet — is a valid recipient, and the
    ///      contract never filters on bytecode presence.
    function test_ordinary_contract_recipient_succeeds() public {
        // A second token instance is simply a contract address that is not `token`.
        address otherContract = address(new MigrateRepV2Token(DISTRIBUTOR, 1));
        assertGt(otherContract.code.length, 0);

        _distribute(_one(otherContract));

        assertEq(token.balanceOf(otherContract), ONE);
        assertTrue(token.wasInitialRecipient(otherContract));
        assertEq(token.totalInitialRecipients(), 1);
    }

    /// @dev The test contract is another bytecode-bearing recipient and is equally valid.
    function test_test_contract_recipient_succeeds() public {
        _distribute(_one(address(this)));
        assertEq(token.balanceOf(address(this)), ONE);
        assertTrue(token.wasInitialRecipient(address(this)));
    }

    /// @dev Precedence around the token-contract recipient check: the zero address is rejected
    ///      before it; it is rejected before the already-distributed check (a duplicate of itself)
    ///      and before a prior recipient later in the batch; and the recipient cap is still checked
    ///      before any per-recipient validation, including the token contract.
    function test_token_contract_recipient_precedence() public {
        // zero address before the token contract
        address[] memory zeroThenToken = new address[](2);
        zeroThenToken[0] = address(0);
        zeroThenToken[1] = address(token);
        vm.prank(DISTRIBUTOR);
        vm.expectRevert(abi.encodeWithSelector(MigrateRepV2Token.ZeroRecipient.selector, 0));
        token.distribute(zeroThenToken);

        // the token contract before the already-distributed check, for a duplicate of itself
        address[] memory tokenTwice = new address[](2);
        tokenTwice[0] = address(token);
        tokenTwice[1] = address(token);
        vm.prank(DISTRIBUTOR);
        vm.expectRevert(abi.encodeWithSelector(MigrateRepV2Token.TokenContractRecipient.selector, 0));
        token.distribute(tokenTwice);

        // the token contract before a prior recipient later in the batch
        _distribute(_one(ALICE));
        address[] memory tokenThenPrior = new address[](2);
        tokenThenPrior[0] = address(token);
        tokenThenPrior[1] = ALICE; // already distributed in the prior call
        vm.prank(DISTRIBUTOR);
        vm.expectRevert(abi.encodeWithSelector(MigrateRepV2Token.TokenContractRecipient.selector, 0));
        token.distribute(tokenThenPrior);

        // the recipient cap before any per-recipient validation, including the token contract
        MigrateRepV2Token capped = new MigrateRepV2Token(DISTRIBUTOR, 1);
        address[] memory overCap = new address[](2);
        overCap[0] = address(capped);
        overCap[1] = address(capped);
        vm.prank(DISTRIBUTOR);
        vm.expectRevert(abi.encodeWithSelector(MigrateRepV2Token.RecipientCapExceeded.selector, 2, 1));
        capped.distribute(overCap);
    }

    function test_recipient_from_earlier_batch_fails() public {
        _distribute(_one(ALICE));
        address[] memory r = new address[](2);
        r[0] = BOB;
        r[1] = ALICE; // already distributed in a prior call
        vm.prank(DISTRIBUTOR);
        vm.expectRevert(abi.encodeWithSelector(MigrateRepV2Token.RecipientAlreadyDistributed.selector, ALICE));
        token.distribute(r);
    }

    function test_recipient_stays_ineligible_after_transferring_away() public {
        _distribute(_one(ALICE));
        vm.prank(ALICE);
        token.transfer(BOB, ONE);
        assertEq(token.balanceOf(ALICE), 0);
        assertTrue(token.wasInitialRecipient(ALICE));

        // ALICE cannot be an initial recipient again even with a zero balance.
        vm.prank(DISTRIBUTOR);
        vm.expectRevert(abi.encodeWithSelector(MigrateRepV2Token.RecipientAlreadyDistributed.selector, ALICE));
        token.distribute(_one(ALICE));
    }

    function test_transferred_token_holder_still_eligible_for_initial() public {
        _distribute(_one(ALICE));
        // BOB only received tokens by transfer, never an initial distribution.
        vm.prank(ALICE);
        token.transfer(BOB, ONE);
        assertFalse(token.wasInitialRecipient(BOB));
        assertEq(token.balanceOf(BOB), ONE);

        // BOB may still receive one initial distribution.
        _distribute(_one(BOB));
        assertTrue(token.wasInitialRecipient(BOB));
        assertEq(token.balanceOf(BOB), 2 * ONE);
    }

    function test_cap_boundary_succeeds() public {
        MigrateRepV2Token capped = new MigrateRepV2Token(DISTRIBUTOR, 5);
        vm.prank(DISTRIBUTOR);
        capped.distribute(_recipientsExcluding(5, 7, address(capped)));
        assertEq(capped.totalInitialRecipients(), 5);
        assertEq(capped.recipientCap(), 5);
    }

    function test_cap_overflow_fails() public {
        MigrateRepV2Token capped = new MigrateRepV2Token(DISTRIBUTOR, 5);
        vm.prank(DISTRIBUTOR);
        capped.distribute(_recipientsExcluding(4, 7, address(capped)));
        // 4 + 3 = 7 > 5
        address[] memory more = _recipientsExcluding(3, 8, address(capped));
        vm.prank(DISTRIBUTOR);
        vm.expectRevert(abi.encodeWithSelector(MigrateRepV2Token.RecipientCapExceeded.selector, 7, 5));
        capped.distribute(more);
    }

    function test_selected_max_batch_succeeds() public {
        address[] memory r = _recipients(200, 42);
        _distribute(r);
        assertEq(token.totalInitialRecipients(), 200);
        assertEq(token.balanceOf(r[199]), ONE);
    }

    function test_max_plus_one_fails_before_iteration() public {
        address[] memory r = _recipients(201, 42);
        vm.prank(DISTRIBUTOR);
        vm.expectRevert(abi.encodeWithSelector(MigrateRepV2Token.BatchSizeExceeded.selector, 201, 200));
        token.distribute(r);
        // no state mutated
        assertEq(token.totalInitialRecipients(), 0);
    }

    function test_events_appear_in_recipient_order() public {
        address[] memory r = _recipients(3, 9);
        for (uint256 i = 0; i < r.length; ++i) {
            vm.expectEmit(true, true, false, true, address(token));
            emit IERC20.Transfer(address(token), r[i], ONE);
        }
        _distribute(r);
    }

    function test_failure_is_atomic() public {
        // A zero recipient at the end must revert every earlier write and event.
        address[] memory r = new address[](3);
        r[0] = ALICE;
        r[1] = BOB;
        r[2] = address(0);
        vm.prank(DISTRIBUTOR);
        vm.expectRevert(abi.encodeWithSelector(MigrateRepV2Token.ZeroRecipient.selector, 2));
        token.distribute(r);

        assertFalse(token.wasInitialRecipient(ALICE));
        assertFalse(token.wasInitialRecipient(BOB));
        assertEq(token.balanceOf(ALICE), 0);
        assertEq(token.balanceOf(BOB), 0);
        assertEq(token.totalInitialRecipients(), 0);
        assertEq(token.balanceOf(address(token)), CAP * ONE);
    }

    function test_total_initial_recipients_increments_exactly() public {
        _distribute(_recipients(3, 1));
        assertEq(token.totalInitialRecipients(), 3);
        _distribute(_recipients(2, 2));
        assertEq(token.totalInitialRecipients(), 5);
    }

    function test_initial_recipient_history_is_permanent() public {
        _distribute(_one(ALICE));
        assertTrue(token.wasInitialRecipient(ALICE));
        vm.prank(ALICE);
        token.transfer(BOB, ONE);
        assertTrue(token.wasInitialRecipient(ALICE)); // still true after moving the token
    }

    function test_reserve_decreases_by_unit_per_recipient() public {
        uint256 reserveBefore = token.balanceOf(address(token));
        _distribute(_recipients(4, 3));
        assertEq(token.balanceOf(address(token)), reserveBefore - 4 * ONE);
    }

    function test_distribution_does_not_change_total_supply() public {
        _distribute(_recipients(10, 5));
        assertEq(token.totalSupply(), CAP * ONE);
    }

    // ------------------------------------------------------------------
    // Finalization
    // ------------------------------------------------------------------

    function test_distributor_may_finalize() public {
        vm.prank(DISTRIBUTOR);
        token.finalizeDistribution();
        assertTrue(token.distributionFinalized());
    }

    function test_outsider_cannot_finalize() public {
        vm.prank(ALICE);
        vm.expectRevert(abi.encodeWithSelector(MigrateRepV2Token.UnauthorizedCaller.selector, ALICE));
        token.finalizeDistribution();
    }

    function test_finalization_emits_exact_event() public {
        _distribute(_recipients(3, 1));
        uint256 reserve = token.balanceOf(address(token));
        vm.expectEmit(true, false, false, true, address(token));
        emit MigrateRepV2Token.DistributionFinalized(DISTRIBUTOR, 3, reserve);
        vm.prank(DISTRIBUTOR);
        token.finalizeDistribution();
    }

    /// @dev The event's third value is the contract's complete live balance, not the remaining
    ///      initial allocation. A holder may transfer a distributed token back to the contract
    ///      before finalization, so the reported balance can exceed
    ///      (recipientCap - totalInitialRecipients) * TOKEN_PER_RECIPIENT.
    function test_finalization_event_reports_complete_contract_balance() public {
        // One initial recipient who then transfers the token back to the token contract.
        _distribute(_one(ALICE));
        vm.prank(ALICE);
        token.transfer(address(token), ONE);

        // The returned token changes neither the permanent count nor the history flag.
        assertEq(token.totalInitialRecipients(), 1);
        assertTrue(token.wasInitialRecipient(ALICE));

        // The complete contract balance exceeds the remaining initial allocation by exactly the
        // one token ALICE returned, so the two quantities are not equal here.
        uint256 contractBalance = token.balanceOf(address(token));
        uint256 remainingAllocation =
            (token.recipientCap() - token.totalInitialRecipients()) * token.TOKEN_PER_RECIPIENT();
        assertEq(contractBalance, remainingAllocation + ONE);
        assertNotEq(contractBalance, remainingAllocation);

        // The event reports the complete contract balance, including the returned token.
        vm.expectEmit(true, false, false, true, address(token));
        emit MigrateRepV2Token.DistributionFinalized(DISTRIBUTOR, 1, contractBalance);
        vm.prank(DISTRIBUTOR);
        token.finalizeDistribution();

        assertTrue(token.distributionFinalized());
    }

    function test_repeated_finalization_fails() public {
        vm.startPrank(DISTRIBUTOR);
        token.finalizeDistribution();
        vm.expectRevert(MigrateRepV2Token.DistributionAlreadyFinalized.selector);
        token.finalizeDistribution();
        vm.stopPrank();
    }

    function test_distribution_after_finalization_fails() public {
        vm.prank(DISTRIBUTOR);
        token.finalizeDistribution();
        address[] memory r = _one(ALICE);
        vm.prank(DISTRIBUTOR);
        vm.expectRevert(MigrateRepV2Token.DistributionAlreadyFinalized.selector);
        token.distribute(r);
    }

    /// @dev Finalization closes distribution only; standard transfer, approve, and transferFrom all
    ///      continue to work afterward.
    function test_standard_erc20_continues_after_finalization() public {
        _distribute(_one(ALICE));
        vm.prank(ALICE);
        token.approve(BOB, ONE);

        vm.prank(DISTRIBUTOR);
        token.finalizeDistribution();

        // approve still works after finalization
        vm.prank(ALICE);
        assertTrue(token.approve(BOB, ONE));
        // transferFrom (BOB spends ALICE's approved token) still works
        vm.prank(BOB);
        assertTrue(token.transferFrom(ALICE, BOB, ONE));
        // ordinary transfer (BOB moves the token onward) still works
        vm.prank(BOB);
        assertTrue(token.transfer(ALICE, ONE));
    }

    function test_unused_reserve_remains_locked_after_finalization() public {
        _distribute(_recipients(3, 1));
        uint256 reserve = token.balanceOf(address(token));
        vm.prank(DISTRIBUTOR);
        token.finalizeDistribution();
        // Reserve is unchanged and no path can move it out of the contract.
        assertEq(token.balanceOf(address(token)), reserve);
        assertEq(reserve, (CAP - 3) * ONE);
    }

    function test_total_supply_fixed_across_finalization() public {
        _distribute(_recipients(3, 1));
        vm.prank(DISTRIBUTOR);
        token.finalizeDistribution();
        assertEq(token.totalSupply(), CAP * ONE);
    }

    // ------------------------------------------------------------------
    // Validation precedence: authorization -> finalized -> empty ->
    // batch maximum -> recipient cap -> recipients
    // ------------------------------------------------------------------

    function test_precedence_authorization_before_finalized() public {
        vm.prank(DISTRIBUTOR);
        token.finalizeDistribution();
        // Non-distributor after finalization: authorization error wins.
        address[] memory r = _one(ALICE);
        vm.prank(ALICE);
        vm.expectRevert(abi.encodeWithSelector(MigrateRepV2Token.UnauthorizedCaller.selector, ALICE));
        token.distribute(r);
    }

    function test_precedence_finalized_before_empty() public {
        vm.prank(DISTRIBUTOR);
        token.finalizeDistribution();
        // Empty array after finalization: finalized error wins over empty error.
        address[] memory r = new address[](0);
        vm.prank(DISTRIBUTOR);
        vm.expectRevert(MigrateRepV2Token.DistributionAlreadyFinalized.selector);
        token.distribute(r);
    }

    function test_precedence_empty_before_batch_maximum() public {
        // Empty (length 0) reports the empty error; it never reaches the size check.
        address[] memory r = new address[](0);
        vm.prank(DISTRIBUTOR);
        vm.expectRevert(MigrateRepV2Token.EmptyRecipientArray.selector);
        token.distribute(r);
    }

    function test_precedence_batch_maximum_before_recipient_cap() public {
        // cap smaller than the batch, and batch above MAX_BATCH_SIZE: size error wins.
        MigrateRepV2Token capped = new MigrateRepV2Token(DISTRIBUTOR, 10);
        address[] memory r = _recipientsExcluding(201, 1, address(capped));
        vm.prank(DISTRIBUTOR);
        vm.expectRevert(abi.encodeWithSelector(MigrateRepV2Token.BatchSizeExceeded.selector, 201, 200));
        capped.distribute(r);
    }

    function test_precedence_recipient_cap_before_recipients() public {
        // cap exceeded and a zero recipient present: cap error wins over recipient validation.
        MigrateRepV2Token capped = new MigrateRepV2Token(DISTRIBUTOR, 1);
        address[] memory r = new address[](2);
        r[0] = address(0);
        r[1] = address(0);
        vm.prank(DISTRIBUTOR);
        vm.expectRevert(abi.encodeWithSelector(MigrateRepV2Token.RecipientCapExceeded.selector, 2, 1));
        capped.distribute(r);
    }
}
