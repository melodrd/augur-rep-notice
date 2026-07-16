// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.36;

/// @title REP MIGRATION ALERT
/// @notice Records one non-economic migration alert unit for each notified address.
/// @dev Receiving an alert performs no migration, grants no right or value, and requires no interaction.
contract RepMigrationAlert {
    string private constant _NAME = "REP MIGRATION ALERT";
    string private constant _SYMBOL = "CHECKREP";
    uint8 private constant _DECIMALS = 0;
    uint256 private constant _UNIT = 1;

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

    /// @notice Reverts when a recipient is the zero address.
    /// @param index The zero-address recipient's calldata index.
    error ZeroRecipient(uint256 index);

    /// @notice Reverts when a recipient already has an alert unit.
    /// @param recipient The previously notified or duplicated recipient.
    error RecipientAlreadyNotified(address recipient);

    /// @notice Reverts when a distribution would exceed the immutable cap.
    /// @param attemptedSupply The supply that the distribution would create.
    /// @param cap The immutable distribution cap.
    error DistributionCapExceeded(uint256 attemptedSupply, uint256 cap);

    /// @notice Reverts for every attempted transfer or transfer-from.
    error TransferDisabled();

    /// @notice Reverts for every attempted approval.
    error ApprovalDisabled();

    /// @notice Reverts when finalization has already completed.
    error FinalizationAlreadyCompleted();

    /// @notice Emitted once for each successfully notified recipient.
    event Transfer(address indexed from, address indexed to, uint256 value);

    /// @notice Emitted when the authority permanently closes distribution.
    event DistributionFinalized(address indexed authority, uint256 finalSupply);

    /// @notice The only address permitted to distribute or finalize.
    address public immutable authority;

    /// @notice The maximum total number of alert units that may be issued.
    uint256 public immutable distributionCap;

    /// @notice The number of unique successfully notified recipients.
    uint256 public totalSupply;

    /// @notice Whether distribution has been permanently closed.
    bool public finalized;

    /// @notice Returns an address's alert balance, which is always zero or one.
    mapping(address account => uint256 balance) public balanceOf;

    /// @notice Creates an unfinalized alert contract with zero initial supply.
    /// @param authority_ The sole address permitted to distribute or finalize.
    /// @param distributionCap_ The immutable maximum total supply.
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

    /// @notice Returns zero because approvals are permanently disabled.
    function allowance(address, address) external pure returns (uint256) {
        return 0;
    }

    /// @notice Atomically issues one alert unit to each recipient.
    /// @param recipients The ordered recipient addresses to notify.
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

        uint256 attemptedSupply = totalSupply + recipientCount;
        if (attemptedSupply > distributionCap) {
            revert DistributionCapExceeded(attemptedSupply, distributionCap);
        }

        for (uint256 index = 0; index < recipientCount; index++) {
            address recipient = recipients[index];
            if (recipient == address(0)) {
                revert ZeroRecipient(index);
            }
            if (balanceOf[recipient] != 0) {
                revert RecipientAlreadyNotified(recipient);
            }

            // A later invalid entry reverts earlier writes and events, including in-call duplicates.
            balanceOf[recipient] = _UNIT;
            emit Transfer(address(0), recipient, _UNIT);
        }

        totalSupply = attemptedSupply;
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
        emit DistributionFinalized(authority, totalSupply);
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
