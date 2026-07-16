// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.36;

import {Test} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";

import {RepMigrationAlert} from "../src/RepMigrationAlert.sol";
import {ContractRecipient} from "./helpers/ContractRecipient.sol";

contract RepMigrationAlertTest is Test {
    address internal constant AUTHORITY = address(0xA11CE);
    address internal constant DEPLOYER = address(0xD3E10);
    address internal constant OUTSIDER = address(0xBAD);
    address internal constant RECIPIENT_A = address(0x1001);
    address internal constant RECIPIENT_B = address(0x1002);
    address internal constant RECIPIENT_C = address(0x1003);
    uint256 internal constant DISTRIBUTION_CAP = 10;

    bytes32 internal constant TRANSFER_TOPIC = keccak256("Transfer(address,address,uint256)");
    bytes32 internal constant FINALIZED_TOPIC = keccak256("DistributionFinalized(address,uint256)");

    RepMigrationAlert internal alert;

    function setUp() public {
        vm.prank(DEPLOYER);
        alert = new RepMigrationAlert(AUTHORITY, DISTRIBUTION_CAP);
    }

    function test_ConstructorSetsApprovedInitialState() public view {
        assertEq(alert.name(), "CHECK AUGUR REP MIGRATION");
        assertEq(alert.symbol(), "MIGRATEREP");
        assertEq(alert.decimals(), 0);
        assertEq(alert.totalIssued(), 0);
        assertEq(alert.totalSupply(), 0);
        assertEq(alert.balanceOf(RECIPIENT_A), 0);
        assertFalse(alert.wasAlerted(RECIPIENT_A));
        assertEq(alert.balanceOf(address(0)), 0);
        assertFalse(alert.wasAlerted(address(0)));
        assertEq(alert.allowance(RECIPIENT_A, RECIPIENT_B), 0);
        assertEq(alert.authority(), AUTHORITY);
        assertEq(alert.distributionCap(), DISTRIBUTION_CAP);
        assertFalse(alert.finalized());
        assertEq(alert.balanceOf(DEPLOYER), 0);
        assertFalse(alert.wasAlerted(DEPLOYER));
        assertEq(alert.balanceOf(AUTHORITY), 0);
        assertFalse(alert.wasAlerted(AUTHORITY));
    }

    function test_ConstructorEmitsNoIssuanceEvent() public {
        vm.recordLogs();
        new RepMigrationAlert(AUTHORITY, DISTRIBUTION_CAP);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        assertEq(logs.length, 0);
    }

    function test_RevertWhen_AuthorityIsZero() public {
        vm.expectRevert(RepMigrationAlert.ZeroAuthority.selector);
        new RepMigrationAlert(address(0), DISTRIBUTION_CAP);
    }

    function test_RevertWhen_DistributionCapIsZero() public {
        vm.expectRevert(RepMigrationAlert.ZeroDistributionCap.selector);
        new RepMigrationAlert(AUTHORITY, 0);
    }

    function test_UnrelatedDeployerReceivesNoPrivilege() public {
        address[] memory recipients = _recipients(RECIPIENT_A);

        _assertDistributionRevertsAtomically(
            DEPLOYER, recipients, abi.encodeWithSelector(RepMigrationAlert.UnauthorizedCaller.selector, DEPLOYER)
        );

        vm.prank(DEPLOYER);
        vm.expectRevert(abi.encodeWithSelector(RepMigrationAlert.UnauthorizedCaller.selector, DEPLOYER));
        alert.finalize();

        assertFalse(alert.finalized());
    }

    function test_SameAddressMayDeployAndServeAsAuthority() public {
        vm.startPrank(AUTHORITY);
        RepMigrationAlert sameAddressAlert = new RepMigrationAlert(AUTHORITY, 1);
        sameAddressAlert.distribute(_recipients(RECIPIENT_A));
        sameAddressAlert.finalize();
        vm.stopPrank();

        assertEq(sameAddressAlert.authority(), AUTHORITY);
        assertEq(sameAddressAlert.balanceOf(RECIPIENT_A), 1);
        assertTrue(sameAddressAlert.wasAlerted(RECIPIENT_A));
        assertEq(sameAddressAlert.totalIssued(), 1);
        assertEq(sameAddressAlert.totalSupply(), 1);
        assertTrue(sameAddressAlert.finalized());
    }

    function test_DistributeSingleRecipient() public {
        vm.expectEmit(true, true, false, true, address(alert));
        emit RepMigrationAlert.Transfer(address(0), RECIPIENT_A, 1);

        vm.prank(AUTHORITY);
        alert.distribute(_recipients(RECIPIENT_A));

        assertEq(alert.balanceOf(RECIPIENT_A), 1);
        assertTrue(alert.wasAlerted(RECIPIENT_A));
        assertEq(alert.balanceOf(RECIPIENT_B), 0);
        assertFalse(alert.wasAlerted(RECIPIENT_B));
        assertEq(alert.totalIssued(), 1);
        assertEq(alert.totalSupply(), 1);
        assertFalse(alert.finalized());
    }

    function test_OneAddressCanaryUsesDistributionPath() public {
        address[] memory canary = _recipients(RECIPIENT_A);

        vm.prank(AUTHORITY);
        alert.distribute(canary);

        assertEq(alert.balanceOf(RECIPIENT_A), 1);
        assertTrue(alert.wasAlerted(RECIPIENT_A));
        assertEq(alert.totalIssued(), canary.length);
        assertEq(alert.totalSupply(), canary.length);
    }

    function test_DistributeMultipleRecipients() public {
        address[] memory recipients = _recipients(RECIPIENT_A, RECIPIENT_B, RECIPIENT_C);

        vm.prank(AUTHORITY);
        alert.distribute(recipients);

        assertEq(alert.balanceOf(RECIPIENT_A), 1);
        assertEq(alert.balanceOf(RECIPIENT_B), 1);
        assertEq(alert.balanceOf(RECIPIENT_C), 1);
        assertTrue(alert.wasAlerted(RECIPIENT_A));
        assertTrue(alert.wasAlerted(RECIPIENT_B));
        assertTrue(alert.wasAlerted(RECIPIENT_C));
        assertEq(alert.balanceOf(OUTSIDER), 0);
        assertFalse(alert.wasAlerted(OUTSIDER));
        assertEq(alert.totalIssued(), recipients.length);
        assertEq(alert.totalSupply(), recipients.length);
        assertFalse(alert.finalized());
    }

    function test_DistributeAcrossMultipleSuccessfulBatches() public {
        vm.startPrank(AUTHORITY);
        alert.distribute(_recipients(RECIPIENT_A));
        alert.distribute(_recipients(RECIPIENT_B, RECIPIENT_C));
        vm.stopPrank();

        assertEq(alert.balanceOf(RECIPIENT_A), 1);
        assertEq(alert.balanceOf(RECIPIENT_B), 1);
        assertEq(alert.balanceOf(RECIPIENT_C), 1);
        assertTrue(alert.wasAlerted(RECIPIENT_A));
        assertTrue(alert.wasAlerted(RECIPIENT_B));
        assertTrue(alert.wasAlerted(RECIPIENT_C));
        assertEq(alert.totalIssued(), 3);
        assertEq(alert.totalSupply(), 3);
    }

    function test_DistributeToContractRecipient() public {
        ContractRecipient contractRecipient = new ContractRecipient();

        vm.prank(AUTHORITY);
        alert.distribute(_recipients(address(contractRecipient)));

        assertEq(alert.balanceOf(address(contractRecipient)), 1);
        assertTrue(alert.wasAlerted(address(contractRecipient)));
        assertEq(alert.totalIssued(), 1);
        assertEq(alert.totalSupply(), 1);
    }

    function test_DistributionEmitsOneEventPerRecipientInCalldataOrder() public {
        address[] memory recipients = _recipients(RECIPIENT_C, RECIPIENT_A, RECIPIENT_B);

        vm.recordLogs();
        vm.prank(AUTHORITY);
        alert.distribute(recipients);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        assertEq(logs.length, recipients.length);
        for (uint256 index = 0; index < recipients.length; index++) {
            assertEq(logs[index].emitter, address(alert));
            assertEq(logs[index].topics.length, 3);
            assertEq(logs[index].topics[0], TRANSFER_TOPIC);
            assertEq(logs[index].topics[1], bytes32(0));
            assertEq(logs[index].topics[2], bytes32(uint256(uint160(recipients[index]))));
            assertEq(abi.decode(logs[index].data, (uint256)), 1);
        }
    }

    function test_DistributionExactlyReachesCapWithoutFinalizing() public {
        RepMigrationAlert cappedAlert = new RepMigrationAlert(AUTHORITY, 3);
        address[] memory recipients = _recipients(RECIPIENT_A, RECIPIENT_B, RECIPIENT_C);

        vm.prank(AUTHORITY);
        cappedAlert.distribute(recipients);

        assertEq(cappedAlert.totalIssued(), cappedAlert.distributionCap());
        assertEq(cappedAlert.totalSupply(), cappedAlert.distributionCap());
        assertEq(cappedAlert.balanceOf(RECIPIENT_A), 1);
        assertEq(cappedAlert.balanceOf(RECIPIENT_B), 1);
        assertEq(cappedAlert.balanceOf(RECIPIENT_C), 1);
        assertTrue(cappedAlert.wasAlerted(RECIPIENT_A));
        assertTrue(cappedAlert.wasAlerted(RECIPIENT_B));
        assertTrue(cappedAlert.wasAlerted(RECIPIENT_C));
        assertFalse(cappedAlert.finalized());
    }

    function test_RevertWhen_CallerIsUnauthorized() public {
        _assertDistributionRevertsAtomically(
            OUTSIDER,
            _recipients(RECIPIENT_A),
            abi.encodeWithSelector(RepMigrationAlert.UnauthorizedCaller.selector, OUTSIDER)
        );
    }

    function test_RevertWhen_RecipientArrayIsEmpty() public {
        _assertDistributionRevertsAtomically(
            AUTHORITY, new address[](0), abi.encodeWithSelector(RepMigrationAlert.EmptyRecipientArray.selector)
        );
    }

    function test_RevertWhen_ZeroRecipientIsAtFirstIndex() public {
        address[] memory recipients = _recipients(address(0), RECIPIENT_A, RECIPIENT_B);

        _assertDistributionRevertsAtomically(
            AUTHORITY, recipients, abi.encodeWithSelector(RepMigrationAlert.ZeroRecipient.selector, 0)
        );
    }

    function test_RevertWhen_ZeroRecipientIsInMiddle() public {
        address[] memory recipients = _recipients(RECIPIENT_A, address(0), RECIPIENT_B);

        _assertDistributionRevertsAtomically(
            AUTHORITY, recipients, abi.encodeWithSelector(RepMigrationAlert.ZeroRecipient.selector, 1)
        );
    }

    function test_RevertWhen_ZeroRecipientIsAtFinalIndex() public {
        address[] memory recipients = _recipients(RECIPIENT_A, RECIPIENT_B, address(0));

        _assertDistributionRevertsAtomically(
            AUTHORITY, recipients, abi.encodeWithSelector(RepMigrationAlert.ZeroRecipient.selector, 2)
        );
    }

    function test_RevertWhen_DistributionContainsAdjacentDuplicate() public {
        address[] memory recipients = _recipients(RECIPIENT_A, RECIPIENT_A, RECIPIENT_B);

        _assertDistributionRevertsAtomically(
            AUTHORITY,
            recipients,
            abi.encodeWithSelector(RepMigrationAlert.RecipientAlreadyNotified.selector, RECIPIENT_A)
        );
    }

    function test_RevertWhen_DistributionContainsNonAdjacentDuplicate() public {
        address[] memory recipients = _recipients(RECIPIENT_A, RECIPIENT_B, RECIPIENT_A);

        _assertDistributionRevertsAtomically(
            AUTHORITY,
            recipients,
            abi.encodeWithSelector(RepMigrationAlert.RecipientAlreadyNotified.selector, RECIPIENT_A)
        );
    }

    function test_RevertWhen_RecipientWasPreviouslyNotified() public {
        _distribute(RECIPIENT_A);

        _assertDistributionRevertsAtomically(
            AUTHORITY,
            _recipients(RECIPIENT_A),
            abi.encodeWithSelector(RepMigrationAlert.RecipientAlreadyNotified.selector, RECIPIENT_A)
        );
    }

    function test_RevertWhen_RecipientWasPreviouslyNotifiedAndBurned() public {
        _distribute(RECIPIENT_A);
        vm.prank(RECIPIENT_A);
        alert.burn();

        assertEq(alert.balanceOf(RECIPIENT_A), 0);
        assertTrue(alert.wasAlerted(RECIPIENT_A));
        assertEq(alert.totalIssued(), 1);
        assertEq(alert.totalSupply(), 0);

        _assertDistributionRevertsAtomically(
            AUTHORITY,
            _recipients(RECIPIENT_A),
            abi.encodeWithSelector(RepMigrationAlert.RecipientAlreadyNotified.selector, RECIPIENT_A)
        );
    }

    function test_RevertWhen_PreviouslyNotifiedRecipientIsMixedWithNewRecipients() public {
        _distribute(RECIPIENT_B);
        address[] memory recipients = _recipients(RECIPIENT_A, RECIPIENT_B, RECIPIENT_C);

        _assertDistributionRevertsAtomically(
            AUTHORITY,
            recipients,
            abi.encodeWithSelector(RepMigrationAlert.RecipientAlreadyNotified.selector, RECIPIENT_B)
        );
    }

    function test_RevertWhen_BurnedRecipientIsMixedWithNewRecipients() public {
        _distribute(RECIPIENT_B);
        vm.prank(RECIPIENT_B);
        alert.burn();
        address[] memory recipients = _recipients(RECIPIENT_A, RECIPIENT_B, RECIPIENT_C);

        _assertDistributionRevertsAtomically(
            AUTHORITY,
            recipients,
            abi.encodeWithSelector(RepMigrationAlert.RecipientAlreadyNotified.selector, RECIPIENT_B)
        );
    }

    function test_RevertWhen_EarlierBatchIsSubmittedAgain() public {
        address[] memory recipients = _recipients(RECIPIENT_A, RECIPIENT_B, RECIPIENT_C);
        vm.prank(AUTHORITY);
        alert.distribute(recipients);

        _assertDistributionRevertsAtomically(
            AUTHORITY,
            recipients,
            abi.encodeWithSelector(RepMigrationAlert.RecipientAlreadyNotified.selector, RECIPIENT_A)
        );
    }

    function test_RevertWhen_DistributionExceedsCapByOne() public {
        RepMigrationAlert cappedAlert = new RepMigrationAlert(AUTHORITY, 2);
        address[] memory recipients = _recipients(RECIPIENT_A, RECIPIENT_B, RECIPIENT_C);

        _assertDistributionRevertsAtomically(
            cappedAlert,
            AUTHORITY,
            recipients,
            abi.encodeWithSelector(RepMigrationAlert.DistributionCapExceeded.selector, 3, 2)
        );
    }

    function test_RevertWhen_DistributionSubstantiallyExceedsCap() public {
        RepMigrationAlert cappedAlert = new RepMigrationAlert(AUTHORITY, 1);
        address[] memory recipients = new address[](8);
        uint160 recipientValue = 0x2000;
        for (uint256 index = 0; index < recipients.length; index++) {
            recipients[index] = address(recipientValue);
            recipientValue++;
        }

        _assertDistributionRevertsAtomically(
            cappedAlert,
            AUTHORITY,
            recipients,
            abi.encodeWithSelector(RepMigrationAlert.DistributionCapExceeded.selector, 8, 1)
        );
    }

    function test_RevertWhen_MultiBatchDistributionExceedsRemainingCap() public {
        RepMigrationAlert cappedAlert = new RepMigrationAlert(AUTHORITY, 3);
        vm.prank(AUTHORITY);
        cappedAlert.distribute(_recipients(RECIPIENT_A, RECIPIENT_B));

        _assertDistributionRevertsAtomically(
            cappedAlert,
            AUTHORITY,
            _recipients(RECIPIENT_C, OUTSIDER),
            abi.encodeWithSelector(RepMigrationAlert.DistributionCapExceeded.selector, 4, 3)
        );
    }

    function test_BurningDoesNotCreateDistributionCapHeadroom() public {
        RepMigrationAlert cappedAlert = new RepMigrationAlert(AUTHORITY, 2);
        vm.prank(AUTHORITY);
        cappedAlert.distribute(_recipients(RECIPIENT_A, RECIPIENT_B));

        vm.prank(RECIPIENT_A);
        cappedAlert.burn();

        assertEq(cappedAlert.totalIssued(), 2);
        assertEq(cappedAlert.totalSupply(), 1);
        assertEq(cappedAlert.balanceOf(RECIPIENT_A), 0);
        assertTrue(cappedAlert.wasAlerted(RECIPIENT_A));

        _assertDistributionRevertsAtomically(
            cappedAlert,
            AUTHORITY,
            _recipients(RECIPIENT_C),
            abi.encodeWithSelector(RepMigrationAlert.DistributionCapExceeded.selector, 3, 2)
        );
    }

    function test_RevertWhen_DistributingAfterFinalization() public {
        vm.prank(AUTHORITY);
        alert.finalize();

        _assertDistributionRevertsAtomically(
            AUTHORITY,
            _recipients(RECIPIENT_A),
            abi.encodeWithSelector(RepMigrationAlert.DistributionAlreadyClosed.selector)
        );
    }

    function test_ActiveHolderBurnsBeforeFinalization() public {
        _distribute(RECIPIENT_A);

        assertFalse(alert.finalized());
        vm.expectEmit(true, true, false, true, address(alert));
        emit RepMigrationAlert.Transfer(RECIPIENT_A, address(0), 1);

        vm.prank(RECIPIENT_A);
        alert.burn();

        assertFalse(alert.finalized());
        assertEq(alert.balanceOf(RECIPIENT_A), 0);
        assertTrue(alert.wasAlerted(RECIPIENT_A));
        assertEq(alert.balanceOf(RECIPIENT_B), 0);
        assertFalse(alert.wasAlerted(RECIPIENT_B));
        assertEq(alert.totalIssued(), 1);
        assertEq(alert.totalSupply(), 0);
    }

    function test_RevertWhen_NeverAlertedCallerBurns() public {
        _assertBurnReverts(OUTSIDER);

        assertEq(alert.totalIssued(), 0);
        assertEq(alert.totalSupply(), 0);
        assertEq(alert.balanceOf(OUTSIDER), 0);
        assertFalse(alert.wasAlerted(OUTSIDER));
    }

    function test_RevertWhen_HolderBurnsRepeatedly() public {
        _distribute(RECIPIENT_A);
        vm.prank(RECIPIENT_A);
        alert.burn();

        _assertBurnReverts(RECIPIENT_A);

        assertEq(alert.balanceOf(RECIPIENT_A), 0);
        assertTrue(alert.wasAlerted(RECIPIENT_A));
        assertEq(alert.totalIssued(), 1);
        assertEq(alert.totalSupply(), 0);
    }

    function test_RevertWhen_AuthorityWithoutAlertAttemptsToBurnAnotherHoldersAlert() public {
        _distribute(RECIPIENT_A);

        _assertBurnReverts(AUTHORITY);

        assertEq(alert.balanceOf(RECIPIENT_A), 1);
        assertTrue(alert.wasAlerted(RECIPIENT_A));
        assertEq(alert.totalIssued(), 1);
        assertEq(alert.totalSupply(), 1);
    }

    function test_RevertWhen_DeployerWithoutAlertAttemptsToBurnAnotherHoldersAlert() public {
        _distribute(RECIPIENT_A);

        _assertBurnReverts(DEPLOYER);

        assertEq(alert.balanceOf(RECIPIENT_A), 1);
        assertTrue(alert.wasAlerted(RECIPIENT_A));
        assertEq(alert.totalIssued(), 1);
        assertEq(alert.totalSupply(), 1);
    }

    function test_RevertWhen_OutsiderWithoutAlertAttemptsToBurnAnotherHoldersAlert() public {
        _distribute(RECIPIENT_A);

        _assertBurnReverts(OUTSIDER);

        assertEq(alert.balanceOf(RECIPIENT_A), 1);
        assertTrue(alert.wasAlerted(RECIPIENT_A));
        assertEq(alert.totalIssued(), 1);
        assertEq(alert.totalSupply(), 1);
    }

    function test_AuthorityMayBurnItsOwnActiveAlert() public {
        _distribute(AUTHORITY);

        vm.prank(AUTHORITY);
        alert.burn();

        assertEq(alert.balanceOf(AUTHORITY), 0);
        assertTrue(alert.wasAlerted(AUTHORITY));
        assertEq(alert.totalIssued(), 1);
        assertEq(alert.totalSupply(), 0);
    }

    function test_BurningOneOfSeveralRecipientsPreservesExactAccounting() public {
        _distribute(RECIPIENT_A, RECIPIENT_B, RECIPIENT_C);

        vm.prank(RECIPIENT_B);
        alert.burn();

        assertEq(alert.balanceOf(RECIPIENT_A), 1);
        assertEq(alert.balanceOf(RECIPIENT_B), 0);
        assertEq(alert.balanceOf(RECIPIENT_C), 1);
        assertTrue(alert.wasAlerted(RECIPIENT_A));
        assertTrue(alert.wasAlerted(RECIPIENT_B));
        assertTrue(alert.wasAlerted(RECIPIENT_C));
        assertEq(alert.totalIssued(), 3);
        assertEq(alert.totalSupply(), 2);
    }

    function test_ActiveHolderBurnsAfterFinalization() public {
        _distribute(RECIPIENT_A, RECIPIENT_B);
        vm.prank(AUTHORITY);
        alert.finalize();

        vm.prank(RECIPIENT_A);
        alert.burn();

        assertTrue(alert.finalized());
        assertEq(alert.balanceOf(RECIPIENT_A), 0);
        assertEq(alert.balanceOf(RECIPIENT_B), 1);
        assertTrue(alert.wasAlerted(RECIPIENT_A));
        assertTrue(alert.wasAlerted(RECIPIENT_B));
        assertEq(alert.totalIssued(), 2);
        assertEq(alert.totalSupply(), 1);

        _assertDistributionRevertsAtomically(
            AUTHORITY,
            _recipients(RECIPIENT_C),
            abi.encodeWithSelector(RepMigrationAlert.DistributionAlreadyClosed.selector)
        );
    }

    function test_ContractRecipientBurnsItsOwnActiveAlert() public {
        ContractRecipient contractRecipient = new ContractRecipient();
        vm.prank(AUTHORITY);
        alert.distribute(_recipients(address(contractRecipient)));

        contractRecipient.burnAlert(alert);

        assertEq(alert.balanceOf(address(contractRecipient)), 0);
        assertTrue(alert.wasAlerted(address(contractRecipient)));
        assertEq(alert.totalIssued(), 1);
        assertEq(alert.totalSupply(), 0);
    }

    function test_RevertWhen_OrdinaryCallerTransfersPositiveValue() public {
        _assertTransferReverts(OUTSIDER, RECIPIENT_A, 1);
    }

    function test_RevertWhen_AuthorityTransfersPositiveValue() public {
        _assertTransferReverts(AUTHORITY, RECIPIENT_A, 1);
    }

    function test_RevertWhen_OrdinaryCallerTransfersZeroValue() public {
        _assertTransferReverts(OUTSIDER, RECIPIENT_A, 0);
    }

    function test_RevertWhen_AuthorityTransfersZeroValue() public {
        _assertTransferReverts(AUTHORITY, RECIPIENT_A, 0);
    }

    function test_RevertWhen_RecipientAttemptsSelfTransfer() public {
        _distribute(RECIPIENT_A);
        _assertTransferReverts(RECIPIENT_A, RECIPIENT_A, 1);
        assertEq(alert.balanceOf(RECIPIENT_A), 1);
    }

    function test_RevertWhen_TransferTargetsZeroAddress() public {
        _assertTransferReverts(OUTSIDER, address(0), 1);
    }

    function test_RevertWhen_TransferIsAttemptedAfterFinalization() public {
        vm.prank(AUTHORITY);
        alert.finalize();

        _assertTransferReverts(AUTHORITY, RECIPIENT_A, 1);
    }

    function test_RevertWhen_OrdinaryCallerUsesTransferFrom() public {
        _assertTransferFromReverts(OUTSIDER, RECIPIENT_A, RECIPIENT_B, 1);
    }

    function test_RevertWhen_AuthorityUsesTransferFrom() public {
        _assertTransferFromReverts(AUTHORITY, RECIPIENT_A, RECIPIENT_B, 1);
    }

    function test_RevertWhen_TransferFromUsesZeroValue() public {
        _assertTransferFromReverts(OUTSIDER, RECIPIENT_A, RECIPIENT_B, 0);
    }

    function test_RevertWhen_OrdinaryCallerApprovesPositiveValue() public {
        _assertApproveReverts(OUTSIDER, RECIPIENT_A, 1);
    }

    function test_RevertWhen_AuthorityApprovesPositiveValue() public {
        _assertApproveReverts(AUTHORITY, RECIPIENT_A, 1);
    }

    function test_RevertWhen_ApprovalUsesZeroValue() public {
        _assertApproveReverts(OUTSIDER, RECIPIENT_A, 0);
    }

    function test_RevertWhen_ApprovalTargetsZeroAddress() public {
        _assertApproveReverts(OUTSIDER, address(0), 1);
    }

    function test_AllowanceAlwaysRemainsZero() public {
        assertEq(alert.allowance(RECIPIENT_A, RECIPIENT_B), 0);

        _assertApproveReverts(RECIPIENT_A, RECIPIENT_B, type(uint256).max);

        assertEq(alert.allowance(RECIPIENT_A, RECIPIENT_B), 0);
        assertEq(alert.allowance(AUTHORITY, address(0)), 0);
    }

    function test_AuthorityFinalizesSuccessfully() public {
        vm.expectEmit(true, false, false, true, address(alert));
        emit RepMigrationAlert.DistributionFinalized(AUTHORITY, 0);

        vm.prank(AUTHORITY);
        alert.finalize();

        assertTrue(alert.finalized());
        assertEq(alert.totalIssued(), 0);
        assertEq(alert.totalSupply(), 0);
        assertEq(alert.authority(), AUTHORITY);
    }

    function test_RevertWhen_UnauthorizedCallerFinalizes() public {
        vm.prank(OUTSIDER);
        vm.expectRevert(abi.encodeWithSelector(RepMigrationAlert.UnauthorizedCaller.selector, OUTSIDER));
        alert.finalize();

        assertFalse(alert.finalized());
        assertEq(alert.totalIssued(), 0);
        assertEq(alert.totalSupply(), 0);
    }

    function test_RevertWhen_FinalizationIsRepeated() public {
        vm.prank(AUTHORITY);
        alert.finalize();

        uint256 issuedBefore = alert.totalIssued();
        uint256 supplyBefore = alert.totalSupply();
        vm.recordLogs();
        vm.prank(AUTHORITY);
        vm.expectRevert(RepMigrationAlert.FinalizationAlreadyCompleted.selector);
        alert.finalize();
        Vm.Log[] memory logs = vm.getRecordedLogs();

        assertTrue(alert.finalized());
        assertEq(alert.totalIssued(), issuedBefore);
        assertEq(alert.totalSupply(), supplyBefore);
        assertEq(logs.length, 0);
    }

    function test_FinalizeBelowCapPreservesBalancesAndSupply() public {
        _distribute(RECIPIENT_A, RECIPIENT_B);
        uint256 issuedBefore = alert.totalIssued();
        uint256 supplyBefore = alert.totalSupply();

        vm.prank(AUTHORITY);
        alert.finalize();

        assertTrue(alert.finalized());
        assertEq(alert.balanceOf(RECIPIENT_A), 1);
        assertEq(alert.balanceOf(RECIPIENT_B), 1);
        assertTrue(alert.wasAlerted(RECIPIENT_A));
        assertTrue(alert.wasAlerted(RECIPIENT_B));
        assertEq(alert.totalIssued(), issuedBefore);
        assertEq(alert.totalSupply(), supplyBefore);
        assertLt(alert.totalIssued(), alert.distributionCap());
    }

    function test_FinalizeExactlyAtCapPreservesBalancesAndSupply() public {
        RepMigrationAlert cappedAlert = new RepMigrationAlert(AUTHORITY, 2);
        vm.startPrank(AUTHORITY);
        cappedAlert.distribute(_recipients(RECIPIENT_A, RECIPIENT_B));
        cappedAlert.finalize();
        vm.stopPrank();

        assertTrue(cappedAlert.finalized());
        assertEq(cappedAlert.balanceOf(RECIPIENT_A), 1);
        assertEq(cappedAlert.balanceOf(RECIPIENT_B), 1);
        assertTrue(cappedAlert.wasAlerted(RECIPIENT_A));
        assertTrue(cappedAlert.wasAlerted(RECIPIENT_B));
        assertEq(cappedAlert.totalIssued(), cappedAlert.distributionCap());
        assertEq(cappedAlert.totalSupply(), cappedAlert.distributionCap());
    }

    function test_FinalizeWithZeroSupply() public {
        vm.prank(AUTHORITY);
        alert.finalize();

        assertTrue(alert.finalized());
        assertEq(alert.totalIssued(), 0);
        assertEq(alert.totalSupply(), 0);
    }

    function test_FinalizationEventContainsAuthorityAndFinalIssuedAfterBurn() public {
        _distribute(RECIPIENT_A, RECIPIENT_B, RECIPIENT_C);
        vm.prank(RECIPIENT_B);
        alert.burn();

        vm.recordLogs();
        vm.prank(AUTHORITY);
        alert.finalize();
        Vm.Log[] memory logs = vm.getRecordedLogs();

        assertEq(logs.length, 1);
        assertEq(logs[0].emitter, address(alert));
        assertEq(logs[0].topics.length, 2);
        assertEq(logs[0].topics[0], FINALIZED_TOPIC);
        assertEq(logs[0].topics[1], bytes32(uint256(uint160(AUTHORITY))));
        assertEq(abi.decode(logs[0].data, (uint256)), 3);
        assertEq(alert.totalIssued(), 3);
        assertEq(alert.totalSupply(), 2);
    }

    function test_FinalizationAfterBurnPreservesBothCounters() public {
        _distribute(RECIPIENT_A, RECIPIENT_B, RECIPIENT_C);
        vm.prank(RECIPIENT_A);
        alert.burn();
        uint256 issuedBefore = alert.totalIssued();
        uint256 supplyBefore = alert.totalSupply();

        vm.prank(AUTHORITY);
        alert.finalize();

        assertTrue(alert.finalized());
        assertEq(alert.totalIssued(), issuedBefore);
        assertEq(alert.totalSupply(), supplyBefore);
        assertEq(alert.balanceOf(RECIPIENT_A), 0);
        assertTrue(alert.wasAlerted(RECIPIENT_A));
    }

    function test_FinalizationPermanentlyClosesDistribution() public {
        _distribute(RECIPIENT_A);
        vm.prank(AUTHORITY);
        alert.finalize();

        _assertDistributionRevertsAtomically(
            AUTHORITY,
            _recipients(RECIPIENT_B),
            abi.encodeWithSelector(RepMigrationAlert.DistributionAlreadyClosed.selector)
        );

        vm.prank(AUTHORITY);
        vm.expectRevert(RepMigrationAlert.FinalizationAlreadyCompleted.selector);
        alert.finalize();

        assertTrue(alert.finalized());
        assertEq(alert.balanceOf(RECIPIENT_A), 1);
        assertEq(alert.balanceOf(RECIPIENT_B), 0);
        assertTrue(alert.wasAlerted(RECIPIENT_A));
        assertFalse(alert.wasAlerted(RECIPIENT_B));
        assertEq(alert.totalIssued(), 1);
        assertEq(alert.totalSupply(), 1);
    }

    function test_MovementAndApprovalRemainDisabledAfterFinalization() public {
        _distribute(RECIPIENT_A);
        vm.prank(AUTHORITY);
        alert.finalize();

        _assertTransferReverts(RECIPIENT_A, RECIPIENT_B, 1);
        _assertTransferFromReverts(AUTHORITY, RECIPIENT_A, RECIPIENT_B, 1);
        _assertApproveReverts(RECIPIENT_A, AUTHORITY, 1);

        assertEq(alert.balanceOf(RECIPIENT_A), 1);
        assertEq(alert.balanceOf(RECIPIENT_B), 0);
        assertTrue(alert.wasAlerted(RECIPIENT_A));
        assertFalse(alert.wasAlerted(RECIPIENT_B));
        assertEq(alert.totalIssued(), 1);
        assertEq(alert.totalSupply(), 1);
        assertEq(alert.allowance(RECIPIENT_A, AUTHORITY), 0);
    }

    function test_NoCallableSelectorCanRestoreIssuance() public {
        vm.prank(AUTHORITY);
        alert.finalize();

        (bool unfinalizeSuccess,) = address(alert).call(abi.encodeWithSignature("unfinalize()"));
        (bool mintSuccess,) = address(alert).call(abi.encodeWithSignature("mint(address)", RECIPIENT_A));
        (bool ownerSuccess,) = address(alert).call(abi.encodeWithSignature("owner()"));
        (bool burnAmountSuccess,) = address(alert).call(abi.encodeWithSignature("burn(uint256)", 1));
        (bool burnFromSuccess,) =
            address(alert).call(abi.encodeWithSignature("burnFrom(address,uint256)", RECIPIENT_A, 1));

        assertFalse(unfinalizeSuccess);
        assertFalse(mintSuccess);
        assertFalse(ownerSuccess);
        assertFalse(burnAmountSuccess);
        assertFalse(burnFromSuccess);
        assertTrue(alert.finalized());
        assertEq(alert.totalIssued(), 0);
        assertEq(alert.totalSupply(), 0);
    }

    function test_DirectEthTransferFails() public {
        vm.deal(address(this), 1 ether);

        (bool success,) = address(alert).call{value: 1 wei}("");

        assertFalse(success);
        assertEq(address(alert).balance, 0);
        assertEq(alert.totalIssued(), 0);
        assertEq(alert.totalSupply(), 0);
        assertFalse(alert.finalized());
    }

    function test_ForcedEthBalanceDoesNotAffectBehavior() public {
        vm.deal(address(alert), 1 ether);

        _distribute(RECIPIENT_A);
        vm.prank(AUTHORITY);
        alert.finalize();

        assertEq(address(alert).balance, 1 ether);
        assertEq(alert.balanceOf(RECIPIENT_A), 1);
        assertTrue(alert.wasAlerted(RECIPIENT_A));
        assertEq(alert.totalIssued(), 1);
        assertEq(alert.totalSupply(), 1);
        assertTrue(alert.finalized());
    }

    function _distribute(address recipient) internal {
        vm.prank(AUTHORITY);
        alert.distribute(_recipients(recipient));
    }

    function _distribute(address recipientA, address recipientB) internal {
        vm.prank(AUTHORITY);
        alert.distribute(_recipients(recipientA, recipientB));
    }

    function _distribute(address recipientA, address recipientB, address recipientC) internal {
        vm.prank(AUTHORITY);
        alert.distribute(_recipients(recipientA, recipientB, recipientC));
    }

    function _assertDistributionRevertsAtomically(address caller, address[] memory recipients, bytes memory revertData)
        internal
    {
        _assertDistributionRevertsAtomically(alert, caller, recipients, revertData);
    }

    function _assertDistributionRevertsAtomically(
        RepMigrationAlert target,
        address caller,
        address[] memory recipients,
        bytes memory revertData
    ) internal {
        uint256 issuedBefore = target.totalIssued();
        uint256 supplyBefore = target.totalSupply();
        bool finalizedBefore = target.finalized();
        uint256[] memory balancesBefore = new uint256[](recipients.length);
        bool[] memory alertedBefore = new bool[](recipients.length);
        for (uint256 index = 0; index < recipients.length; index++) {
            balancesBefore[index] = target.balanceOf(recipients[index]);
            alertedBefore[index] = target.wasAlerted(recipients[index]);
        }

        vm.prank(caller);
        vm.expectRevert(revertData);
        target.distribute(recipients);

        assertEq(target.totalIssued(), issuedBefore);
        assertEq(target.totalSupply(), supplyBefore);
        assertEq(target.finalized(), finalizedBefore);
        for (uint256 index = 0; index < recipients.length; index++) {
            assertEq(target.balanceOf(recipients[index]), balancesBefore[index]);
            assertEq(target.wasAlerted(recipients[index]), alertedBefore[index]);
        }
        assertEq(target.balanceOf(address(0)), 0);
        assertFalse(target.wasAlerted(address(0)));
    }

    function _assertBurnReverts(address caller) internal {
        uint256 issuedBefore = alert.totalIssued();
        uint256 supplyBefore = alert.totalSupply();
        bool finalizedBefore = alert.finalized();
        uint256 balanceBefore = alert.balanceOf(caller);
        bool alertedBefore = alert.wasAlerted(caller);

        vm.recordLogs();
        vm.prank(caller);
        vm.expectRevert(abi.encodeWithSelector(RepMigrationAlert.NoAlertBalance.selector, caller));
        alert.burn();
        Vm.Log[] memory logs = vm.getRecordedLogs();

        assertEq(logs.length, 0);
        assertEq(alert.totalIssued(), issuedBefore);
        assertEq(alert.totalSupply(), supplyBefore);
        assertEq(alert.finalized(), finalizedBefore);
        assertEq(alert.balanceOf(caller), balanceBefore);
        assertEq(alert.wasAlerted(caller), alertedBefore);
    }

    function _assertTransferReverts(address caller, address recipient, uint256 value) internal {
        uint256 issuedBefore = alert.totalIssued();
        uint256 supplyBefore = alert.totalSupply();
        uint256 callerBalanceBefore = alert.balanceOf(caller);
        uint256 recipientBalanceBefore = alert.balanceOf(recipient);
        bool callerAlertedBefore = alert.wasAlerted(caller);
        bool recipientAlertedBefore = alert.wasAlerted(recipient);

        vm.recordLogs();
        vm.prank(caller);
        vm.expectRevert(RepMigrationAlert.TransferDisabled.selector);
        alert.transfer(recipient, value);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        assertEq(logs.length, 0);
        assertEq(alert.totalIssued(), issuedBefore);
        assertEq(alert.totalSupply(), supplyBefore);
        assertEq(alert.balanceOf(caller), callerBalanceBefore);
        assertEq(alert.balanceOf(recipient), recipientBalanceBefore);
        assertEq(alert.wasAlerted(caller), callerAlertedBefore);
        assertEq(alert.wasAlerted(recipient), recipientAlertedBefore);
    }

    function _assertTransferFromReverts(address caller, address owner, address recipient, uint256 value) internal {
        uint256 issuedBefore = alert.totalIssued();
        uint256 supplyBefore = alert.totalSupply();
        uint256 ownerBalanceBefore = alert.balanceOf(owner);
        uint256 recipientBalanceBefore = alert.balanceOf(recipient);
        bool ownerAlertedBefore = alert.wasAlerted(owner);
        bool recipientAlertedBefore = alert.wasAlerted(recipient);

        vm.recordLogs();
        vm.prank(caller);
        vm.expectRevert(RepMigrationAlert.TransferDisabled.selector);
        alert.transferFrom(owner, recipient, value);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        assertEq(logs.length, 0);
        assertEq(alert.totalIssued(), issuedBefore);
        assertEq(alert.totalSupply(), supplyBefore);
        assertEq(alert.balanceOf(owner), ownerBalanceBefore);
        assertEq(alert.balanceOf(recipient), recipientBalanceBefore);
        assertEq(alert.wasAlerted(owner), ownerAlertedBefore);
        assertEq(alert.wasAlerted(recipient), recipientAlertedBefore);
    }

    function _assertApproveReverts(address caller, address spender, uint256 value) internal {
        uint256 issuedBefore = alert.totalIssued();
        uint256 supplyBefore = alert.totalSupply();
        uint256 callerBalanceBefore = alert.balanceOf(caller);
        bool callerAlertedBefore = alert.wasAlerted(caller);
        bool spenderAlertedBefore = alert.wasAlerted(spender);

        vm.recordLogs();
        vm.prank(caller);
        vm.expectRevert(RepMigrationAlert.ApprovalDisabled.selector);
        alert.approve(spender, value);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        assertEq(logs.length, 0);
        assertEq(alert.totalIssued(), issuedBefore);
        assertEq(alert.totalSupply(), supplyBefore);
        assertEq(alert.balanceOf(caller), callerBalanceBefore);
        assertEq(alert.wasAlerted(caller), callerAlertedBefore);
        assertEq(alert.wasAlerted(spender), spenderAlertedBefore);
        assertEq(alert.allowance(caller, spender), 0);
    }

    function _recipients(address recipient) internal pure returns (address[] memory recipients) {
        recipients = new address[](1);
        recipients[0] = recipient;
    }

    function _recipients(address recipientA, address recipientB) internal pure returns (address[] memory recipients) {
        recipients = new address[](2);
        recipients[0] = recipientA;
        recipients[1] = recipientB;
    }

    function _recipients(address recipientA, address recipientB, address recipientC)
        internal
        pure
        returns (address[] memory recipients)
    {
        recipients = new address[](3);
        recipients[0] = recipientA;
        recipients[1] = recipientB;
        recipients[2] = recipientC;
    }
}

