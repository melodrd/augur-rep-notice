// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.36;

import {Test} from "forge-std/Test.sol";

import {RepMigrationAlert} from "../../src/RepMigrationAlert.sol";

contract RepMigrationAlertGasTest is Test {
    address internal constant AUTHORITY = address(0xA11CE);
    address internal constant NEVER_ALERTED = address(0xBAD);
    uint160 internal constant GAS_ADDRESS_BASE = uint160(0x1111111111111111111111111111111111111111);
    uint256 internal constant BASE_TRANSACTION_GAS = 21_000;

    // Conservative local transaction bound for regression detection, not a live-chain observation.
    uint256 internal constant DISTRIBUTE_500_LOCAL_TRANSACTION_GAS_CEILING = 15_000_000;

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
        uint256 osakaTransactionGas = _measureSuccessfulDistribution(500, "distribute-500");

        assertLe(osakaTransactionGas, DISTRIBUTE_500_LOCAL_TRANSACTION_GAS_CEILING);
    }

    function test_Gas_BatchSizeExceededRevert() public {
        RepMigrationAlert target = new RepMigrationAlert(AUTHORITY, 501);

        _measureCall(
            target,
            AUTHORITY,
            abi.encodeCall(target.distribute, (_gasRecipients(501))),
            false,
            RepMigrationAlert.BatchSizeExceeded.selector,
            "revert-batch-size-exceeded"
        );
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

    function _measureSuccessfulDistribution(uint256 size, string memory label)
        internal
        returns (uint256 osakaTransactionGas)
    {
        RepMigrationAlert target = new RepMigrationAlert(AUTHORITY, size);
        bytes memory callData = abi.encodeCall(target.distribute, (_gasRecipients(size)));

        osakaTransactionGas = _measureCall(target, AUTHORITY, callData, true, bytes4(0), label);
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
    ) internal returns (uint256 osakaTransactionGas) {
        vm.cool(address(target));
        vm.prank(caller);
        (bool success, bytes memory returnData) = address(target).call(callData);
        uint256 executionGas = vm.snapshotGasLastCall("RepMigrationAlert", label);
        uint256 calldataGas = _calldataGas(callData);
        uint256 calldataTokens = calldataGas / 4;
        uint256 osakaFloorDataGas = calldataTokens * 10;
        uint256 standardTransactionGas = BASE_TRANSACTION_GAS + calldataGas + executionGas;
        osakaTransactionGas = BASE_TRANSACTION_GAS + _max(calldataGas + executionGas, osakaFloorDataGas);

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
