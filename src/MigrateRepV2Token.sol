// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title MIGRATE REPV2 (MREP2) notice token
/// @notice A conventional, transferable, fixed-supply ERC-20 notice token. The entire
///         maximum supply is created once at construction and held by the token contract
///         itself. The immutable distributor sends exactly one whole MREP2 token to each
///         selected address through {distribute}, then permanently closes distribution
///         with {finalizeDistribution}. Every other behavior is standard OpenZeppelin
///         ERC-20: unrestricted transfer, approve, allowance, and transferFrom.
/// @dev MREP2 is a notice token. It is not REP, REPv2, a migration claim, migration
///      eligibility proof, redemption right, governance right, reward, or a project-supported
///      investment asset. Holding, transferring, or approving MREP2 performs no REP migration.
///      There is no owner, role, pause, mint, holder burn, tax, blacklist, or upgrade surface.
contract MigrateRepV2Token is ERC20 {
    /// @notice The amount delivered to each initial recipient: one whole token (1e18 base units).
    uint256 public constant TOKEN_PER_RECIPIENT = 1 ether;

    /// @notice The hard maximum number of recipients accepted by one {distribute} call.
    /// @dev Chosen by measurement so the worst-case successful call stays well under the
    ///      Osaka transaction gas cap. Operations normally use smaller batches; see docs.
    uint256 public constant MAX_BATCH_SIZE = 200;

    /// @notice The only address permitted to distribute the reserve or finalize distribution.
    address public immutable distributor;

    /// @notice The maximum number of unique addresses that may ever receive an initial token.
    uint256 public immutable recipientCap;

    /// @notice The fixed maximum supply, equal to recipientCap * TOKEN_PER_RECIPIENT.
    uint256 public immutable maximumSupply;

    /// @notice The permanent count of unique addresses that received an initial token.
    uint256 public totalInitialRecipients;

    /// @notice Whether reserve distribution has been permanently closed.
    bool public distributionFinalized;

    /// @notice Permanent record of every address that received a token from the reserve
    ///         through the authorized initial distribution. Once true, it never becomes false.
    /// @dev This is distribution history, not a live balance or eligibility claim. An initial
    ///      recipient may transfer their token away and still read true here with a zero balance.
    mapping(address account => bool) public wasInitialRecipient;

    /// @notice Reverts when the constructor distributor is the zero address.
    error ZeroDistributor();

    /// @notice Reverts when the constructor distributor is the token contract itself.
    /// @dev A deployment can predict its own address and pass it as the distributor. That would
    ///      permanently disable distribution: only the token contract could call {distribute} or
    ///      {finalizeDistribution}, and the token has no self-call mechanism. Other contract
    ///      distributors, such as a reviewed multisignature, remain valid.
    error TokenContractDistributor();

    /// @notice Reverts when the constructor recipient cap is zero.
    error ZeroRecipientCap();

    /// @notice Reverts when recipientCap * TOKEN_PER_RECIPIENT would overflow uint256.
    error RecipientCapOverflow();

    /// @notice Reverts when a caller is not the immutable distributor.
    /// @param caller The unauthorized caller.
    error UnauthorizedCaller(address caller);

    /// @notice Reverts when distribution has been permanently finalized.
    error DistributionAlreadyFinalized();

    /// @notice Reverts when a distribution contains no recipients.
    error EmptyRecipientArray();

    /// @notice Reverts when a distribution exceeds the hard batch ceiling.
    /// @param provided The submitted recipient count.
    /// @param maximum The hard maximum recipient count.
    error BatchSizeExceeded(uint256 provided, uint256 maximum);

    /// @notice Reverts when a distribution would exceed the lifetime recipient cap.
    /// @param attempted The lifetime recipient count the distribution would create.
    /// @param maximum The immutable recipient cap.
    error RecipientCapExceeded(uint256 attempted, uint256 maximum);

    /// @notice Reverts when a recipient is the zero address.
    /// @param index The zero-address recipient's calldata index.
    error ZeroRecipient(uint256 index);

    /// @notice Reverts when a recipient is the token contract itself.
    /// @dev Distributing to `address(this)` would self-transfer the unit, leaving the contract
    ///      balance unchanged while still consuming one unit of `recipientCap` and permanently
    ///      recording the token contract as an initial recipient. Ordinary contract recipients
    ///      are not rejected: multisignatures, custody addresses, and smart wallets may
    ///      legitimately appear in a separately approved recipient list.
    /// @param index The token-contract recipient's calldata index.
    error TokenContractRecipient(uint256 index);

    /// @notice Reverts when a recipient was already an initial recipient, including a duplicate
    ///         earlier in the same batch.
    /// @param recipient The previously distributed or duplicated recipient.
    error RecipientAlreadyDistributed(address recipient);

    /// @notice Emitted once when the distributor permanently closes distribution.
    /// @param distributor The immutable distributor that finalized.
    /// @param totalInitialRecipients The permanent count of initial recipients at finalization.
    /// @param contractBalanceAtFinalization The token contract's complete MREP2 balance when
    ///        distribution is finalized. This normally includes the remaining initial-distribution
    ///        allocation and may also include tokens holders transferred back to the contract, so it
    ///        is not a mathematically exact undistributed allocation. After finalization this balance
    ///        can no longer leave through {distribute}, though later ordinary transfers into the
    ///        contract may still increase its balance after this event.
    event DistributionFinalized(
        address indexed distributor, uint256 totalInitialRecipients, uint256 contractBalanceAtFinalization
    );

    /// @notice Creates the token, fixes the supply, and mints the whole reserve to the contract.
    /// @dev The deployer and distributor receive no token balance at construction. No function
    ///      can increase totalSupply() afterward. Validation precedence is exact: zero
    ///      distributor, token-contract distributor, zero recipient cap, then supply overflow.
    /// @param distributor_ The sole address permitted to distribute or finalize. It must be
    ///        neither the zero address nor the token contract itself; any other address,
    ///        including a reviewed contract, is accepted.
    /// @param recipientCap_ The maximum number of unique initial recipients.
    constructor(address distributor_, uint256 recipientCap_) ERC20("MIGRATE REPV2", "MREP2") {
        if (distributor_ == address(0)) {
            revert ZeroDistributor();
        }
        if (distributor_ == address(this)) {
            revert TokenContractDistributor();
        }
        if (recipientCap_ == 0) {
            revert ZeroRecipientCap();
        }
        if (recipientCap_ > type(uint256).max / TOKEN_PER_RECIPIENT) {
            revert RecipientCapOverflow();
        }

        uint256 supply = recipientCap_ * TOKEN_PER_RECIPIENT;

        distributor = distributor_;
        recipientCap = recipientCap_;
        maximumSupply = supply;

        _mint(address(this), supply);
    }

    /// @notice Sends exactly one whole MREP2 token from the reserve to each recipient.
    /// @dev Only the distributor may call this, only before finalization. The whole batch is
    ///      atomic: any invalid recipient reverts all prior mapping writes, balance changes,
    ///      events, and counter updates in the call. Duplicates within the batch and addresses
    ///      distributed to in an earlier batch are both rejected by {wasInitialRecipient}.
    ///      Per-recipient validation precedence is exact: zero address, token contract, then
    ///      prior initial recipient. Recipients are never filtered on bytecode presence.
    /// @param recipients The ordered recipient addresses to receive one initial token each.
    function distribute(address[] calldata recipients) external {
        if (msg.sender != distributor) {
            revert UnauthorizedCaller(msg.sender);
        }
        if (distributionFinalized) {
            revert DistributionAlreadyFinalized();
        }

        uint256 count = recipients.length;
        if (count == 0) {
            revert EmptyRecipientArray();
        }
        if (count > MAX_BATCH_SIZE) {
            revert BatchSizeExceeded(count, MAX_BATCH_SIZE);
        }

        uint256 attempted = totalInitialRecipients + count;
        if (attempted > recipientCap) {
            revert RecipientCapExceeded(attempted, recipientCap);
        }

        for (uint256 i = 0; i < count; ++i) {
            address recipient = recipients[i];
            if (recipient == address(0)) {
                revert ZeroRecipient(i);
            }
            if (recipient == address(this)) {
                revert TokenContractRecipient(i);
            }
            if (wasInitialRecipient[recipient]) {
                revert RecipientAlreadyDistributed(recipient);
            }

            wasInitialRecipient[recipient] = true;
            _transfer(address(this), recipient, TOKEN_PER_RECIPIENT);
        }

        totalInitialRecipients = attempted;
    }

    /// @notice Permanently closes reserve distribution.
    /// @dev Only the distributor may call this. Standard transfers, approvals, and transferFrom
    ///      continue afterward; any undistributed reserve remains permanently locked in the
    ///      contract and total supply does not change.
    function finalizeDistribution() external {
        if (msg.sender != distributor) {
            revert UnauthorizedCaller(msg.sender);
        }
        if (distributionFinalized) {
            revert DistributionAlreadyFinalized();
        }

        distributionFinalized = true;
        emit DistributionFinalized(distributor, totalInitialRecipients, balanceOf(address(this)));
    }
}
