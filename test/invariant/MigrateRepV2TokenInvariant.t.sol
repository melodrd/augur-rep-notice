// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import {Test} from "forge-std/Test.sol";

import {MigrateRepV2Token} from "../../src/MigrateRepV2Token.sol";
import {MigrateRepV2TokenHandler} from "./MigrateRepV2TokenHandler.sol";

/// @dev Compact stateful campaign (~16 runs x 64 depth). It reconciles the full balance set,
///      permanent history, distribution accounting, and post-finalization behavior.
///
///      The handler models every permitted ERC-20 behavior, including holders transferring MREP2
///      back to `address(token)`. The token contract's balance is therefore not the remaining
///      initial allocation: it is that allocation plus whatever has been returned.
contract MigrateRepV2TokenInvariant is Test {
    MigrateRepV2Token internal token;
    MigrateRepV2TokenHandler internal handler;

    address internal constant DISTRIBUTOR = address(0xD1571B);
    uint256 internal constant CAP = 20;
    uint256 internal constant ONE = 1 ether;

    function setUp() public {
        token = new MigrateRepV2Token(DISTRIBUTOR, CAP);
        handler = new MigrateRepV2TokenHandler(token, DISTRIBUTOR);
        targetContract(address(handler));
    }

    /// @dev Sum of every tracked balance: the actor pool plus the token contract.
    function _trackedBalanceSum() internal view returns (uint256 sum) {
        sum = token.balanceOf(address(token)) + _actorBalanceSum();
    }

    /// @dev Sum of actor balances only — the value currently held outside the token contract.
    function _actorBalanceSum() internal view returns (uint256 sum) {
        for (uint256 i = 0; i < handler.ACTOR_COUNT(); ++i) {
            sum += token.balanceOf(handler.actorAt(i));
        }
    }

    /// @dev Total supply is fixed at the maximum supply forever.
    function invariant_totalSupplyFixed() public view {
        assertEq(token.totalSupply(), token.maximumSupply());
    }

    /// @dev The lifetime recipient count never exceeds the cap.
    function invariant_recipientsWithinCap() public view {
        assertLe(token.totalInitialRecipients(), token.recipientCap());
    }

    /// @dev No value escapes the tracked set: actor balances plus the token contract's balance
    ///      sum to total supply.
    function invariant_balanceSumEqualsSupply() public view {
        assertEq(_trackedBalanceSum(), token.totalSupply());
    }

    /// @dev The on-chain recipient count matches the ghost model, and the number of distinctly
    ///      flagged actors equals it — so no address was ever initially distributed to twice.
    function invariant_recipientHistoryConsistent() public view {
        assertEq(token.totalInitialRecipients(), handler.ghostInitialRecipients());

        uint256 flagged;
        for (uint256 i = 0; i < handler.ACTOR_COUNT(); ++i) {
            if (token.wasInitialRecipient(handler.actorAt(i))) flagged++;
        }
        // Distribution only ever targets actors, so a second distribution to an already-flagged
        // address would raise the count without raising the number of distinct flagged actors.
        assertEq(flagged, token.totalInitialRecipients());
    }

    /// @dev Initial-recipient history only ever changes false -> true. Any address the handler has
    ///      seen flagged must still read true, whatever transfers happened afterward.
    function invariant_recipientHistoryOnlyGrows() public view {
        for (uint256 i = 0; i < handler.ACTOR_COUNT(); ++i) {
            address actor = handler.actorAt(i);
            if (handler.ghostEverFlagged(actor)) {
                assertTrue(token.wasInitialRecipient(actor), "initial-recipient history cleared");
            }
        }
    }

    /// @dev The token contract's balance follows the returned-token model:
    ///
    ///        contract balance = maximumSupply
    ///                         - totalInitialRecipients * TOKEN_PER_RECIPIENT
    ///                         + tokens returned to the contract
    ///
    ///      and the actor pool holds exactly what has left the contract and not come back:
    ///
    ///        actor balance sum = totalInitialRecipients * TOKEN_PER_RECIPIENT
    ///                          - tokens returned to the contract
    ///
    ///      The contract balance is not "the remaining reserve": it is the remaining initial
    ///      allocation plus any returned tokens, which no path can distribute or recover.
    function invariant_contractBalanceFollowsReturnedTokenModel() public view {
        uint256 distributed = token.totalInitialRecipients() * ONE;
        uint256 returned = handler.ghostReturnedToContract();

        assertEq(token.balanceOf(address(token)), token.maximumSupply() - distributed + returned);
        assertEq(_actorBalanceSum(), distributed - returned);
    }

    /// @dev The remaining initial allocation never exceeds the contract's balance: returned tokens
    ///      can only add to it, and the allocation itself is only ever consumed by distribution.
    function invariant_remainingInitialAllocationNeverExceedsBalance() public view {
        uint256 remainingInitialAllocation = (token.recipientCap() - token.totalInitialRecipients()) * ONE;
        assertGe(token.balanceOf(address(token)), remainingInitialAllocation);
    }

    /// @dev The token contract is never an initial recipient, at any point in the campaign.
    function invariant_tokenContractIsNeverAnInitialRecipient() public {
        assertFalse(token.wasInitialRecipient(address(token)));

        if (token.distributionFinalized()) return;
        if (token.totalInitialRecipients() >= token.recipientCap()) return;

        address[] memory r = new address[](1);
        r[0] = address(token);
        vm.prank(DISTRIBUTOR);
        try token.distribute(r) {
            revert("distribute must reject the token contract as a recipient");
        } catch {
            // expected
        }
        assertFalse(token.wasInitialRecipient(address(token)));
    }

    /// @dev After finalization, distribution always reverts and supply is unchanged.
    function invariant_distributionFailsAfterFinalization() public {
        if (!token.distributionFinalized()) return;
        address[] memory r = new address[](1);
        r[0] = address(0xF1);
        vm.prank(DISTRIBUTOR);
        try token.distribute(r) {
            revert("distribute must fail after finalization");
        } catch {
            // expected
        }
        assertEq(token.totalSupply(), token.maximumSupply());
    }
}
