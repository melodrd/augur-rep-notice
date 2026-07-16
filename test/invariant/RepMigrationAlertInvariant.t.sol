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

        bytes4[] memory selectors = new bytes4[](27);
        selectors[0] = handler.distributeValid.selector;
        selectors[1] = handler.distributeEmpty.selector;
        selectors[2] = handler.distributeZero.selector;
        selectors[3] = handler.distributeAdjacentDuplicate.selector;
        selectors[4] = handler.distributeNonAdjacentDuplicate.selector;
        selectors[5] = handler.distributePreviouslyActive.selector;
        selectors[6] = handler.distributePreviouslyBurned.selector;
        selectors[7] = handler.distributeBurnedRecipient.selector;
        selectors[8] = handler.distributeCapBoundary.selector;
        selectors[9] = handler.distributeCapOverflow.selector;
        selectors[10] = handler.distributeUnauthorized.selector;
        selectors[11] = handler.distributeAsDeployer.selector;
        selectors[12] = handler.distributeAfterFinalization.selector;
        selectors[13] = handler.burnValid.selector;
        selectors[14] = handler.burnBeforeFinalization.selector;
        selectors[15] = handler.burnAfterFinalization.selector;
        selectors[16] = handler.burnNeverAlerted.selector;
        selectors[17] = handler.burnRepeated.selector;
        selectors[18] = handler.burnAsAuthority.selector;
        selectors[19] = handler.burnAsDeployer.selector;
        selectors[20] = handler.finalizeAuthorized.selector;
        selectors[21] = handler.finalizeUnauthorized.selector;
        selectors[22] = handler.finalizeAsDeployer.selector;
        selectors[23] = handler.transferAttempt.selector;
        selectors[24] = handler.transferFromAttempt.selector;
        selectors[25] = handler.approveAttempt.selector;
        selectors[26] = handler.forceEthBalance.selector;

        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
    }

    function invariant_AllApprovedStatePropertiesHold() public view {
        _assertRecipientLifecycleAndBalancesMatchReferenceModel();
        _assertAccountingAuthorityAndCapRemainConsistent();
        _assertFinalizationIsOneWayAndOnlyStopsIssuance();
        _assertPermissionsMovementAndApprovalsRemainConstrained();
    }

    function _assertRecipientLifecycleAndBalancesMatchReferenceModel() internal view {
        uint256 countedEverAlerted;
        uint256 countedActive;
        uint256 countedBurned;
        uint256 poolLength = handler.recipientPoolLength();

        assertEq(alert.balanceOf(address(0)), 0);
        assertFalse(alert.wasAlerted(address(0)));
        for (uint256 index = 0; index < poolLength; index++) {
            address recipient = handler.recipientAt(index);
            bool everAlerted = handler.ghostEverAlerted(recipient);
            bool active = handler.ghostActive(recipient);
            bool burned = handler.ghostBurned(recipient);
            uint256 balance = alert.balanceOf(recipient);

            assertFalse(active && burned);
            assertEq(everAlerted, active || burned);
            assertEq(alert.wasAlerted(recipient), everAlerted);
            assertEq(balance, active ? 1 : 0);
            assertLe(balance, 1);

            if (everAlerted) {
                countedEverAlerted++;
            }
            if (active) {
                countedActive++;
            }
            if (burned) {
                countedBurned++;
            }
        }

        assertEq(countedEverAlerted, handler.ghostTotalIssued());
        assertEq(countedActive, handler.ghostActiveSupply());
        assertEq(countedBurned, handler.ghostBurnedCount());
        assertEq(countedEverAlerted, countedActive + countedBurned);
        assertEq(alert.totalIssued(), countedEverAlerted);
        assertEq(alert.totalSupply(), countedActive);
        assertEq(handler.successfulBurns(), countedBurned);

        assertEq(alert.balanceOf(AUTHORITY), 0);
        assertFalse(alert.wasAlerted(AUTHORITY));
        assertEq(alert.balanceOf(DEPLOYER), 0);
        assertFalse(alert.wasAlerted(DEPLOYER));
    }

    function _assertAccountingAuthorityAndCapRemainConsistent() internal view {
        assertEq(alert.authority(), AUTHORITY);
        assertEq(alert.distributionCap(), DISTRIBUTION_CAP);
        assertEq(alert.totalIssued(), handler.ghostTotalIssued());
        assertEq(alert.totalSupply(), handler.ghostActiveSupply());
        assertEq(handler.ghostTotalIssued(), handler.ghostActiveSupply() + handler.ghostBurnedCount());
        assertLe(alert.totalSupply(), alert.totalIssued());
        assertLe(alert.totalIssued(), alert.distributionCap());

        assertEq(handler.unexpectedValidDistributionReverts(), 0);
        assertEq(handler.invalidDistributionSuccesses(), 0);
        assertEq(handler.unauthorizedDistributionSuccesses(), 0);
        assertEq(handler.postFinalizationDistributionSuccesses(), 0);
        assertEq(handler.unexpectedValidBurnReverts(), 0);
        assertEq(handler.invalidBurnSuccesses(), 0);
        assertEq(handler.unauthorizedFinalizationSuccesses(), 0);
        assertEq(handler.unexpectedAuthorizedFinalizationReverts(), 0);
    }

    function _assertFinalizationIsOneWayAndOnlyStopsIssuance() internal view {
        assertEq(alert.finalized(), handler.ghostFinalized());
        assertLe(handler.successfulFinalizations(), 1);
        assertEq(handler.repeatedFinalizationSuccesses(), 0);
        assertEq(
            handler.successfulBurns(),
            handler.successfulBurnsBeforeFinalization() + handler.successfulBurnsAfterFinalization()
        );

        if (handler.ghostFinalized()) {
            assertEq(alert.totalIssued(), handler.issuedAtFinalization());
            assertLe(alert.totalSupply(), handler.activeSupplyAtFinalization());
            assertEq(
                handler.activeSupplyAtFinalization() - alert.totalSupply(), handler.successfulBurnsAfterFinalization()
            );
        }
    }

    function _assertPermissionsMovementAndApprovalsRemainConstrained() internal view {
        assertEq(handler.transferSuccesses(), 0);
        assertEq(handler.transferFromSuccesses(), 0);
        assertEq(handler.approveSuccesses(), 0);

        uint256 poolLength = handler.recipientPoolLength();
        for (uint256 index = 0; index < poolLength; index++) {
            address owner = handler.recipientAt(index);
            address spender = handler.recipientAt((index + 1) % poolLength);
            assertEq(alert.allowance(owner, spender), 0);
        }
        assertEq(alert.allowance(AUTHORITY, DEPLOYER), 0);
        assertEq(alert.allowance(DEPLOYER, AUTHORITY), 0);
        assertEq(alert.allowance(address(0), address(0)), 0);
    }
}
