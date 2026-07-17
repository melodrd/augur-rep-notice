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

    function _recipients(uint256 n, uint256 seed) internal pure returns (address[] memory a) {
        a = new address[](n);
        for (uint256 i = 0; i < n; ++i) {
            a[i] = address(uint160(uint256(keccak256(abi.encode(seed, i)))));
        }
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

    function test_metadata_name() public view {
        assertEq(token.name(), "MIGRATE REPV2");
    }

    function test_metadata_symbol() public view {
        assertEq(token.symbol(), "MREP2");
    }

    function test_metadata_decimals_is_18() public view {
        assertEq(token.decimals(), 18);
    }

    function test_tokenPerRecipient_is_one_ether() public view {
        assertEq(token.TOKEN_PER_RECIPIENT(), 1 ether);
    }

    function test_maxBatchSize_is_200() public view {
        assertEq(token.MAX_BATCH_SIZE(), 200);
    }

    function test_distributor_is_exact() public view {
        assertEq(token.distributor(), DISTRIBUTOR);
    }

    function test_recipientCap_is_exact() public view {
        assertEq(token.recipientCap(), CAP);
    }

    function test_maximumSupply_is_cap_times_unit() public view {
        assertEq(token.maximumSupply(), CAP * ONE);
    }

    function test_totalSupply_equals_maximumSupply() public view {
        assertEq(token.totalSupply(), CAP * ONE);
    }

    function test_all_supply_held_by_contract() public view {
        assertEq(token.balanceOf(address(token)), CAP * ONE);
    }

    function test_distributor_starts_with_zero() public view {
        assertEq(token.balanceOf(DISTRIBUTOR), 0);
    }

    function test_deployer_starts_with_zero() public view {
        assertEq(token.balanceOf(address(this)), 0);
    }

    function test_totalInitialRecipients_starts_zero() public view {
        assertEq(token.totalInitialRecipients(), 0);
    }

    function test_distribution_starts_unfinalized() public view {
        assertFalse(token.distributionFinalized());
    }

    function test_constructor_reverts_on_zero_distributor() public {
        vm.expectRevert(MigrateRepV2Token.ZeroDistributor.selector);
        new MigrateRepV2Token(address(0), CAP);
    }

    function test_constructor_reverts_on_zero_cap() public {
        vm.expectRevert(MigrateRepV2Token.ZeroRecipientCap.selector);
        new MigrateRepV2Token(DISTRIBUTOR, 0);
    }

    function test_constructor_reverts_on_cap_overflow() public {
        uint256 tooLarge = type(uint256).max / ONE + 1;
        vm.expectRevert(MigrateRepV2Token.RecipientCapOverflow.selector);
        new MigrateRepV2Token(DISTRIBUTOR, tooLarge);
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
    // ------------------------------------------------------------------

    function test_transfer_succeeds_and_returns_true() public {
        _distribute(_one(ALICE));
        vm.prank(ALICE);
        bool ok = token.transfer(BOB, ONE);
        assertTrue(ok);
        assertEq(token.balanceOf(BOB), ONE);
        assertEq(token.balanceOf(ALICE), 0);
    }

    function test_zero_value_transfer_succeeds_and_emits_Transfer() public {
        vm.expectEmit(true, true, false, true, address(token));
        emit IERC20.Transfer(ALICE, BOB, 0);
        vm.prank(ALICE);
        bool ok = token.transfer(BOB, 0);
        assertTrue(ok);
    }

    function test_recipient_may_accumulate_multiple_tokens() public {
        _distribute(_one(ALICE));
        _distribute(_one(BOB));
        vm.prank(ALICE);
        token.transfer(BOB, ONE);
        assertEq(token.balanceOf(BOB), 2 * ONE);
    }

    function test_self_transfer_behaves_normally() public {
        _distribute(_one(ALICE));
        vm.prank(ALICE);
        token.transfer(ALICE, ONE);
        assertEq(token.balanceOf(ALICE), ONE);
    }

    function test_transfer_to_zero_uses_oz_error() public {
        _distribute(_one(ALICE));
        vm.prank(ALICE);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidReceiver.selector, address(0)));
        token.transfer(address(0), ONE);
    }

    function test_transfer_insufficient_balance_uses_oz_error() public {
        vm.prank(ALICE);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, ALICE, 0, ONE));
        token.transfer(BOB, ONE);
    }

    function test_approve_succeeds_emits_and_stores_allowance() public {
        vm.expectEmit(true, true, false, true, address(token));
        emit IERC20.Approval(ALICE, BOB, ONE);
        vm.prank(ALICE);
        bool ok = token.approve(BOB, ONE);
        assertTrue(ok);
        assertEq(token.allowance(ALICE, BOB), ONE);
    }

    function test_replacement_approval_overwrites() public {
        vm.startPrank(ALICE);
        token.approve(BOB, ONE);
        token.approve(BOB, 5 * ONE);
        vm.stopPrank();
        assertEq(token.allowance(ALICE, BOB), 5 * ONE);
    }

    function test_transferFrom_with_finite_allowance_decreases() public {
        _distribute(_one(ALICE));
        vm.prank(ALICE);
        token.approve(BOB, 3 * ONE);

        vm.prank(BOB);
        bool ok = token.transferFrom(ALICE, BOB, ONE);
        assertTrue(ok);
        assertEq(token.balanceOf(BOB), ONE);
        assertEq(token.allowance(ALICE, BOB), 2 * ONE);
    }

    function test_transferFrom_with_max_allowance_is_infinite() public {
        _distribute(_one(ALICE));
        vm.prank(ALICE);
        token.approve(BOB, type(uint256).max);

        vm.prank(BOB);
        token.transferFrom(ALICE, BOB, ONE);
        // OpenZeppelin does not decrease an infinite (max) allowance.
        assertEq(token.allowance(ALICE, BOB), type(uint256).max);
    }

    function test_transferFrom_insufficient_allowance_uses_oz_error() public {
        _distribute(_one(ALICE));
        vm.prank(ALICE);
        token.approve(BOB, ONE - 1);

        vm.prank(BOB);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, BOB, ONE - 1, ONE));
        token.transferFrom(ALICE, BOB, ONE);
    }

    function test_standard_transfers_do_not_change_total_supply() public {
        _distribute(_one(ALICE));
        uint256 before = token.totalSupply();
        vm.prank(ALICE);
        token.transfer(BOB, ONE);
        assertEq(token.totalSupply(), before);
        assertEq(token.totalSupply(), CAP * ONE);
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
        capped.distribute(_recipients(5, 7));
        assertEq(capped.totalInitialRecipients(), 5);
        assertEq(capped.recipientCap(), 5);
    }

    function test_cap_overflow_fails() public {
        MigrateRepV2Token capped = new MigrateRepV2Token(DISTRIBUTOR, 5);
        vm.prank(DISTRIBUTOR);
        capped.distribute(_recipients(4, 7));
        // 4 + 3 = 7 > 5
        address[] memory more = _recipients(3, 8);
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

    function test_transfer_after_finalization_succeeds() public {
        _distribute(_one(ALICE));
        vm.prank(DISTRIBUTOR);
        token.finalizeDistribution();
        vm.prank(ALICE);
        assertTrue(token.transfer(BOB, ONE));
    }

    function test_approve_after_finalization_succeeds() public {
        vm.prank(DISTRIBUTOR);
        token.finalizeDistribution();
        vm.prank(ALICE);
        assertTrue(token.approve(BOB, ONE));
    }

    function test_transferFrom_after_finalization_succeeds() public {
        _distribute(_one(ALICE));
        vm.prank(ALICE);
        token.approve(BOB, ONE);
        vm.prank(DISTRIBUTOR);
        token.finalizeDistribution();
        vm.prank(BOB);
        assertTrue(token.transferFrom(ALICE, BOB, ONE));
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
        address[] memory r = _recipients(201, 1);
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
