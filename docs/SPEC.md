# Contract Specification

## Purpose

`MigrateRepV2Token` (CHECK AUGUR MIGRATION / `CHECKAUGUR`) is a conventional, transferable, fixed-supply ERC-20 notice token. The entire maximum supply is created once during construction and held by the token contract itself. The immutable distributor sends one whole token to each selected address through `distribute`, then permanently closes distribution with `finalizeDistribution`. Every other behavior is standard OpenZeppelin ERC-20.

CHECKAUGUR is a **notice token**. It is not REP, REPv2, a migration claim, migration eligibility proof, redemption right, governance right, reward, or a project-supported investment asset. Holding, transferring, or approving CHECKAUGUR performs no REP migration.

This document is authoritative for contract behavior. Deployment and operational controls are in [OPERATIONS.md](OPERATIONS.md).

## Fixed metadata

| Property | Value |
| --- | --- |
| Name | `CHECK AUGUR MIGRATION` |
| Symbol | `CHECKAUGUR` |
| Decimals | `18` (inherited OpenZeppelin default; not overridden) |
| One token | `TOKEN_PER_RECIPIENT = 1 ether = 1e18` base units |
| Maximum supply | `recipientCap * 1e18`, fixed at construction |

`decimals()` is the standard OpenZeppelin 18. A specific deployment is identified by its verified, checksummed contract address and that address's on-chain source verification; matching metadata, source, ABI, price, or branding is not proof of authenticity.

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
constructor(address distributor_, uint256 recipientCap_) ERC20("CHECK AUGUR MIGRATION", "CHECKAUGUR")
```

Validation precedence is exact:

1. `distributor_` is nonzero (`ZeroDistributor`);
2. `distributor_` is not `address(this)` (`TokenContractDistributor`);
3. `recipientCap_` is nonzero (`ZeroRecipientCap`);
4. `recipientCap_ * TOKEN_PER_RECIPIENT` does not overflow (`RecipientCapOverflow`).

It then sets the three immutables and mints `maximumSupply` to `address(this)`.

A deployer can predict the address its next `CREATE` will produce and pass it as `distributor_`. The resulting contract would be permanently unusable: only the token contract could call `distribute` or `finalizeDistribution`, and it has no self-call mechanism, so the whole supply would be locked forever with no distribution possible. `TokenContractDistributor` rejects exactly this case. Other contract distributors are not rejected — a reviewed multisignature may legitimately hold distribution authority.

Initial state:

```text
totalSupply()              == maximumSupply == recipientCap * 1e18
balanceOf(address(this))   == maximumSupply
balanceOf(distributor)     == 0
balanceOf(deployer)        == 0
totalInitialRecipients     == 0
distributionFinalized      == false
```

## Fixed-supply initial allocation

The whole supply is minted to `address(this)` and stays there until distributed. It is never minted to the deployer, distributor, an owner, or a treasury, so no privileged account can move it through ordinary transfers. The only exit is `distribute`. There is no reserve-recovery, rescue, or arbitrary transfer-from-contract function. Anything left at the contract after finalization is permanently locked; it is never burned, swept, or sent to a dead address.

Two quantities are distinct and are never used interchangeably in this repository:

- **remaining initial allocation** — `(recipientCap - totalInitialRecipients) * TOKEN_PER_RECIPIENT`. The part of the original allocation not yet distributed. It is computable off-chain from the manifest and only ever decreases, by exactly one token per new recipient.
- **token contract balance** — `balanceOf(address(this))`. The contract's complete live balance. It equals the remaining initial allocation *plus* any tokens holders transferred back to the contract, so it is not predictable off-chain once public transfers begin.

The word "reserve", where it appears below, means the initial allocation — never the complete contract balance.

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
6. each recipient, in calldata order, passes per-recipient validation.

Per-recipient validation precedence is itself exact:

1. the recipient is not the zero address (`ZeroRecipient`);
2. the recipient is not the token contract (`TokenContractRecipient`);
3. the recipient is not already an initial recipient (`RecipientAlreadyDistributed`).

Any failure reverts the complete call, including earlier mapping writes, balance changes, `Transfer` events, and the counter update. A duplicate within one batch is rejected by the same `wasInitialRecipient` check that rejects a recipient from an earlier batch. The contract makes no external third-party calls.

### The token contract is never a recipient

Distributing to `address(this)` would consume a recipient slot without moving any balance or representing a legitimate external recipient. The self-transfer `_transfer(address(this), address(this), TOKEN_PER_RECIPIENT)` leaves the contract's balance unchanged while still consuming one unit of `recipientCap` and permanently recording the token contract as an initial recipient. `TokenContractRecipient(index)` rejects it before any state changes, and the rejection reverts the whole batch atomically.

Only the token contract is rejected. Recipients are **never** filtered on bytecode presence: `recipient.code.length` is not consulted anywhere. A multisignature, custody address, or smart wallet is an ordinary recipient and may legitimately appear in a separately approved recipient list. Bytecode presence would neither identify who controls an address nor establish eligibility, so it is a policy question resolved off-chain, not an on-chain filter.

## Initial-recipient history

`wasInitialRecipient(address)` records that an address received one token directly from the reserve through the authorized distribution. It does **not** mean the address currently holds CHECKAUGUR, owns REP or REPv2, is eligible to migrate, or that any migration occurred. An initial recipient may transfer the token away and keep `wasInitialRecipient == true` with `balanceOf == 0`. An address that only received transferred tokens has `wasInitialRecipient == false` with a positive balance and remains eligible for exactly one direct distribution. Once true, the flag never becomes false. There is no on-chain recipient array or holder enumeration.

## Standard ERC-20 behavior

`name`, `symbol`, `decimals`, `totalSupply`, `balanceOf`, `transfer`, `allowance`, `approve`, and `transferFrom` are the inherited OpenZeppelin implementations and are not overridden, nor are `_update`, `_transfer`, `_approve`, or `_spendAllowance`. Any holder may transfer any amount they own; balances may exceed one token; zero-value transfers succeed and emit `Transfer`; `transfer` and `approve` return `true`; finite allowances decrease and the maximum allowance is treated as infinite per OpenZeppelin; standard OpenZeppelin errors are preserved and not wrapped. Transfers, approvals, and `transferFrom` continue unchanged after finalization.

## Finalization

```solidity
function finalizeDistribution() external
```

Only the distributor may call it. A successful call sets `distributionFinalized = true` permanently and emits `DistributionFinalized(distributor, totalInitialRecipients, balanceOf(address(this)))`. Repeated finalization reverts (`DistributionAlreadyFinalized`). Finalization closes reserve distribution only; it does not freeze the token — holder transfers, approvals, and `transferFrom` all continue, total supply is unchanged, and unused reserve remains locked. The entire reserve need not be distributed before finalizing.

The event's third field, `contractBalanceAtFinalization`, is the token contract's complete live balance `balanceOf(address(this))` at the moment of finalization. Two distinct quantities must not be conflated:

- **Remaining initial allocation** — `(recipientCap - totalInitialRecipients) * TOKEN_PER_RECIPIENT`. The base units of the original allocation not yet distributed to initial recipients.
- **Token contract balance** — `balanceOf(address(this))`. The complete live balance held by the token contract. It may include the remaining initial allocation *and* any tokens holders voluntarily transferred back to the contract.

These two values are equal before any holder returns tokens to the contract, but they are not guaranteed to remain equal, because CHECKAUGUR is freely transferable and a holder may transfer a token to `address(this)`. The event therefore records the complete contract balance, not a mathematically exact undistributed allocation, and must not be labeled `undistributedReserve`. After finalization this balance can no longer leave through `distribute`, though later ordinary transfers into the contract may still increase it.

## Supply semantics and invariants

```text
maximumSupply           = recipientCap * TOKEN_PER_RECIPIENT
totalSupply()           == maximumSupply                       (always, after construction)
distributed amount      = totalInitialRecipients * TOKEN_PER_RECIPIENT
totalInitialRecipients  <= recipientCap
wasInitialRecipient      only changes false -> true
```

`totalInitialRecipients` is the authoritative permanent distribution count. Because ordinary users may later transfer tokens back to `address(this)`, `balanceOf(address(this))` is not proof of the original remaining allocation once public transfers begin. The exact relationship is:

```text
balanceOf(address(this)) = maximumSupply
                         - totalInitialRecipients * TOKEN_PER_RECIPIENT
                         + tokens returned to the contract
