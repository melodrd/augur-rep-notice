// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.36;

import {Test} from "forge-std/Test.sol";

import {RepMigrationAlert} from "../../src/RepMigrationAlert.sol";

contract RepMigrationAlertFuzzTest is Test {
    address internal constant AUTHORITY = address(0xA11CE);
    address internal constant FALLBACK_OUTSIDER = address(0xBAD);
    uint256 internal constant DISTRIBUTION_CAP = 128;
    uint256 internal constant MAX_FUZZ_BATCH = 64;

    RepMigrationAlert internal alert;

    function setUp() public {
        alert = new RepMigrationAlert(AUTHORITY, DISTRIBUTION_CAP);
    }

    function testFuzz_DistributeUniqueRecipientsSetsBinaryBalances(uint256 rawBase, uint8 rawLength) public {
        uint256 length = bound(rawLength, 1, MAX_FUZZ_BATCH);
        address[] memory recipients = _uniqueRecipients(rawBase, length);
        address unrelated = _unrelatedAddress(recipients);

        vm.prank(AUTHORITY);
        alert.distribute(recipients);

        for (uint256 index = 0; index < recipients.length; index++) {
            assertEq(alert.balanceOf(recipients[index]), 1);
            assertLe(alert.balanceOf(recipients[index]), 1);
        }
        assertEq(alert.balanceOf(unrelated), 0);
        assertEq(alert.balanceOf(address(0)), 0);
        assertEq(alert.totalSupply(), recipients.length);
        assertLe(alert.totalSupply(), alert.distributionCap());
        assertFalse(alert.finalized());
    }

    function testFuzz_MultipleSuccessfulBatchesIncreaseSupplyExactly(
        uint256 rawBase,
        uint8 rawFirstLength,
        uint8 rawSecondLength
    ) public {
        uint256 firstLength = bound(rawFirstLength, 1, MAX_FUZZ_BATCH);
        uint256 secondLength = bound(rawSecondLength, 1, DISTRIBUTION_CAP - firstLength);
        address[] memory allRecipients = _uniqueRecipients(rawBase, firstLength + secondLength);
        address[] memory firstBatch = _slice(allRecipients, 0, firstLength);
        address[] memory secondBatch = _slice(allRecipients, firstLength, secondLength);

        vm.startPrank(AUTHORITY);
        alert.distribute(firstBatch);
        uint256 supplyAfterFirstBatch = alert.totalSupply();
        alert.distribute(secondBatch);
        vm.stopPrank();

        assertEq(supplyAfterFirstBatch, firstLength);
        assertEq(alert.totalSupply(), firstLength + secondLength);
        assertLe(alert.totalSupply(), alert.distributionCap());
        for (uint256 index = 0; index < allRecipients.length; index++) {
            assertEq(alert.balanceOf(allRecipients[index]), 1);
        }
    }

    function testFuzz_DuplicateIndexPairRevertsAtomically(
        uint256 rawBase,
        uint8 rawLength,
        uint8 rawFirstIndex,
        uint8 rawOffset
    ) public {
        uint256 length = bound(rawLength, 2, 32);
        address[] memory recipients = _uniqueRecipients(rawBase, length);
        uint256 firstIndex = bound(rawFirstIndex, 0, length - 1);
        uint256 secondIndex = (firstIndex + 1 + bound(rawOffset, 0, length - 2)) % length;
        address duplicatedRecipient = recipients[firstIndex];
        recipients[secondIndex] = duplicatedRecipient;

        _assertDistributionRevertsAtomically(
            alert,
            AUTHORITY,
            recipients,
            abi.encodeWithSelector(RepMigrationAlert.RecipientAlreadyNotified.selector, duplicatedRecipient)
        );
    }

    function testFuzz_AdjacentDuplicateRevertsAtomically(uint256 rawBase, uint8 rawLength, uint8 rawIndex) public {
        uint256 length = bound(rawLength, 2, 32);
        address[] memory recipients = _uniqueRecipients(rawBase, length);
        uint256 duplicateIndex = bound(rawIndex, 1, length - 1);
        address duplicatedRecipient = recipients[duplicateIndex - 1];
        recipients[duplicateIndex] = duplicatedRecipient;

        _assertDistributionRevertsAtomically(
            alert,
            AUTHORITY,
            recipients,
            abi.encodeWithSelector(RepMigrationAlert.RecipientAlreadyNotified.selector, duplicatedRecipient)
        );
    }

    function testFuzz_NonAdjacentDuplicateRevertsAtomically(
        uint256 rawBase,
        uint8 rawLength,
        uint8 rawFirstIndex,
        uint8 rawGap
    ) public {
        uint256 length = bound(rawLength, 3, 32);
        address[] memory recipients = _uniqueRecipients(rawBase, length);
        uint256 firstIndex = bound(rawFirstIndex, 0, length - 3);
        uint256 secondIndex = bound(firstIndex + 2 + rawGap, firstIndex + 2, length - 1);
        address duplicatedRecipient = recipients[firstIndex];
        recipients[secondIndex] = duplicatedRecipient;

        _assertDistributionRevertsAtomically(
            alert,
            AUTHORITY,
            recipients,
            abi.encodeWithSelector(RepMigrationAlert.RecipientAlreadyNotified.selector, duplicatedRecipient)
        );
    }

    function testFuzz_ZeroRecipientAtArbitraryIndexRevertsAtomically(uint256 rawBase, uint8 rawLength, uint8 rawIndex)
        public
    {
        uint256 length = bound(rawLength, 1, 32);
        address[] memory recipients = _uniqueRecipients(rawBase, length);
        uint256 zeroIndex = bound(rawIndex, 0, length - 1);
        recipients[zeroIndex] = address(0);

        _assertDistributionRevertsAtomically(
            alert, AUTHORITY, recipients, abi.encodeWithSelector(RepMigrationAlert.ZeroRecipient.selector, zeroIndex)
        );
    }

    function testFuzz_PreviouslyNotifiedRecipientRevertsAtomically(uint256 rawBase, uint8 rawLength, uint8 rawIndex)
        public
    {
        uint256 length = bound(rawLength, 1, 32);
        address[] memory allRecipients = _uniqueRecipients(rawBase, length + 1);
        address priorRecipient = allRecipients[0];
        vm.prank(AUTHORITY);
        alert.distribute(_slice(allRecipients, 0, 1));

        address[] memory attemptedBatch = _slice(allRecipients, 1, length);
        uint256 priorIndex = bound(rawIndex, 0, length - 1);
        attemptedBatch[priorIndex] = priorRecipient;

        _assertDistributionRevertsAtomically(
            alert,
            AUTHORITY,
            attemptedBatch,
            abi.encodeWithSelector(RepMigrationAlert.RecipientAlreadyNotified.selector, priorRecipient)
        );
    }

    function testFuzz_ArbitraryUnauthorizedCallerCannotDistributeOrFinalize(
        uint160 rawCaller,
        uint256 rawBase,
        uint8 rawLength
    ) public {
        address caller = _unauthorizedCaller(rawCaller);
        address[] memory recipients = _uniqueRecipients(rawBase, bound(rawLength, 1, 32));

        _assertDistributionRevertsAtomically(
            alert, caller, recipients, abi.encodeWithSelector(RepMigrationAlert.UnauthorizedCaller.selector, caller)
        );

        vm.prank(caller);
        vm.expectRevert(abi.encodeWithSelector(RepMigrationAlert.UnauthorizedCaller.selector, caller));
        alert.finalize();

        assertEq(alert.totalSupply(), 0);
        assertFalse(alert.finalized());
    }

    function testFuzz_ValidSequenceNeverExceedsCap(uint256 rawBase, uint8 rawCurrentSupply, uint8 rawBatchLength)
        public
    {
        uint256 cap = 64;
        RepMigrationAlert target = new RepMigrationAlert(AUTHORITY, cap);
        uint256 currentSupply = bound(rawCurrentSupply, 0, cap - 1);
        uint256 batchLength = bound(rawBatchLength, 1, cap - currentSupply);
        address[] memory allRecipients = _uniqueRecipients(rawBase, currentSupply + batchLength);

        vm.startPrank(AUTHORITY);
        if (currentSupply != 0) {
            target.distribute(_slice(allRecipients, 0, currentSupply));
        }
        uint256 supplyBefore = target.totalSupply();
        target.distribute(_slice(allRecipients, currentSupply, batchLength));
        vm.stopPrank();

        assertEq(supplyBefore, currentSupply);
        assertEq(target.totalSupply(), currentSupply + batchLength);
        assertLe(target.totalSupply(), target.distributionCap());
    }

    function testFuzz_DistributionAboveRemainingCapRevertsAtomically(
        uint256 rawBase,
        uint8 rawCurrentSupply,
        uint8 rawExcess
    ) public {
        uint256 cap = 64;
        RepMigrationAlert target = new RepMigrationAlert(AUTHORITY, cap);
        uint256 currentSupply = bound(rawCurrentSupply, 0, 32);
        uint256 attemptedLength = cap - currentSupply + bound(rawExcess, 1, 32);
        address[] memory allRecipients = _uniqueRecipients(rawBase, currentSupply + attemptedLength);

        if (currentSupply != 0) {
            vm.prank(AUTHORITY);
            target.distribute(_slice(allRecipients, 0, currentSupply));
        }

        address[] memory attemptedBatch = _slice(allRecipients, currentSupply, attemptedLength);
        _assertDistributionRevertsAtomically(
            target,
            AUTHORITY,
            attemptedBatch,
            abi.encodeWithSelector(
                RepMigrationAlert.DistributionCapExceeded.selector, currentSupply + attemptedLength, cap
            )
        );
    }

    function testFuzz_MovementAndApprovalAlwaysRevert(
        uint160 rawCaller,
        uint160 rawOwner,
        uint160 rawRecipient,
        uint160 rawSpender,
        uint256 value
    ) public {
        address caller = address(rawCaller);
        address owner = address(rawOwner);
        address recipient = address(rawRecipient);
        address spender = address(rawSpender);

        vm.prank(caller);
        vm.expectRevert(RepMigrationAlert.TransferDisabled.selector);
        alert.transfer(recipient, value);

        vm.prank(caller);
        vm.expectRevert(RepMigrationAlert.TransferDisabled.selector);
        alert.transferFrom(owner, recipient, value);

        vm.prank(caller);
        vm.expectRevert(RepMigrationAlert.ApprovalDisabled.selector);
        alert.approve(spender, value);

        assertEq(alert.allowance(owner, spender), 0);
        assertEq(alert.totalSupply(), 0);
        assertEq(alert.balanceOf(owner), 0);
        assertEq(alert.balanceOf(recipient), 0);
    }

    function testFuzz_FinalizationPermanentlyFreezesArbitraryValidState(uint256 rawBase, uint8 rawLength) public {
        uint256 length = bound(rawLength, 0, 32);
        address[] memory recipients = _uniqueRecipients(rawBase, length + 1);

        vm.startPrank(AUTHORITY);
        if (length != 0) {
            alert.distribute(_slice(recipients, 0, length));
        }
        alert.finalize();
        vm.stopPrank();

        uint256 finalSupply = alert.totalSupply();
        _assertDistributionRevertsAtomically(
            alert,
            AUTHORITY,
            _slice(recipients, length, 1),
            abi.encodeWithSelector(RepMigrationAlert.DistributionAlreadyClosed.selector)
        );

        assertTrue(alert.finalized());
        assertEq(alert.totalSupply(), finalSupply);
        for (uint256 index = 0; index < length; index++) {
            assertEq(alert.balanceOf(recipients[index]), 1);
        }
        assertEq(alert.balanceOf(recipients[length]), 0);
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
        assertEq(target.balanceOf(address(0)), 0);
        for (uint256 index = 0; index < recipients.length; index++) {
            assertEq(target.balanceOf(recipients[index]), balancesBefore[index]);
        }
    }

    function _uniqueRecipients(uint256 rawBase, uint256 count) internal pure returns (address[] memory recipients) {
        uint256 maximumBase = type(uint160).max - count;
        uint160 base = uint160(bound(rawBase, 1, maximumBase));
        recipients = new address[](count);
        uint160 recipientValue = base;
        for (uint256 index = 0; index < count; index++) {
            recipients[index] = address(recipientValue);
            recipientValue++;
        }
    }

    function _slice(address[] memory source, uint256 start, uint256 length)
        internal
        pure
        returns (address[] memory result)
    {
        result = new address[](length);
        for (uint256 index = 0; index < length; index++) {
            result[index] = source[start + index];
        }
    }

    function _unrelatedAddress(address[] memory recipients) internal pure returns (address) {
        uint160 firstRecipient = uint160(recipients[0]);
        if (firstRecipient > 1) {
            return address(firstRecipient - 1);
        }
        return address(uint160(recipients[recipients.length - 1]) + 1);
    }

    function _unauthorizedCaller(uint160 rawCaller) internal pure returns (address caller) {
        caller = address(rawCaller);
        if (caller == AUTHORITY) {
            caller = FALLBACK_OUTSIDER;
        }
    }
}
