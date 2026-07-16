// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.36;

/// @title CHECK AUGUR REP MIGRATION
/// @notice Records one non-economic migration alert unit for each alerted address.
/// @dev Receiving an alert performs no migration, grants no right or value, and requires no action.
contract RepMigrationAlert {
    string private constant _NAME = "CHECK AUGUR REP MIGRATION";
    string private constant _SYMBOL = "MIGRATEREP";
    uint8 private constant _DECIMALS = 0;
    uint256 private constant _UNIT = 1;

    /// @notice The hard maximum number of recipients accepted by one distribution call.
    uint256 public constant MAX_BATCH_SIZE = 500;

    enum AlertStatus {
        NeverAlerted,
        Active,
        Burned
    }

    /// @notice Reverts when the constructor authority is the zero address.
    error ZeroAuthority();

    /// @notice Reverts when the constructor distribution cap is zero.
    error ZeroDistributionCap();

    /// @notice Reverts when a caller is not the immutable authority.
    /// @param caller The unauthorized caller.
    error UnauthorizedCaller(address caller);

    /// @notice Reverts when distribution has been permanently finalized.
    error DistributionAlreadyClosed();

    /// @notice Reverts when a distribution contains no recipients.
    error EmptyRecipientArray();

    /// @notice Reverts when a distribution exceeds the hard batch ceiling.
    /// @param provided The submitted recipient count.
    /// @param maximum The hard maximum recipient count.
    error BatchSizeExceeded(uint256 provided, uint256 maximum);

    /// @notice Reverts when a recipient is the zero address.
    /// @param index The zero-address recipient's calldata index.
    error ZeroRecipient(uint256 index);

    /// @notice Reverts when a recipient was previously alerted or duplicated in the current call.
    /// @param recipient The previously alerted or duplicated recipient.
    error RecipientAlreadyNotified(address recipient);

    /// @notice Reverts when a distribution would exceed the immutable cap.
    /// @param attemptedIssued The lifetime issued count that the distribution would create.
    /// @param cap The immutable distribution cap.
    error DistributionCapExceeded(uint256 attemptedIssued, uint256 cap);

    /// @notice Reverts when the caller has no active alert unit to burn.
    /// @param account The caller without an active alert balance.
    error NoAlertBalance(address account);

    /// @notice Reverts for every attempted transfer or transfer-from.
    error TransferDisabled();

    /// @notice Reverts for every attempted approval.
    error ApprovalDisabled();

    /// @notice Reverts when finalization has already completed.
    error FinalizationAlreadyCompleted();

    /// @notice Emitted once for each successful issuance or holder self-burn.
    event Transfer(address indexed from, address indexed to, uint256 value);

    /// @notice Emitted when the authority permanently closes distribution.
    event DistributionFinalized(address indexed authority, uint256 finalIssued);

    /// @notice The only address permitted to distribute or finalize.
    address public immutable authority;

    /// @notice The maximum number of unique addresses that may ever be alerted.
    uint256 public immutable distributionCap;

    /// @notice The number of unique addresses ever successfully alerted.
    uint256 public totalIssued;

    /// @notice The number of active, unburned alert units.
    uint256 public totalSupply;

    /// @notice Whether distribution has been permanently closed.
    bool public finalized;

    mapping(address account => AlertStatus status) private _status;

    /// @notice Creates an unfinalized alert contract with zero initial supply.
    /// @param authority_ The sole address permitted to distribute or finalize.
    /// @param distributionCap_ The immutable maximum lifetime issued count.
    constructor(address authority_, uint256 distributionCap_) {
        if (authority_ == address(0)) {
            revert ZeroAuthority();
        }
        if (distributionCap_ == 0) {
            revert ZeroDistributionCap();
        }

        authority = authority_;
        distributionCap = distributionCap_;
    }

    /// @notice Returns the fixed alert name.
    function name() external pure returns (string memory) {
        return _NAME;
    }

    /// @notice Returns the fixed alert symbol.
    function symbol() external pure returns (string memory) {
        return _SYMBOL;
    }

    /// @notice Returns the fixed zero-decimal precision.
    function decimals() external pure returns (uint8) {
        return _DECIMALS;
    }

    /// @notice Returns an address's active alert balance, which is always zero or one.
    function balanceOf(address account) public view returns (uint256) {
        return _status[account] == AlertStatus.Active ? _UNIT : 0;
    }

    /// @notice Returns whether an address was ever successfully alerted.
    function wasAlerted(address account) external view returns (bool) {
        return _status[account] != AlertStatus.NeverAlerted;
    }

    /// @notice Returns zero because approvals are permanently disabled.
    function allowance(address, address) external pure returns (uint256) {
        return 0;
    }

    /// @notice Atomically issues one alert unit to each recipient.
    /// @param recipients The ordered recipient addresses to alert.
    function distribute(address[] calldata recipients) external {
        if (msg.sender != authority) {
            revert UnauthorizedCaller(msg.sender);
        }
        if (finalized) {
            revert DistributionAlreadyClosed();
        }

        uint256 recipientCount = recipients.length;
        if (recipientCount == 0) {
            revert EmptyRecipientArray();
        }
        if (recipientCount > MAX_BATCH_SIZE) {
            revert BatchSizeExceeded(recipientCount, MAX_BATCH_SIZE);
        }

        uint256 attemptedIssued = totalIssued + recipientCount;
        if (attemptedIssued > distributionCap) {
            revert DistributionCapExceeded(attemptedIssued, distributionCap);
        }

        for (uint256 index = 0; index < recipientCount; index++) {
            address recipient = recipients[index];
            if (recipient == address(0)) {
                revert ZeroRecipient(index);
            }
            if (_status[recipient] != AlertStatus.NeverAlerted) {
                revert RecipientAlreadyNotified(recipient);
            }

            // A later invalid entry reverts earlier writes and events, including in-call duplicates.
            _status[recipient] = AlertStatus.Active;
            emit Transfer(address(0), recipient, _UNIT);
        }

        totalIssued = attemptedIssued;
        totalSupply += recipientCount;
    }

    /// @notice Permanently removes the caller's active alert unit.
    /// @dev Holder self-burn intentionally remains available after issuance finalization.
    function burn() external {
        if (_status[msg.sender] != AlertStatus.Active) {
            revert NoAlertBalance(msg.sender);
        }

        _status[msg.sender] = AlertStatus.Burned;
        totalSupply -= _UNIT;
        emit Transfer(msg.sender, address(0), _UNIT);
    }

    /// @notice Permanently closes distribution.
    function finalize() external {
        if (msg.sender != authority) {
            revert UnauthorizedCaller(msg.sender);
        }
        if (finalized) {
            revert FinalizationAlreadyCompleted();
        }

        finalized = true;
        emit DistributionFinalized(authority, totalIssued);
    }

    /// @notice Disabled; always reverts.
    function transfer(address, uint256) external pure returns (bool) {
        revert TransferDisabled();
    }

    /// @notice Disabled; always reverts.
    function transferFrom(address, address, uint256) external pure returns (bool) {
        revert TransferDisabled();
    }

    /// @notice Disabled; always reverts.
    function approve(address, uint256) external pure returns (bool) {
        revert ApprovalDisabled();
    }
}
