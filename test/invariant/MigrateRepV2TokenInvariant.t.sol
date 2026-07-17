// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import {Test} from "forge-std/Test.sol";

import {MigrateRepV2Token} from "../../src/MigrateRepV2Token.sol";
import {MigrateRepV2TokenHandler} from "./MigrateRepV2TokenHandler.sol";

/// @dev Compact stateful campaign (~16 runs x 64 depth). It reconciles the full balance set,
///      permanent history, distribution accounting, and post-finalization behavior.
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

    function _trackedBalanceSum() internal view returns (uint256 sum) {
        sum = token.balanceOf(address(token));
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

    /// @dev No value escapes the reserve-plus-actor set: their balances sum to total supply.
    function invariant_balanceSumEqualsSupply() public view {
        assertEq(_trackedBalanceSum(), token.totalSupply());
    }

    /// @dev The on-chain recipient count matches the ghost model; history never clears.
    function invariant_recipientHistoryConsistent() public view {
        assertEq(token.totalInitialRecipients(), handler.ghostInitialRecipients());

        uint256 flagged;
        for (uint256 i = 0; i < handler.ACTOR_COUNT(); ++i) {
            if (token.wasInitialRecipient(handler.actorAt(i))) flagged++;
        }
        // Every counted recipient corresponds to a flagged actor (distribution only targets actors).
        assertEq(flagged, token.totalInitialRecipients());
    }

    /// @dev Distributed amount equals recipients x unit; reserve holds the remainder and the
    ///      actor pool holds exactly what has left the reserve.
    function invariant_reserveAccounting() public view {
        uint256 distributed = token.totalInitialRecipients() * ONE;
        assertEq(token.balanceOf(address(token)), token.maximumSupply() - distributed);
        assertEq(_actorsBesideReserve(), distributed);
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

    /// @dev Sum of actor balances (value that has left the reserve).
    function _actorsBesideReserve() internal view returns (uint256 sum) {
        for (uint256 i = 0; i < handler.ACTOR_COUNT(); ++i) {
            sum += token.balanceOf(handler.actorAt(i));
        }
    }
}
