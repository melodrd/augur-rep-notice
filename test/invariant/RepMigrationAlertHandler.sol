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
    mapping(address recipient => bool notified) public ghostNotified;

    uint256 public ghostSupply;
    bool public ghostFinalized;
    uint256 public supplyAtFinalization;
    uint256 public successfulFinalizations;

    uint256 public unexpectedValidDistributionReverts;
    uint256 public invalidDistributionSuccesses;
    uint256 public unauthorizedDistributionSuccesses;
    uint256 public unauthorizedFinalizationSuccesses;
    uint256 public unexpectedAuthorizedFinalizationReverts;
    uint256 public repeatedFinalizationSuccesses;
    uint256 public postFinalizationDistributionSuccesses;
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
            recipientPool.push(address(recipientValue));
            recipientValue++;
        }
    }

    function distributeValid(uint256 rawCount) external {
        if (ghostFinalized || ghostSupply == alert.distributionCap()) {
            return;
        }

        uint256 remaining = alert.distributionCap() - ghostSupply;
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
        if (ghostFinalized || ghostSupply == alert.distributionCap()) {
            return;
        }

        uint256 remaining = alert.distributionCap() - ghostSupply;
        uint256 count = bound(rawCount, 1, _min(MAX_SMALL_BATCH, remaining));
        address[] memory recipients = _newRecipients(count);
        recipients[bound(rawIndex, 0, count - 1)] = address(0);

        (bool success,) = _distributeAs(authority, recipients);
        if (success) {
            invalidDistributionSuccesses++;
        }
    }

    function distributeAdjacentDuplicate(uint256 rawCount, uint256 rawIndex) external {
        uint256 remaining = alert.distributionCap() - ghostSupply;
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
        uint256 remaining = alert.distributionCap() - ghostSupply;
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

    function distributePreviouslyNotified(uint256 rawExistingIndex, uint256 rawNewCount, uint256 rawPlacement)
        external
    {
        uint256 remaining = alert.distributionCap() - ghostSupply;
        if (ghostFinalized || ghostSupply == 0 || remaining == 0) {
            return;
        }

        uint256 count = bound(rawNewCount, 1, _min(MAX_SMALL_BATCH, remaining));
        address[] memory recipients = _newRecipients(count);
        address existingRecipient = recipientPool[bound(rawExistingIndex, 0, ghostSupply - 1)];
        recipients[bound(rawPlacement, 0, count - 1)] = existingRecipient;

        (bool success,) = _distributeAs(authority, recipients);
        if (success) {
            invalidDistributionSuccesses++;
        }
    }

    function distributeCapBoundary(uint256 rawGate) external {
        uint256 remaining = alert.distributionCap() - ghostSupply;
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

        uint256 remaining = alert.distributionCap() - ghostSupply;
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

    function finalizeAuthorized(uint256 rawGate) external {
        if (!ghostFinalized && rawGate % FINALIZATION_GATE != 0) {
            return;
        }

        vm.prank(authority);
        (bool success,) = address(alert).call(abi.encodeCall(alert.finalize, ()));
        if (!ghostFinalized) {
            if (success) {
                ghostFinalized = true;
                supplyAtFinalization = ghostSupply;
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

    function _recordSuccessfulDistribution(address[] memory recipients) internal {
        for (uint256 index = 0; index < recipients.length; index++) {
            ghostNotified[recipients[index]] = true;
        }
        ghostSupply += recipients.length;
    }

    function _newRecipients(uint256 count) internal view returns (address[] memory recipients) {
        recipients = new address[](count);
        for (uint256 index = 0; index < count; index++) {
            recipients[index] = recipientPool[ghostSupply + index];
        }
    }

    function _poolRecipients(uint256 count) internal view returns (address[] memory recipients) {
        recipients = new address[](count);
        for (uint256 index = 0; index < count; index++) {
            recipients[index] = recipientPool[index];
        }
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
