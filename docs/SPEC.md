# Contract Specification

## Purpose

`MigrateRepV2Token` (MIGRATE REPV2 / `MREP2`) is a conventional, transferable, fixed-supply ERC-20 notice token. The entire maximum supply is created once during construction and held by the token contract itself. The immutable distributor sends one whole token to each selected address through `distribute`, then permanently closes distribution with `finalizeDistribution`. Every other behavior is standard OpenZeppelin ERC-20.

MREP2 is a **notice token**. It is not REP, REPv2, a migration claim, migration eligibility proof, redemption right, governance right, reward, or a project-supported investment asset. Holding, transferring, or approving MREP2 performs no REP migration.

This document is authoritative for contract behavior. Operational controls are in [OPERATIONS.md](OPERATIONS.md); current evidence is in [VALIDATION.md](VALIDATION.md).

### Naming-risk disclosure

The name `MIGRATE REPV2` and symbol `MREP2` could be read by users as an actual REPv2 asset or as an instruction to migrate. They are neither. Documentation and explorer metadata must state plainly that MREP2 is a notice token and not REPv2 itself, and that receiving it requires no action.

## Fixed metadata

| Property | Value |
| --- | --- |
| Name | `MIGRATE REPV2` |
| Symbol | `MREP2` |
| Decimals | `18` (inherited OpenZeppelin default; not overridden) |
| One token | `TOKEN_PER_RECIPIENT = 1 ether = 1e18` base units |
| Maximum supply | `recipientCap * 1e18`, fixed at construction |

`decimals()` is the standard OpenZeppelin 18. The verified checksummed contract address published through official Augur sources is the canonical identity; matching metadata, source, ABI, price, or branding is not proof of authenticity.

## Architecture

The production contract inherits only OpenZeppelin `ERC20` (v5.6.1) and adds a fixed-supply reserve distribution layer. It has:

- three immutables: `distributor`, `recipientCap`, `maximumSupply`;
- two constants: `TOKEN_PER_RECIPIENT` (`1 ether`) and `MAX_BATCH_SIZE` (`200`);
- two counters/flags: `totalInitialRecipients` and `distributionFinalized`;
- one permanent history mapping: `wasInitialRecipient`;
- one atomic array-based distribution path and one irreversible finalization path.

The whole supply is minted to `address(this)` in the constructor. The deployer and distributor receive no balance. No function can increase `totalSupply()` after construction, and no function other than `distribute` can move the reserve out of the contract. There is no owner, role, pause, mint, holder burn, tax, blacklist, reentrancy surface, or upgrade path.

## Construction

```solidity
constructor(address distributor_, uint256 recipientCap_) ERC20("MIGRATE REPV2", "MREP2")
```

Validation, in order: `distributor_` nonzero (`ZeroDistributor`), `recipientCap_` nonzero (`ZeroRecipientCap`), and `recipientCap_ * TOKEN_PER_RECIPIENT` non-overflowing (`RecipientCapOverflow`). It then sets the three immutables and mints `maximumSupply` to `address(this)`.

Initial state:

```text
totalSupply()              == maximumSupply == recipientCap * 1e18
balanceOf(address(this))   == maximumSupply
balanceOf(distributor)     == 0
balanceOf(deployer)        == 0
totalInitialRecipients     == 0
distributionFinalized      == false
```

## Fixed-supply reserve

The reserve stays at `address(this)` until distributed. It is never minted to the deployer, distributor, an owner, or a treasury, so no privileged account can move it through ordinary transfers. The only exit is `distribute`. There is no reserve-recovery, rescue, or arbitrary transfer-from-contract function. Any reserve left after finalization is permanently locked; it is never burned, swept, or sent to a dead address.

## Distribution

```solidity
function distribute(address[] calldata recipients) external
```

Only the immutable `distributor` may call it, only before finalization. Each valid recipient is marked `wasInitialRecipient` and receives exactly `TOKEN_PER_RECIPIENT` via the inherited `_transfer(address(this), recipient, ...)`, emitting the standard ERC-20 `Transfer(address(this), recipient, 1e18)`. After the loop, `totalInitialRecipients` increases once by the recipient count. The distributor may call it repeatedly with different batches until the cap is reached or distribution is finalized.

Validation precedence is exact:

1. caller is the distributor (`UnauthorizedCaller`);
2. distribution is not finalized (`DistributionAlreadyFinalized`);
3. the array is not empty (`EmptyRecipientArray`);
4. the array has at most `MAX_BATCH_SIZE` entries (`BatchSizeExceeded`);
5. the resulting lifetime count does not exceed `recipientCap` (`RecipientCapExceeded`);
6. each recipient, in calldata order, is nonzero (`ZeroRecipient`) and not already an initial recipient (`RecipientAlreadyDistributed`).

Any failure reverts the complete call, including earlier mapping writes, balance changes, `Transfer` events, and the counter update. A duplicate within one batch is rejected by the same `wasInitialRecipient` check that rejects a recipient from an earlier batch. The contract makes no external third-party calls.

