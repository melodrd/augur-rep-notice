// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import {Test} from "forge-std/Test.sol";

import {MigrateRepV2Token} from "../../src/MigrateRepV2Token.sol";

/// @dev Stateful handler that drives the token through distribution, transfers, approvals,
///      transferFrom, and finalization. All value stays within a fixed actor pool plus the
///      token reserve, so the invariant suite can reconcile the full balance set.
///      Every action guards its preconditions so the handler never reverts.
contract MigrateRepV2TokenHandler is Test {
    MigrateRepV2Token public immutable token;
    address public immutable distributor;

    uint256 public constant ACTOR_COUNT = 8;
    address[ACTOR_COUNT] public actors;

    // Ghost accounting the invariants reconcile against on-chain state.
    uint256 public ghostInitialRecipients;

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
        }

        vm.prank(distributor);
        token.distribute(batch);
        ghostInitialRecipients += n;
    }

    function transfer(uint256 fromIdx, uint256 toIdx, uint256 amount) external {
        address from = actors[fromIdx % ACTOR_COUNT];
        address to = actors[toIdx % ACTOR_COUNT];
        uint256 bal = token.balanceOf(from);
        if (bal == 0) return;
        amount = bound(amount, 0, bal);
        vm.prank(from);
        token.transfer(to, amount);
    }

    function approveAndTransferFrom(uint256 ownerIdx, uint256 spenderIdx, uint256 amount) external {
        address owner = actors[ownerIdx % ACTOR_COUNT];
        address spender = actors[spenderIdx % ACTOR_COUNT];
        uint256 bal = token.balanceOf(owner);
        if (bal == 0) return;
        amount = bound(amount, 0, bal);

        vm.prank(owner);
        token.approve(spender, amount);

        vm.prank(spender);
        token.transferFrom(owner, spender, amount);
    }

    function finalize() external {
        if (token.distributionFinalized()) return;
        vm.prank(distributor);
        token.finalizeDistribution();
    }
}
