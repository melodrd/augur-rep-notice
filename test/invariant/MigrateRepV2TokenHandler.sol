// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import {Test} from "forge-std/Test.sol";

import {MigrateRepV2Token} from "../../src/MigrateRepV2Token.sol";

/// @dev Stateful handler that drives the token through distribution, transfers, approvals,
///      transferFrom, and finalization. All value stays within a fixed actor pool plus the token
///      contract itself, so the invariant suite can reconcile the full balance set.
///      Every action guards its preconditions so the handler never reverts.
///
///      Transfers and approved transferFrom operations may target `address(token)`. CHECKAUGUR is
///      freely transferable, so any holder may send tokens back to the token contract, and the
///      invariants must model that rather than assume the contract balance is only the
///      undistributed initial allocation. Returned tokens are tracked in
///      {ghostReturnedToContract}; they can never leave again, because the only exit from the
///      contract is {MigrateRepV2Token.distribute}, which moves exactly one unit per new recipient.
contract MigrateRepV2TokenHandler is Test {
    MigrateRepV2Token public immutable token;
    address public immutable distributor;

    uint256 public constant ACTOR_COUNT = 8;
    address[ACTOR_COUNT] public actors;

    // Ghost accounting the invariants reconcile against on-chain state.

    /// @notice Units of one token distributed, counted by the handler as it distributes.
    uint256 public ghostInitialRecipients;

    /// @notice Base units transferred back into the token contract by ordinary ERC-20 transfers.
    uint256 public ghostReturnedToContract;

    /// @notice Handler-side mirror of `wasInitialRecipient`. Once set it is never cleared, so the
    ///         invariants can prove the on-chain flag never reverts to false.
    mapping(address account => bool) public ghostEverFlagged;

    constructor(MigrateRepV2Token token_, address distributor_) {
        token = token_;
        distributor = distributor_;
        for (uint256 i = 0; i < ACTOR_COUNT; ++i) {
            actors[i] = address(uint160(0xACC0 + i));
        }
    }

    function actorAt(uint256 i) external view returns (address) {
        return actors[i];
    }

    // ---- handler actions ----

    function distribute(uint256 count) external {
        if (token.distributionFinalized()) return;

        uint256 remainingCap = token.recipientCap() - token.totalInitialRecipients();
        if (remainingCap == 0) return;

        // Collect actors that are not yet initial recipients.
        address[] memory candidates = new address[](ACTOR_COUNT);
        uint256 available;
        for (uint256 i = 0; i < ACTOR_COUNT; ++i) {
            if (!token.wasInitialRecipient(actors[i])) {
                candidates[available] = actors[i];
                available++;
            }
        }
        if (available == 0) return;

        uint256 max = available < remainingCap ? available : remainingCap;
        if (max > token.MAX_BATCH_SIZE()) max = token.MAX_BATCH_SIZE();
        uint256 n = bound(count, 1, max);

        address[] memory batch = new address[](n);
        for (uint256 i = 0; i < n; ++i) {
            batch[i] = candidates[i];
            // The candidate list is filtered on the on-chain flag; this also pins the handler's
            // own mirror, so a repeated initial distribution would fail here rather than silently
            // corrupt the ghost accounting.
            assertFalse(ghostEverFlagged[batch[i]], "handler distributed to one address twice");
        }

        vm.prank(distributor);
        token.distribute(batch);

        for (uint256 i = 0; i < n; ++i) {
            ghostEverFlagged[batch[i]] = true;
        }
        ghostInitialRecipients += n;
    }

    /// @param toContract When true the destination is the token contract itself, modelling a
    ///        holder returning CHECKAUGUR to `address(token)`.
    function transfer(uint256 fromIdx, uint256 toIdx, uint256 amount, bool toContract) external {
        address from = actors[fromIdx % ACTOR_COUNT];
        address to = toContract ? address(token) : actors[toIdx % ACTOR_COUNT];
        uint256 bal = token.balanceOf(from);
        if (bal == 0) return;
        amount = bound(amount, 0, bal);

        vm.prank(from);
        token.transfer(to, amount);

        if (to == address(token)) {
            ghostReturnedToContract += amount;
        }
    }

    /// @param toContract When true the approved spender moves the owner's tokens into the token
    ///        contract instead of taking them, modelling a return through `transferFrom`.
    function approveAndTransferFrom(uint256 ownerIdx, uint256 spenderIdx, uint256 amount, bool toContract) external {
        address owner = actors[ownerIdx % ACTOR_COUNT];
        address spender = actors[spenderIdx % ACTOR_COUNT];
        address destination = toContract ? address(token) : spender;
        uint256 bal = token.balanceOf(owner);
        if (bal == 0) return;
        amount = bound(amount, 0, bal);

        vm.prank(owner);
        token.approve(spender, amount);

        vm.prank(spender);
        token.transferFrom(owner, destination, amount);

        if (destination == address(token)) {
            ghostReturnedToContract += amount;
        }
    }

    function finalize() external {
        if (token.distributionFinalized()) return;
        vm.prank(distributor);
        token.finalizeDistribution();
    }
}
