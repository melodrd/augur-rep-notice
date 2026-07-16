// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.36;

import {Test} from "forge-std/Test.sol";

import {RepMigrationAlert} from "../../src/RepMigrationAlert.sol";

contract RepMigrationAlertHandler is Test {
    uint256 internal constant MAX_SMALL_BATCH = 4;
    uint256 internal constant FINALIZATION_GATE = 16;

    RepMigrationAlert public immutable alert;
    address public immutable authority;
    address public immutable deployer;

    address[] internal recipientPool;
    mapping(address recipient => bool alerted) public ghostEverAlerted;
    mapping(address recipient => bool active) public ghostActive;
    mapping(address recipient => bool burned) public ghostBurned;

    uint256 public ghostTotalIssued;
    uint256 public ghostActiveSupply;
    uint256 public ghostBurnedCount;
    bool public ghostFinalized;
    uint256 public issuedAtFinalization;
    uint256 public activeSupplyAtFinalization;
    uint256 public successfulFinalizations;
    uint256 public successfulBurns;
    uint256 public successfulBurnsBeforeFinalization;
    uint256 public successfulBurnsAfterFinalization;

    uint256 public unexpectedValidDistributionReverts;
    uint256 public invalidDistributionSuccesses;
    uint256 public unauthorizedDistributionSuccesses;
    uint256 public postFinalizationDistributionSuccesses;
    uint256 public unexpectedValidBurnReverts;
    uint256 public invalidBurnSuccesses;
    uint256 public unauthorizedFinalizationSuccesses;
    uint256 public unexpectedAuthorizedFinalizationReverts;
    uint256 public repeatedFinalizationSuccesses;
    uint256 public transferSuccesses;
    uint256 public transferFromSuccesses;
    uint256 public approveSuccesses;

    constructor(RepMigrationAlert alert_, address authority_, address deployer_) {
        alert = alert_;
        authority = authority_;
        deployer = deployer_;

        uint256 poolSize = alert_.distributionCap() + 1;
        uint160 recipientValue = 0x10_000;
        while (recipientPool.length < poolSize) {
            address recipient = address(recipientValue);
            recipientValue++;
            if (recipient == authority_ || recipient == deployer_) {
                continue;
            }
            recipientPool.push(recipient);
        }
    }

    function distributeValid(uint256 rawCount) external {
        if (ghostFinalized || ghostTotalIssued == alert.distributionCap()) {
            return;
        }

        uint256 remaining = alert.distributionCap() - ghostTotalIssued;
        uint256 count = bound(rawCount, 1, _min(MAX_SMALL_BATCH, remaining));
        address[] memory recipients = _newRecipients(count);

        (bool success,) = _distributeAs(authority, recipients);
        if (!success) {
            unexpectedValidDistributionReverts++;
            return;
        }

        _recordSuccessfulDistribution(recipients);
    }

    function distributeEmpty() external {
        (bool success,) = _distributeAs(authority, new address[](0));
        if (success) {
            invalidDistributionSuccesses++;
        }
    }

    function distributeZero(uint256 rawCount, uint256 rawIndex) external {
        if (ghostFinalized || ghostTotalIssued == alert.distributionCap()) {
            return;
        }

        uint256 remaining = alert.distributionCap() - ghostTotalIssued;
        uint256 count = bound(rawCount, 1, _min(MAX_SMALL_BATCH, remaining));
        address[] memory recipients = _newRecipients(count);
        recipients[bound(rawIndex, 0, count - 1)] = address(0);

        (bool success,) = _distributeAs(authority, recipients);
        if (success) {
            invalidDistributionSuccesses++;
        }
    }

    function distributeAdjacentDuplicate(uint256 rawCount, uint256 rawIndex) external {
        uint256 remaining = alert.distributionCap() - ghostTotalIssued;
        if (ghostFinalized || remaining < 2) {
            return;
        }

        uint256 count = bound(rawCount, 2, _min(MAX_SMALL_BATCH, remaining));
        address[] memory recipients = _newRecipients(count);
        uint256 duplicateIndex = bound(rawIndex, 1, count - 1);
        recipients[duplicateIndex] = recipients[duplicateIndex - 1];

        (bool success,) = _distributeAs(authority, recipients);
        if (success) {
            invalidDistributionSuccesses++;
        }
    }

    function distributeNonAdjacentDuplicate(uint256 rawCount, uint256 rawIndex) external {
        uint256 remaining = alert.distributionCap() - ghostTotalIssued;
        if (ghostFinalized || remaining < 3) {
            return;
        }

        uint256 count = bound(rawCount, 3, _min(MAX_SMALL_BATCH, remaining));
        address[] memory recipients = _newRecipients(count);
        uint256 duplicateIndex = bound(rawIndex, 2, count - 1);
        recipients[duplicateIndex] = recipients[0];

        (bool success,) = _distributeAs(authority, recipients);
        if (success) {
            invalidDistributionSuccesses++;
        }
    }

    function distributePreviouslyActive(uint256 rawExistingIndex, uint256 rawNewCount, uint256 rawPlacement) external {
        uint256 remaining = alert.distributionCap() - ghostTotalIssued;
        if (ghostFinalized || ghostActiveSupply == 0 || remaining == 0) {
            return;
        }

        uint256 count = bound(rawNewCount, 1, _min(MAX_SMALL_BATCH, remaining));
        address[] memory recipients = _newRecipients(count);
        recipients[bound(rawPlacement, 0, count - 1)] = _activeRecipient(rawExistingIndex);

        (bool success,) = _distributeAs(authority, recipients);
        if (success) {
            invalidDistributionSuccesses++;
        }
    }

    function distributePreviouslyBurned(uint256 rawExistingIndex, uint256 rawNewCount, uint256 rawPlacement) external {
        uint256 remaining = alert.distributionCap() - ghostTotalIssued;
        if (ghostFinalized || ghostBurnedCount == 0 || remaining == 0) {
            return;
        }

        uint256 count = bound(rawNewCount, 1, _min(MAX_SMALL_BATCH, remaining));
        address[] memory recipients = _newRecipients(count);
        recipients[bound(rawPlacement, 0, count - 1)] = _burnedRecipient(rawExistingIndex);

        (bool success,) = _distributeAs(authority, recipients);
        if (success) {
            invalidDistributionSuccesses++;
        }
    }

    function distributeBurnedRecipient(uint256 rawBurnedIndex) external {
        if (ghostFinalized || ghostBurnedCount == 0 || ghostTotalIssued == alert.distributionCap()) {
            return;
        }

        address[] memory recipients = new address[](1);
        recipients[0] = _burnedRecipient(rawBurnedIndex);
        (bool success,) = _distributeAs(authority, recipients);
        if (success) {
            invalidDistributionSuccesses++;
        }
    }

    function distributeCapBoundary(uint256 rawGate) external {
        uint256 remaining = alert.distributionCap() - ghostTotalIssued;
        if (rawGate % FINALIZATION_GATE != 0 || ghostFinalized || remaining == 0) {
            return;
        }

        address[] memory recipients = _newRecipients(remaining);
        (bool success,) = _distributeAs(authority, recipients);
        if (!success) {
            unexpectedValidDistributionReverts++;
            return;
        }

        _recordSuccessfulDistribution(recipients);
    }

    function distributeCapOverflow(uint256 rawExcess) external {
        if (ghostFinalized) {
            return;
        }

        uint256 remaining = alert.distributionCap() - ghostTotalIssued;
        uint256 excess = bound(rawExcess, 1, 1);
        address[] memory recipients = _newRecipients(remaining + excess);

        (bool success,) = _distributeAs(authority, recipients);
        if (success) {
            invalidDistributionSuccesses++;
        }
    }

    function distributeUnauthorized(uint256 rawCaller, uint256 rawCount) external {
        address caller = _unauthorizedPoolAddress(rawCaller);
        uint256 count = bound(rawCount, 1, MAX_SMALL_BATCH);
        address[] memory recipients = _poolRecipients(count);

        (bool success,) = _distributeAs(caller, recipients);
        if (success) {
            unauthorizedDistributionSuccesses++;
        }
    }

    function distributeAsDeployer() external {
        (bool success,) = _distributeAs(deployer, _poolRecipients(1));
        if (success) {
            unauthorizedDistributionSuccesses++;
        }
    }

    function distributeAfterFinalization() external {
        if (!ghostFinalized) {
            return;
        }

        address[] memory recipients = new address[](1);
        recipients[0] = recipientPool[alert.distributionCap()];
        (bool success,) = _distributeAs(authority, recipients);
        if (success) {
            postFinalizationDistributionSuccesses++;
        }
    }

    function burnValid(uint256 rawHolderIndex) external {
        if (ghostActiveSupply == 0) {
            return;
        }
        _attemptValidBurn(_activeRecipient(rawHolderIndex));
    }

    function burnBeforeFinalization(uint256 rawHolderIndex) external {
        if (ghostFinalized || ghostActiveSupply == 0) {
            return;
        }
        _attemptValidBurn(_activeRecipient(rawHolderIndex));
    }

    function burnAfterFinalization(uint256 rawHolderIndex) external {
        if (!ghostFinalized || ghostActiveSupply == 0) {
            return;
        }
        _attemptValidBurn(_activeRecipient(rawHolderIndex));
    }

    function burnNeverAlerted(uint256 rawRecipientIndex) external {
        uint256 neverAlertedCount = recipientPool.length - ghostTotalIssued;
        address caller = recipientPool[ghostTotalIssued + (rawRecipientIndex % neverAlertedCount)];
        _attemptInvalidBurn(caller);
    }

    function burnRepeated(uint256 rawBurnedIndex) external {
        if (ghostBurnedCount == 0) {
            return;
        }
        _attemptInvalidBurn(_burnedRecipient(rawBurnedIndex));
    }

    function burnAsAuthority() external {
        _attemptInvalidBurn(authority);
    }

    function burnAsDeployer() external {
        _attemptInvalidBurn(deployer);
    }

    function finalizeAuthorized(uint256 rawGate) external {
        if (!ghostFinalized && rawGate % FINALIZATION_GATE != 0) {
            return;
        }

        vm.prank(authority);
        (bool success,) = address(alert).call(abi.encodeCall(alert.finalize, ()));
        if (!ghostFinalized) {
            if (success) {
                ghostFinalized = true;
                issuedAtFinalization = ghostTotalIssued;
                activeSupplyAtFinalization = ghostActiveSupply;
                successfulFinalizations++;
            } else {
                unexpectedAuthorizedFinalizationReverts++;
            }
            return;
        }

        if (success) {
            repeatedFinalizationSuccesses++;
        }
    }

    function finalizeUnauthorized(uint256 rawCaller) external {
        address caller = _unauthorizedPoolAddress(rawCaller);
        vm.prank(caller);
        (bool success,) = address(alert).call(abi.encodeCall(alert.finalize, ()));
        if (success) {
            unauthorizedFinalizationSuccesses++;
        }
    }

    function finalizeAsDeployer() external {
        vm.prank(deployer);
        (bool success,) = address(alert).call(abi.encodeCall(alert.finalize, ()));
        if (success) {
            unauthorizedFinalizationSuccesses++;
        }
    }

    function transferAttempt(uint256 rawCaller, uint256 rawRecipient, uint256 value) external {
        address caller = recipientPool[rawCaller % recipientPool.length];
        address recipient = recipientPool[rawRecipient % recipientPool.length];
        vm.prank(caller);
        (bool success,) = address(alert).call(abi.encodeCall(alert.transfer, (recipient, value)));
        if (success) {
            transferSuccesses++;
        }
    }

    function transferFromAttempt(uint256 rawCaller, uint256 rawOwner, uint256 rawRecipient, uint256 value) external {
        address caller = recipientPool[rawCaller % recipientPool.length];
        address owner = recipientPool[rawOwner % recipientPool.length];
        address recipient = recipientPool[rawRecipient % recipientPool.length];
        vm.prank(caller);
        (bool success,) = address(alert).call(abi.encodeCall(alert.transferFrom, (owner, recipient, value)));
        if (success) {
            transferFromSuccesses++;
        }
    }

    function approveAttempt(uint256 rawCaller, uint256 rawSpender, uint256 value) external {
        address caller = recipientPool[rawCaller % recipientPool.length];
        address spender = recipientPool[rawSpender % recipientPool.length];
        vm.prank(caller);
        (bool success,) = address(alert).call(abi.encodeCall(alert.approve, (spender, value)));
        if (success) {
            approveSuccesses++;
        }
    }

    function forceEthBalance(uint96 rawBalance) external {
        vm.deal(address(alert), uint256(rawBalance));
    }

    function recipientPoolLength() external view returns (uint256) {
        return recipientPool.length;
    }

    function recipientAt(uint256 index) external view returns (address) {
        return recipientPool[index];
    }

    function _distributeAs(address caller, address[] memory recipients)
        internal
        returns (bool success, bytes memory returnData)
    {
        vm.prank(caller);
        return address(alert).call(abi.encodeCall(alert.distribute, (recipients)));
    }

    function _burnAs(address caller) internal returns (bool success, bytes memory returnData) {
        vm.prank(caller);
        return address(alert).call(abi.encodeCall(alert.burn, ()));
    }

    function _attemptValidBurn(address holder) internal {
        (bool success,) = _burnAs(holder);
        if (!success) {
            unexpectedValidBurnReverts++;
            return;
        }

        ghostActive[holder] = false;
        ghostBurned[holder] = true;
        ghostActiveSupply--;
        ghostBurnedCount++;
        successfulBurns++;
        if (ghostFinalized) {
            successfulBurnsAfterFinalization++;
        } else {
            successfulBurnsBeforeFinalization++;
        }
    }

    function _attemptInvalidBurn(address caller) internal {
        (bool success,) = _burnAs(caller);
        if (success) {
            invalidBurnSuccesses++;
        }
    }

    function _recordSuccessfulDistribution(address[] memory recipients) internal {
        for (uint256 index = 0; index < recipients.length; index++) {
            address recipient = recipients[index];
            ghostEverAlerted[recipient] = true;
            ghostActive[recipient] = true;
        }
        ghostTotalIssued += recipients.length;
        ghostActiveSupply += recipients.length;
    }

    function _newRecipients(uint256 count) internal view returns (address[] memory recipients) {
        recipients = new address[](count);
        for (uint256 index = 0; index < count; index++) {
            recipients[index] = recipientPool[ghostTotalIssued + index];
        }
    }

    function _poolRecipients(uint256 count) internal view returns (address[] memory recipients) {
        recipients = new address[](count);
        for (uint256 index = 0; index < count; index++) {
            recipients[index] = recipientPool[index];
        }
    }

    function _activeRecipient(uint256 rawIndex) internal view returns (address) {
        uint256 remainingIndex = rawIndex % ghostActiveSupply;
        for (uint256 index = 0; index < ghostTotalIssued; index++) {
            address recipient = recipientPool[index];
            if (!ghostActive[recipient]) {
                continue;
            }
            if (remainingIndex == 0) {
                return recipient;
            }
            remainingIndex--;
        }
        return address(0);
    }

    function _burnedRecipient(uint256 rawIndex) internal view returns (address) {
        uint256 remainingIndex = rawIndex % ghostBurnedCount;
        for (uint256 index = 0; index < ghostTotalIssued; index++) {
            address recipient = recipientPool[index];
            if (!ghostBurned[recipient]) {
                continue;
            }
            if (remainingIndex == 0) {
                return recipient;
            }
            remainingIndex--;
        }
        return address(0);
    }

    function _unauthorizedPoolAddress(uint256 rawIndex) internal view returns (address caller) {
        caller = recipientPool[rawIndex % recipientPool.length];
        if (caller == authority) {
            caller = deployer;
        }
    }

    function _min(uint256 left, uint256 right) internal pure returns (uint256) {
        return left < right ? left : right;
    }
}
