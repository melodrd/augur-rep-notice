// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.36;

import {StdInvariant} from "forge-std/StdInvariant.sol";
import {Test} from "forge-std/Test.sol";

import {RepMigrationAlert} from "../../src/RepMigrationAlert.sol";
import {RepMigrationAlertHandler} from "./RepMigrationAlertHandler.sol";

contract RepMigrationAlertInvariantTest is StdInvariant, Test {
    address internal constant AUTHORITY = address(0xA11CE);
    address internal constant DEPLOYER = address(0xD3E10);
    uint256 internal constant DISTRIBUTION_CAP = 16;

    RepMigrationAlert internal alert;
    RepMigrationAlertHandler internal handler;

    function setUp() public {
        vm.prank(DEPLOYER);
        alert = new RepMigrationAlert(AUTHORITY, DISTRIBUTION_CAP);
        handler = new RepMigrationAlertHandler(alert, AUTHORITY, DEPLOYER);

        targetContract(address(handler));

        bytes4[] memory selectors = new bytes4[](18);
        selectors[0] = handler.distributeValid.selector;
        selectors[1] = handler.distributeEmpty.selector;
        selectors[2] = handler.distributeZero.selector;
        selectors[3] = handler.distributeAdjacentDuplicate.selector;
        selectors[4] = handler.distributeNonAdjacentDuplicate.selector;
        selectors[5] = handler.distributePreviouslyNotified.selector;
        selectors[6] = handler.distributeCapBoundary.selector;
        selectors[7] = handler.distributeCapOverflow.selector;
        selectors[8] = handler.distributeUnauthorized.selector;
        selectors[9] = handler.distributeAsDeployer.selector;
        selectors[10] = handler.distributeAfterFinalization.selector;
        selectors[11] = handler.finalizeAuthorized.selector;
        selectors[12] = handler.finalizeUnauthorized.selector;
        selectors[13] = handler.finalizeAsDeployer.selector;
        selectors[14] = handler.transferAttempt.selector;
        selectors[15] = handler.transferFromAttempt.selector;
        selectors[16] = handler.approveAttempt.selector;
        selectors[17] = handler.forceEthBalance.selector;

        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
    }

    function invariant_AllApprovedStatePropertiesHold() public view {
        _assertBalancesRemainBinaryPermanentAndFullyAccounted();
        _assertSupplyAuthorityAndCapRemainConsistent();
        _assertFinalizationIsOneWayAndPermanentlyStopsIssuance();
        _assertMovementApprovalsAndBurningRemainImpossible();
    }

    function _assertBalancesRemainBinaryPermanentAndFullyAccounted() internal view {
        uint256 countedRecipients;
        uint256 poolLength = handler.recipientPoolLength();

        assertEq(alert.balanceOf(address(0)), 0);
        for (uint256 index = 0; index < poolLength; index++) {
            address recipient = handler.recipientAt(index);
            uint256 balance = alert.balanceOf(recipient);
            uint256 expectedBalance = handler.ghostNotified(recipient) ? 1 : 0;

            assertLe(balance, 1);
            assertEq(balance, expectedBalance);
            countedRecipients += balance;
        }

        assertEq(countedRecipients, handler.ghostSupply());
        assertEq(alert.totalSupply(), countedRecipients);
    }

    function _assertSupplyAuthorityAndCapRemainConsistent() internal view {
        assertEq(alert.authority(), AUTHORITY);
        assertEq(alert.distributionCap(), DISTRIBUTION_CAP);
        assertLe(alert.totalSupply(), alert.distributionCap());
        assertEq(alert.totalSupply(), handler.ghostSupply());

        assertEq(handler.unexpectedValidDistributionReverts(), 0);
        assertEq(handler.invalidDistributionSuccesses(), 0);
        assertEq(handler.unauthorizedDistributionSuccesses(), 0);
        assertEq(handler.unauthorizedFinalizationSuccesses(), 0);
        assertEq(handler.unexpectedAuthorizedFinalizationReverts(), 0);
    }

    function _assertFinalizationIsOneWayAndPermanentlyStopsIssuance() internal view {
        assertEq(alert.finalized(), handler.ghostFinalized());
        assertLe(handler.successfulFinalizations(), 1);
        assertEq(handler.repeatedFinalizationSuccesses(), 0);
        assertEq(handler.postFinalizationDistributionSuccesses(), 0);

        if (handler.ghostFinalized()) {
            assertEq(alert.totalSupply(), handler.supplyAtFinalization());
        }
    }

    function _assertMovementApprovalsAndBurningRemainImpossible() internal view {
        assertEq(handler.transferSuccesses(), 0);
        assertEq(handler.transferFromSuccesses(), 0);
        assertEq(handler.approveSuccesses(), 0);

        uint256 poolLength = handler.recipientPoolLength();
        uint256 sampledPairs = poolLength < 4 ? poolLength : 4;
        for (uint256 index = 0; index < sampledPairs; index++) {
            address owner = handler.recipientAt(index);
            address spender = handler.recipientAt((index + 1) % poolLength);
            assertEq(alert.allowance(owner, spender), 0);
        }
        assertEq(alert.allowance(AUTHORITY, DEPLOYER), 0);
        assertEq(alert.allowance(address(0), address(0)), 0);
    }
}
