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
        assertEq(alert.name(), "REP MIGRATION ALERT");
        assertEq(alert.symbol(), "CHECKREP");
        assertEq(alert.decimals(), 0);
        assertEq(alert.totalSupply(), 0);
        assertEq(alert.balanceOf(RECIPIENT_A), 0);
        assertEq(alert.balanceOf(address(0)), 0);
        assertEq(alert.allowance(RECIPIENT_A, RECIPIENT_B), 0);
        assertEq(alert.authority(), AUTHORITY);
        assertEq(alert.distributionCap(), DISTRIBUTION_CAP);
        assertFalse(alert.finalized());
        assertEq(alert.balanceOf(DEPLOYER), 0);
        assertEq(alert.balanceOf(AUTHORITY), 0);
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
        assertEq(sameAddressAlert.totalSupply(), 1);
        assertTrue(sameAddressAlert.finalized());
    }

    function test_DistributeSingleRecipient() public {
        vm.expectEmit(true, true, false, true, address(alert));
        emit RepMigrationAlert.Transfer(address(0), RECIPIENT_A, 1);

        vm.prank(AUTHORITY);
        alert.distribute(_recipients(RECIPIENT_A));

        assertEq(alert.balanceOf(RECIPIENT_A), 1);
        assertEq(alert.balanceOf(RECIPIENT_B), 0);
        assertEq(alert.totalSupply(), 1);
        assertFalse(alert.finalized());
    }

    function test_OneAddressCanaryUsesDistributionPath() public {
        address[] memory canary = _recipients(RECIPIENT_A);

        vm.prank(AUTHORITY);
        alert.distribute(canary);

        assertEq(alert.balanceOf(RECIPIENT_A), 1);
        assertEq(alert.totalSupply(), canary.length);
    }

    function test_DistributeMultipleRecipients() public {
        address[] memory recipients = _recipients(RECIPIENT_A, RECIPIENT_B, RECIPIENT_C);

        vm.prank(AUTHORITY);
        alert.distribute(recipients);

        assertEq(alert.balanceOf(RECIPIENT_A), 1);
        assertEq(alert.balanceOf(RECIPIENT_B), 1);
        assertEq(alert.balanceOf(RECIPIENT_C), 1);
        assertEq(alert.balanceOf(OUTSIDER), 0);
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
        assertEq(alert.totalSupply(), 3);
    }

    function test_DistributeToContractRecipient() public {
        ContractRecipient contractRecipient = new ContractRecipient();

        vm.prank(AUTHORITY);
        alert.distribute(_recipients(address(contractRecipient)));

        assertEq(alert.balanceOf(address(contractRecipient)), 1);
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

        assertEq(cappedAlert.totalSupply(), cappedAlert.distributionCap());
        assertEq(cappedAlert.balanceOf(RECIPIENT_A), 1);
        assertEq(cappedAlert.balanceOf(RECIPIENT_B), 1);
        assertEq(cappedAlert.balanceOf(RECIPIENT_C), 1);
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

    function test_RevertWhen_PreviouslyNotifiedRecipientIsMixedWithNewRecipients() public {
        _distribute(RECIPIENT_B);
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

    function test_RevertWhen_DistributingAfterFinalization() public {
        vm.prank(AUTHORITY);
        alert.finalize();

        _assertDistributionRevertsAtomically(
            AUTHORITY,
            _recipients(RECIPIENT_A),
            abi.encodeWithSelector(RepMigrationAlert.DistributionAlreadyClosed.selector)
        );
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
        assertEq(alert.totalSupply(), 0);
        assertEq(alert.authority(), AUTHORITY);
    }

    function test_RevertWhen_UnauthorizedCallerFinalizes() public {
        vm.prank(OUTSIDER);
        vm.expectRevert(abi.encodeWithSelector(RepMigrationAlert.UnauthorizedCaller.selector, OUTSIDER));
        alert.finalize();

        assertFalse(alert.finalized());
        assertEq(alert.totalSupply(), 0);
    }

    function test_RevertWhen_FinalizationIsRepeated() public {
        vm.prank(AUTHORITY);
        alert.finalize();

        uint256 supplyBefore = alert.totalSupply();
        vm.recordLogs();
        vm.prank(AUTHORITY);
        vm.expectRevert(RepMigrationAlert.FinalizationAlreadyCompleted.selector);
        alert.finalize();
        Vm.Log[] memory logs = vm.getRecordedLogs();

        assertTrue(alert.finalized());
        assertEq(alert.totalSupply(), supplyBefore);
        assertEq(logs.length, 0);
    }

    function test_FinalizeBelowCapPreservesBalancesAndSupply() public {
        _distribute(RECIPIENT_A, RECIPIENT_B);
        uint256 supplyBefore = alert.totalSupply();

        vm.prank(AUTHORITY);
        alert.finalize();

        assertTrue(alert.finalized());
        assertEq(alert.balanceOf(RECIPIENT_A), 1);
        assertEq(alert.balanceOf(RECIPIENT_B), 1);
        assertEq(alert.totalSupply(), supplyBefore);
        assertLt(alert.totalSupply(), alert.distributionCap());
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
        assertEq(cappedAlert.totalSupply(), cappedAlert.distributionCap());
    }

    function test_FinalizeWithZeroSupply() public {
        vm.prank(AUTHORITY);
        alert.finalize();

        assertTrue(alert.finalized());
        assertEq(alert.totalSupply(), 0);
    }

    function test_FinalizationEventContainsAuthorityAndFinalSupply() public {
        _distribute(RECIPIENT_A, RECIPIENT_B, RECIPIENT_C);

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
        assertEq(alert.totalSupply(), 1);
        assertEq(alert.allowance(RECIPIENT_A, AUTHORITY), 0);
    }

    function test_NoCallableSelectorCanRestoreIssuance() public {
        vm.prank(AUTHORITY);
        alert.finalize();

        (bool unfinalizeSuccess,) = address(alert).call(abi.encodeWithSignature("unfinalize()"));
        (bool mintSuccess,) = address(alert).call(abi.encodeWithSignature("mint(address)", RECIPIENT_A));
        (bool ownerSuccess,) = address(alert).call(abi.encodeWithSignature("owner()"));

        assertFalse(unfinalizeSuccess);
        assertFalse(mintSuccess);
        assertFalse(ownerSuccess);
        assertTrue(alert.finalized());
        assertEq(alert.totalSupply(), 0);
    }

    function test_DirectEthTransferFails() public {
        vm.deal(address(this), 1 ether);

        (bool success,) = address(alert).call{value: 1 wei}("");

        assertFalse(success);
        assertEq(address(alert).balance, 0);
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
        uint256 supplyBefore = target.totalSupply();
        bool finalizedBefore = target.finalized();
        uint256[] memory balancesBefore = new uint256[](recipients.length);
        for (uint256 index = 0; index < recipients.length; index++) {
            balancesBefore[index] = target.balanceOf(recipients[index]);
        }

        vm.prank(caller);
        vm.expectRevert(revertData);
        target.distribute(recipients);

        assertEq(target.totalSupply(), supplyBefore);
        assertEq(target.finalized(), finalizedBefore);
        for (uint256 index = 0; index < recipients.length; index++) {
            assertEq(target.balanceOf(recipients[index]), balancesBefore[index]);
        }
        assertEq(target.balanceOf(address(0)), 0);
    }

    function _assertTransferReverts(address caller, address recipient, uint256 value) internal {
        uint256 supplyBefore = alert.totalSupply();
        uint256 callerBalanceBefore = alert.balanceOf(caller);
        uint256 recipientBalanceBefore = alert.balanceOf(recipient);

        vm.recordLogs();
        vm.prank(caller);
        vm.expectRevert(RepMigrationAlert.TransferDisabled.selector);
        alert.transfer(recipient, value);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        assertEq(logs.length, 0);
        assertEq(alert.totalSupply(), supplyBefore);
        assertEq(alert.balanceOf(caller), callerBalanceBefore);
        assertEq(alert.balanceOf(recipient), recipientBalanceBefore);
    }

    function _assertTransferFromReverts(address caller, address owner, address recipient, uint256 value) internal {
        uint256 supplyBefore = alert.totalSupply();
        uint256 ownerBalanceBefore = alert.balanceOf(owner);
        uint256 recipientBalanceBefore = alert.balanceOf(recipient);

        vm.recordLogs();
        vm.prank(caller);
        vm.expectRevert(RepMigrationAlert.TransferDisabled.selector);
        alert.transferFrom(owner, recipient, value);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        assertEq(logs.length, 0);
        assertEq(alert.totalSupply(), supplyBefore);
        assertEq(alert.balanceOf(owner), ownerBalanceBefore);
        assertEq(alert.balanceOf(recipient), recipientBalanceBefore);
    }

    function _assertApproveReverts(address caller, address spender, uint256 value) internal {
        uint256 supplyBefore = alert.totalSupply();
        uint256 callerBalanceBefore = alert.balanceOf(caller);

        vm.recordLogs();
        vm.prank(caller);
        vm.expectRevert(RepMigrationAlert.ApprovalDisabled.selector);
        alert.approve(spender, value);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        assertEq(logs.length, 0);
        assertEq(alert.totalSupply(), supplyBefore);
        assertEq(alert.balanceOf(caller), callerBalanceBefore);
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
    uint160 internal constant GAS_ADDRESS_BASE = uint160(0x1111111111111111111111111111111111111111);
    uint256 internal constant BASE_TRANSACTION_GAS = 21_000;

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
            address(0xBAD),
            abi.encodeCall(target.distribute, (_gasRecipients(500))),
            false,
            RepMigrationAlert.UnauthorizedCaller.selector,
            "revert-unauthorized"
        );
    }

    function test_Gas_Finalization() public {
        RepMigrationAlert target = new RepMigrationAlert(AUTHORITY, 500);
        vm.prank(AUTHORITY);
        target.distribute(_gasRecipients(100));

        _measureCall(target, AUTHORITY, abi.encodeCall(target.finalize, ()), true, bytes4(0), "finalize-success");
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
        assertEq(target.totalSupply(), size);
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

    function _max(uint256 left, uint256 right) internal pure returns (uint256) {
        return left > right ? left : right;
    }
}