## Initial-recipient history

`wasInitialRecipient(address)` records that an address received one token directly from the reserve through the authorized distribution. It does **not** mean the address currently holds MREP2, owns REP or REPv2, is eligible to migrate, or that any migration occurred. An initial recipient may transfer the token away and keep `wasInitialRecipient == true` with `balanceOf == 0`. An address that only received transferred tokens has `wasInitialRecipient == false` with a positive balance and remains eligible for exactly one direct distribution. Once true, the flag never becomes false. There is no on-chain recipient array or holder enumeration.

## Standard ERC-20 behavior

`name`, `symbol`, `decimals`, `totalSupply`, `balanceOf`, `transfer`, `allowance`, `approve`, and `transferFrom` are the inherited OpenZeppelin implementations and are not overridden, nor are `_update`, `_transfer`, `_approve`, or `_spendAllowance`. Any holder may transfer any amount they own; balances may exceed one token; zero-value transfers succeed and emit `Transfer`; `transfer` and `approve` return `true`; finite allowances decrease and the maximum allowance is treated as infinite per OpenZeppelin; standard OpenZeppelin errors are preserved and not wrapped. Transfers, approvals, and `transferFrom` continue unchanged after finalization.

## Finalization

```solidity
function finalizeDistribution() external
```

Only the distributor may call it. A successful call sets `distributionFinalized = true` permanently and emits `DistributionFinalized(distributor, totalInitialRecipients, balanceOf(address(this)))`. Repeated finalization reverts (`DistributionAlreadyFinalized`). Finalization closes reserve distribution only; it does not freeze the token — holder transfers, approvals, and `transferFrom` all continue, total supply is unchanged, and unused reserve remains locked. The entire reserve need not be distributed before finalizing.

## Supply semantics and invariants

```text
maximumSupply           = recipientCap * TOKEN_PER_RECIPIENT
totalSupply()           == maximumSupply                       (always, after construction)
distributed amount      = totalInitialRecipients * TOKEN_PER_RECIPIENT
totalInitialRecipients  <= recipientCap
wasInitialRecipient      only changes false -> true
```

`totalInitialRecipients` is the authoritative permanent distribution count. Because ordinary users may later transfer tokens back to `address(this)`, `balanceOf(address(this))` is not proof of the original remaining allocation once public transfers begin. Transfers never affect total supply, the recipient cap, `totalInitialRecipients`, or initial-recipient history.

## Events

```solidity
event Transfer(address indexed from, address indexed to, uint256 value);        // OpenZeppelin
event Approval(address indexed owner, address indexed spender, uint256 value);   // OpenZeppelin
event DistributionFinalized(
    address indexed distributor, uint256 totalInitialRecipients, uint256 undistributedReserve
);
```

Distribution emits the standard `Transfer(address(this), recipient, 1e18)` per recipient in calldata order; there is no custom transfer event, batch identifier, or manifest hash.

## Custom errors

`ZeroDistributor`, `ZeroRecipientCap`, `RecipientCapOverflow`, `UnauthorizedCaller(address)`, `DistributionAlreadyFinalized`, `EmptyRecipientArray`, `BatchSizeExceeded(uint256,uint256)`, `RecipientCapExceeded(uint256,uint256)`, `ZeroRecipient(uint256)`, `RecipientAlreadyDistributed(address)`.

The single `DistributionAlreadyFinalized` covers both distribution-after-finalization and repeated finalization (the two overlapping finalization errors are consolidated). Inherited OpenZeppelin `IERC20Errors` are used unchanged for standard transfer and allowance failures and are not duplicated or wrapped. Errors carry no strings, links, instructions, or promotional text.

## Forbidden functionality

No holder burn (`ERC20Burnable` is not inherited; no `burn`/`burnFrom`); no owner, role, or authority-transfer system; no post-deployment, public, signature, or claim mint; no permit, pause, proxy, upgrade, `delegatecall`, or `selfdestruct`; no tax, fee, reflection, rebasing, liquidity, DEX/router detection, blacklist, allowlist, cooldown, or trading switch; no callback, hook, bridge, oracle, arbitrary external call, fallback, receive, payable path, withdrawal, or token recovery; no REP or migration-contract interaction; no mutable metadata, token URI, or migration URL in storage. Forced ETH is inert and unrecoverable, and behavior never depends on the contract's ETH balance.

## Acceptance criteria

The candidate must pass unit, fuzz, invariant, gas, coverage, ABI, storage-layout, lint, and static-analysis review demonstrating exact construction, metadata, and initial state; the exact distribution validation precedence and atomic rollback; success at the `200`-recipient maximum and exact rejection at `201`; cap-boundary success and over-cap rejection; permanent, binary history and duplicate prevention; unrestricted standard ERC-20 behavior before and after finalization; irreversible finalization with continuing transfers; a fixed supply with no post-construction mint; and the absence of every forbidden surface. Passing these criteria is evidence about tested behavior, not an audit or proof that vulnerabilities are absent.