```

Returned tokens can never leave again: the only exit is `distribute`, which moves exactly one unit per new recipient and stops entirely at finalization. Transfers never affect total supply, the recipient cap, `totalInitialRecipients`, or initial-recipient history.

## Events

```solidity
event Transfer(address indexed from, address indexed to, uint256 value);        // OpenZeppelin
event Approval(address indexed owner, address indexed spender, uint256 value);   // OpenZeppelin
event DistributionFinalized(
    address indexed distributor, uint256 totalInitialRecipients, uint256 contractBalanceAtFinalization
);
```

Distribution emits the standard `Transfer(address(this), recipient, 1e18)` per recipient in calldata order; there is no custom transfer event, batch identifier, or manifest hash.

## Custom errors

`ZeroDistributor`, `TokenContractDistributor`, `ZeroRecipientCap`, `RecipientCapOverflow`, `UnauthorizedCaller(address)`, `DistributionAlreadyFinalized`, `EmptyRecipientArray`, `BatchSizeExceeded(uint256,uint256)`, `RecipientCapExceeded(uint256,uint256)`, `ZeroRecipient(uint256)`, `TokenContractRecipient(uint256)`, `RecipientAlreadyDistributed(address)`.

The single `DistributionAlreadyFinalized` covers both distribution-after-finalization and repeated finalization (the two overlapping finalization errors are consolidated). Inherited OpenZeppelin `IERC20Errors` are used unchanged for standard transfer and allowance failures and are not duplicated or wrapped. Errors carry no strings, links, instructions, or promotional text.

## Forbidden functionality

No holder burn (`ERC20Burnable` is not inherited; no `burn`/`burnFrom`); no owner, role, or authority-transfer system; no post-deployment, public, signature, or claim mint; no permit, pause, proxy, upgrade, `delegatecall`, or `selfdestruct`; no tax, fee, reflection, rebasing, liquidity, DEX/router detection, blacklist, allowlist, cooldown, or trading switch; no callback, hook, bridge, oracle, arbitrary external call, fallback, receive, payable path, withdrawal, or token recovery; no REP or migration-contract interaction; no mutable metadata, token URI, or migration URL in storage. Forced ETH is inert and unrecoverable, and behavior never depends on the contract's ETH balance.

## Acceptance criteria

The candidate must pass unit, fuzz, invariant, gas, coverage, ABI, storage-layout, lint, and static-analysis review demonstrating exact construction, metadata, and initial state; both validation precedences (constructor and per-recipient) and atomic rollback; rejection of the token contract as recipient and as distributor, with ordinary contract recipients and distributors still supported; success at the `200`-recipient maximum and exact rejection at `201`; cap-boundary success and over-cap rejection; permanent, binary history and duplicate prevention; unrestricted standard ERC-20 behavior before and after finalization; the returned-token balance model; irreversible finalization with continuing transfers; a fixed supply with no post-construction mint; and the absence of every forbidden surface.

Passing these criteria is evidence about tested behavior, not an audit or proof that vulnerabilities are absent. The candidate is not approved for mainnet until an independent Solidity reviewer has inspected the final production source, dependency pin, supply and distribution model, ABI, storage layout, constructor arguments, and the final recipient manifest and provenance.