contract RepMigrationAlertGasTest is Test {
    address internal constant AUTHORITY = address(0xA11CE);
    address internal constant NEVER_ALERTED = address(0xBAD);
    uint160 internal constant GAS_ADDRESS_BASE = uint160(0x1111111111111111111111111111111111111111);
    uint256 internal constant BASE_TRANSACTION_GAS = 21_000;

    function test_Gas_Deployment() public {
        vm.startSnapshotGas("RepMigrationAlert", "deployment");
        RepMigrationAlert target = new RepMigrationAlert(AUTHORITY, 500);
        uint256 deploymentGas = vm.stopSnapshotGas();

        emit log_named_string("measurement", "deployment");
        emit log_named_uint("deployment gas", deploymentGas);
        vm.snapshotValue("RepMigrationAlert-deployment-gas", "deployment", deploymentGas);

        assertEq(target.authority(), AUTHORITY);
        assertEq(target.distributionCap(), 500);
        assertEq(target.totalIssued(), 0);
        assertEq(target.totalSupply(), 0);
    }

    function test_Gas_Distribute_001() public {
        _measureSuccessfulDistribution(1, "distribute-001");
    }

    function test_Gas_Distribute_010() public {
        _measureSuccessfulDistribution(10, "distribute-010");
    }

    function test_Gas_Distribute_025() public {
        _measureSuccessfulDistribution(25, "distribute-025");
    }

    function test_Gas_Distribute_050() public {
        _measureSuccessfulDistribution(50, "distribute-050");
    }

    function test_Gas_Distribute_100() public {
        _measureSuccessfulDistribution(100, "distribute-100");
    }

    function test_Gas_Distribute_200() public {
        _measureSuccessfulDistribution(200, "distribute-200");
    }

    function test_Gas_Distribute_500() public {
        _measureSuccessfulDistribution(500, "distribute-500");
    }

    function test_Gas_EmptyArrayRevert() public {
        RepMigrationAlert target = new RepMigrationAlert(AUTHORITY, 500);
        _measureCall(
            target,
            AUTHORITY,
            abi.encodeCall(target.distribute, (new address[](0))),
            false,
            RepMigrationAlert.EmptyRecipientArray.selector,
            "revert-empty"
        );
    }

    function test_Gas_DuplicateAtStartRevert() public {
        address[] memory recipients = _gasRecipients(500);
        recipients[1] = recipients[0];
        RepMigrationAlert target = new RepMigrationAlert(AUTHORITY, 500);

        _measureCall(
            target,
            AUTHORITY,
            abi.encodeCall(target.distribute, (recipients)),
            false,
            RepMigrationAlert.RecipientAlreadyNotified.selector,
            "revert-duplicate-start"
        );
    }

    function test_Gas_DuplicateInMiddleRevert() public {
        address[] memory recipients = _gasRecipients(500);
        recipients[250] = recipients[249];
        RepMigrationAlert target = new RepMigrationAlert(AUTHORITY, 500);

        _measureCall(
            target,
            AUTHORITY,
            abi.encodeCall(target.distribute, (recipients)),
            false,
            RepMigrationAlert.RecipientAlreadyNotified.selector,
            "revert-duplicate-middle"
        );
    }

    function test_Gas_DuplicateAtEndRevert() public {
        address[] memory recipients = _gasRecipients(500);
        recipients[499] = recipients[498];
        RepMigrationAlert target = new RepMigrationAlert(AUTHORITY, 500);

        _measureCall(
            target,
            AUTHORITY,
            abi.encodeCall(target.distribute, (recipients)),
            false,
            RepMigrationAlert.RecipientAlreadyNotified.selector,
            "revert-duplicate-end"
        );
    }

    function test_Gas_PreviouslyNotifiedRecipientRevert() public {
        RepMigrationAlert target = new RepMigrationAlert(AUTHORITY, 501);
        address[] memory initialRecipient = new address[](1);
        initialRecipient[0] = 0x2222222222222222222222222222222222222222;
        vm.prank(AUTHORITY);
        target.distribute(initialRecipient);

        address[] memory recipients = _gasRecipients(500);
        recipients[499] = initialRecipient[0];
        _measureCall(
            target,
            AUTHORITY,
            abi.encodeCall(target.distribute, (recipients)),
            false,
            RepMigrationAlert.RecipientAlreadyNotified.selector,
            "revert-prior-recipient"
        );
    }

    function test_Gas_ZeroRecipientRevert() public {
        address[] memory recipients = _gasRecipients(500);
        recipients[499] = address(0);
        RepMigrationAlert target = new RepMigrationAlert(AUTHORITY, 500);

        _measureCall(
            target,
            AUTHORITY,
            abi.encodeCall(target.distribute, (recipients)),
            false,
            RepMigrationAlert.ZeroRecipient.selector,
            "revert-zero-recipient"
        );
    }

    function test_Gas_CapBoundarySuccess() public {
        uint256 cap = 500;
        RepMigrationAlert target = new RepMigrationAlert(AUTHORITY, cap);
        bytes memory callData = abi.encodeCall(target.distribute, (_gasRecipients(cap)));

        _measureCall(target, AUTHORITY, callData, true, bytes4(0), "cap-boundary-success");
        assertEq(target.totalIssued(), cap);
        assertEq(target.totalSupply(), cap);
    }

    function test_Gas_CapOverflowRevert() public {
        RepMigrationAlert target = new RepMigrationAlert(AUTHORITY, 499);
        bytes memory callData = abi.encodeCall(target.distribute, (_gasRecipients(500)));

        _measureCall(
            target,
            AUTHORITY,
            callData,
            false,
            RepMigrationAlert.DistributionCapExceeded.selector,
            "revert-cap-overflow"
        );
    }

    function test_Gas_UnauthorizedCallRevert() public {
        RepMigrationAlert target = new RepMigrationAlert(AUTHORITY, 500);

        _measureCall(
            target,
            NEVER_ALERTED,
            abi.encodeCall(target.distribute, (_gasRecipients(500))),
            false,
            RepMigrationAlert.UnauthorizedCaller.selector,
            "revert-unauthorized"
        );
    }

    function test_Gas_FirstBurn() public {
        RepMigrationAlert target = new RepMigrationAlert(AUTHORITY, 1);
        address recipient = _gasRecipients(1)[0];
        vm.prank(AUTHORITY);
        target.distribute(_singleRecipient(recipient));

        _measureCall(target, recipient, abi.encodeCall(target.burn, ()), true, bytes4(0), "burn-first");
        assertEq(target.totalIssued(), 1);
        assertEq(target.totalSupply(), 0);
        assertTrue(target.wasAlerted(recipient));
    }

    function test_Gas_BurnAfterMultipleIssuances() public {
        RepMigrationAlert target = new RepMigrationAlert(AUTHORITY, 100);
        address[] memory recipients = _gasRecipients(100);
        vm.prank(AUTHORITY);
        target.distribute(recipients);

        _measureCall(
            target, recipients[99], abi.encodeCall(target.burn, ()), true, bytes4(0), "burn-after-multiple-issuances"
        );
        assertEq(target.totalIssued(), 100);
        assertEq(target.totalSupply(), 99);
    }

    function test_Gas_BurnBeforeFinalization() public {
        RepMigrationAlert target = new RepMigrationAlert(AUTHORITY, 10);
        address[] memory recipients = _gasRecipients(10);
        vm.prank(AUTHORITY);
        target.distribute(recipients);

        _measureCall(
            target, recipients[0], abi.encodeCall(target.burn, ()), true, bytes4(0), "burn-before-finalization"
        );
        assertFalse(target.finalized());
        assertEq(target.totalIssued(), 10);
        assertEq(target.totalSupply(), 9);
    }

    function test_Gas_BurnAfterFinalization() public {
        RepMigrationAlert target = new RepMigrationAlert(AUTHORITY, 10);
        address[] memory recipients = _gasRecipients(10);
        vm.startPrank(AUTHORITY);
        target.distribute(recipients);
        target.finalize();
        vm.stopPrank();

        _measureCall(target, recipients[0], abi.encodeCall(target.burn, ()), true, bytes4(0), "burn-after-finalization");
        assertTrue(target.finalized());
        assertEq(target.totalIssued(), 10);
        assertEq(target.totalSupply(), 9);
    }

    function test_Gas_NeverAlertedBurnRevert() public {
        RepMigrationAlert target = new RepMigrationAlert(AUTHORITY, 1);

        _measureCall(
            target,
            NEVER_ALERTED,
            abi.encodeCall(target.burn, ()),
            false,
            RepMigrationAlert.NoAlertBalance.selector,
            "revert-burn-never-alerted"
        );
    }

    function test_Gas_RepeatedBurnRevert() public {
        RepMigrationAlert target = new RepMigrationAlert(AUTHORITY, 1);
        address recipient = _gasRecipients(1)[0];
        vm.prank(AUTHORITY);
        target.distribute(_singleRecipient(recipient));
        vm.prank(recipient);
        target.burn();

        _measureCall(
            target,
            recipient,
            abi.encodeCall(target.burn, ()),
            false,
            RepMigrationAlert.NoAlertBalance.selector,
            "revert-burn-repeated"
        );
    }

    function test_Gas_ReissueBurnedRecipientRevert() public {
        RepMigrationAlert target = new RepMigrationAlert(AUTHORITY, 2);
        address recipient = _gasRecipients(1)[0];
        address[] memory recipientArray = _singleRecipient(recipient);
        vm.prank(AUTHORITY);
        target.distribute(recipientArray);
        vm.prank(recipient);
        target.burn();

        _measureCall(
            target,
            AUTHORITY,
            abi.encodeCall(target.distribute, (recipientArray)),
            false,
            RepMigrationAlert.RecipientAlreadyNotified.selector,
            "revert-reissue-burned"
        );
    }

    function test_Gas_CapBoundaryAfterBurns() public {
        RepMigrationAlert target = new RepMigrationAlert(AUTHORITY, 2);
        address[] memory recipients = _gasRecipients(2);
        vm.prank(AUTHORITY);
        target.distribute(_singleRecipient(recipients[0]));
        vm.prank(recipients[0]);
        target.burn();

        _measureCall(
            target,
            AUTHORITY,
            abi.encodeCall(target.distribute, (_singleRecipient(recipients[1]))),
            true,
            bytes4(0),
            "cap-boundary-after-burns"
        );
        assertEq(target.totalIssued(), 2);
        assertEq(target.totalSupply(), 1);
    }

    function test_Gas_CapOverflowAfterBurnsRevert() public {
        RepMigrationAlert target = new RepMigrationAlert(AUTHORITY, 1);
        address[] memory recipients = _gasRecipients(2);
        vm.prank(AUTHORITY);
        target.distribute(_singleRecipient(recipients[0]));
        vm.prank(recipients[0]);
        target.burn();

        _measureCall(
            target,
            AUTHORITY,
            abi.encodeCall(target.distribute, (_singleRecipient(recipients[1]))),
            false,
            RepMigrationAlert.DistributionCapExceeded.selector,
            "revert-cap-overflow-after-burns"
        );
        assertEq(target.totalIssued(), 1);
        assertEq(target.totalSupply(), 0);
    }

    function test_Gas_Finalization() public {
        RepMigrationAlert target = new RepMigrationAlert(AUTHORITY, 500);
        vm.prank(AUTHORITY);
        target.distribute(_gasRecipients(100));

        _measureCall(target, AUTHORITY, abi.encodeCall(target.finalize, ()), true, bytes4(0), "finalize-success");
    }

    function test_Gas_FinalizationAfterBurns() public {
        RepMigrationAlert target = new RepMigrationAlert(AUTHORITY, 100);
        address[] memory recipients = _gasRecipients(100);
        vm.prank(AUTHORITY);
        target.distribute(recipients);
        vm.prank(recipients[0]);
        target.burn();

        _measureCall(target, AUTHORITY, abi.encodeCall(target.finalize, ()), true, bytes4(0), "finalize-after-burns");
        assertEq(target.totalIssued(), 100);
        assertEq(target.totalSupply(), 99);
        assertTrue(target.finalized());
    }

    function test_Gas_RepeatedFinalizationRevert() public {
        RepMigrationAlert target = new RepMigrationAlert(AUTHORITY, 500);
        vm.startPrank(AUTHORITY);
        target.distribute(_gasRecipients(100));
        target.finalize();
        vm.stopPrank();

        _measureCall(
            target,
            AUTHORITY,
            abi.encodeCall(target.finalize, ()),
            false,
            RepMigrationAlert.FinalizationAlreadyCompleted.selector,
            "revert-finalize-repeated"
        );
    }

    function _measureSuccessfulDistribution(uint256 size, string memory label) internal {
        RepMigrationAlert target = new RepMigrationAlert(AUTHORITY, size);
        bytes memory callData = abi.encodeCall(target.distribute, (_gasRecipients(size)));

        _measureCall(target, AUTHORITY, callData, true, bytes4(0), label);
        assertEq(target.totalIssued(), size);
        assertEq(target.totalSupply(), size);
        assertTrue(target.wasAlerted(_gasRecipients(size)[0]));
    }

    function _measureCall(
        RepMigrationAlert target,
        address caller,
        bytes memory callData,
        bool expectedSuccess,
        bytes4 expectedError,
        string memory label
    ) internal {
        vm.cool(address(target));
        vm.prank(caller);
        (bool success, bytes memory returnData) = address(target).call(callData);
        uint256 executionGas = vm.snapshotGasLastCall("RepMigrationAlert", label);
        uint256 calldataGas = _calldataGas(callData);
        uint256 calldataTokens = calldataGas / 4;
        uint256 osakaFloorDataGas = calldataTokens * 10;
        uint256 standardTransactionGas = BASE_TRANSACTION_GAS + calldataGas + executionGas;
        uint256 osakaTransactionGas = BASE_TRANSACTION_GAS + _max(calldataGas + executionGas, osakaFloorDataGas);

        emit log_named_string("measurement", label);
        emit log_named_uint("calldata bytes", callData.length);
        emit log_named_uint("calldata gas", calldataGas);
        emit log_named_uint("Osaka floor data gas", osakaFloorDataGas);
        emit log_named_uint("execution gas", executionGas);
        emit log_named_uint("standard transaction gas", standardTransactionGas);
        emit log_named_uint("Osaka transaction gas", osakaTransactionGas);

        vm.snapshotValue("RepMigrationAlert-calldata-bytes", label, callData.length);
        vm.snapshotValue("RepMigrationAlert-calldata-gas", label, calldataGas);
        vm.snapshotValue("RepMigrationAlert-osaka-floor-data-gas", label, osakaFloorDataGas);
        vm.snapshotValue("RepMigrationAlert-execution-gas", label, executionGas);
        vm.snapshotValue("RepMigrationAlert-standard-transaction-gas", label, standardTransactionGas);
        vm.snapshotValue("RepMigrationAlert-osaka-transaction-gas", label, osakaTransactionGas);

        assertEq(success, expectedSuccess);
        if (!expectedSuccess) {
            assertGe(returnData.length, 4);
            bytes memory encodedExpectedError = abi.encodePacked(expectedError);
            for (uint256 index = 0; index < 4; index++) {
                assertEq(returnData[index], encodedExpectedError[index]);
            }
        }
    }

    function _calldataGas(bytes memory callData) internal pure returns (uint256 gasCost) {
        for (uint256 index = 0; index < callData.length; index++) {
            gasCost += callData[index] == bytes1(0) ? 4 : 16;
        }
    }

    function _gasRecipients(uint256 count) internal pure returns (address[] memory recipients) {
        recipients = new address[](count);
        uint160 highSuffixByte = 1;
        uint160 lowSuffixByte = 1;
        for (uint256 index = 0; index < count; index++) {
            uint160 suffix = (highSuffixByte << 8) | lowSuffixByte;
            recipients[index] = address((GAS_ADDRESS_BASE & ~uint160(type(uint16).max)) | suffix);
            lowSuffixByte++;
            if (lowSuffixByte == 256) {
                lowSuffixByte = 1;
                highSuffixByte++;
            }
        }
    }

    function _singleRecipient(address recipient) internal pure returns (address[] memory recipients) {
        recipients = new address[](1);
        recipients[0] = recipient;
    }

    function _max(uint256 left, uint256 right) internal pure returns (uint256) {
        return left > right ? left : right;
    }
}
