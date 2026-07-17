# Contract Specification

## Purpose

`CHECK AUGUR REP MIGRATION` is a minimal, non-economic on-chain alert. The authority may issue one non-transferable unit to each approved address. An active holder may optionally burn only their own unit.

The alert is not REP, migrated REP, replacement REP, a claim, a reward, a governance asset, or an asset with value. Receiving it performs no migration, grants no right, proves neither REP ownership nor migration eligibility, and requires no action.

This document is authoritative for contract behavior. Operational controls are in [OPERATIONS.md](OPERATIONS.md); current evidence is in [VALIDATION.md](VALIDATION.md).

## Fixed metadata

| Property | Value |
| --- | --- |
| Name | `CHECK AUGUR REP MIGRATION` |
| Symbol | `MIGRATEREP` |
| Decimals | `0` |
| Unit per recipient | `1` |
| Initial `totalIssued` | `0` |
| Initial `totalSupply` | `0` |

Metadata is compiled into the contract and cannot change. The verified checksummed contract address published through official Augur sources is the canonical identity; matching metadata, source, ABI, price, or branding is not proof of authenticity.

## Architecture

The production contract is standalone, non-upgradeable, and intentionally ERC-20-shaped without being transferable. It uses explicit state and makes no external calls.

It has:

- one nonzero constructor-supplied immutable `authority`;
- one nonzero constructor-supplied immutable `distributionCap`;
- one private status entry per address;
- one atomic array-based issuance path;
- one holder-only self-burn path; and
- one irreversible finalization path.

Construction issues nothing. The deployer receives no inventory or implicit privilege; only the address explicitly supplied as `authority` can distribute or finalize. The authority cannot be transferred, replaced, renounced, recovered, or delegated.

The cap must equal the final approved manifest's unique-address count. It is a lifetime issuance limit, not an active-supply limit.

## Recipient state and accounting

Each address has exactly one of these states:

```text
NeverAlerted -> Active -> Burned
```

| State | `balanceOf(account)` | `wasAlerted(account)` |
| --- | ---: | --- |
| `NeverAlerted` | `0` | `false` |
| `Active` | `1` | `true` |
| `Burned` | `0` | `true` |

No transition returns an address to an earlier state.

- `totalIssued` is the number of unique addresses ever successfully alerted. It only increases.
- `totalSupply` is the number of active, unburned units. It increases on issuance and decreases on self-burn.
- `wasAlerted(account)` permanently distinguishes a never-alerted address from one that later burned.

At all times:

```text
totalSupply <= totalIssued <= distributionCap
```

Balances are always zero or one. The zero address is never alerted. Burning does not reduce `totalIssued`, restore cap headroom, or make an address eligible for reissuance.

## Public interface

| Function or read | Behavior |
| --- | --- |
| `name()` | Returns the fixed name |
| `symbol()` | Returns the fixed symbol |
| `decimals()` | Returns `0` |
| `authority()` | Returns the immutable authority |
| `distributionCap()` | Returns the immutable lifetime cap |
| `MAX_BATCH_SIZE()` | Returns the compile-time ceiling `500` |
| `totalIssued()` | Returns permanent unique issuance |
| `totalSupply()` | Returns active, unburned supply |
| `balanceOf(address)` | Returns `0` or `1` |
| `wasAlerted(address)` | Returns permanent alert history |
| `finalized()` | Returns whether issuance is closed |
| `allowance(address,address)` | Always returns `0` |
| `distribute(address[])` | Atomically issues one unit per valid recipient |
| `burn()` | Burns only the active caller's unit |
| `finalize()` | Irreversibly closes issuance |
| `transfer(address,uint256)` | Always reverts, including for value zero |
| `transferFrom(address,address,uint256)` | Always reverts |
| `approve(address,uint256)` | Always reverts |

## Distribution

`distribute(address[] recipients)` serves both canaries and batches. Only the authority may call it before finalization. A successful call marks every recipient `Active`, increments both counters by the recipient count, and emits one issuance event per recipient in calldata order.

The hard contract ceiling is `MAX_BATCH_SIZE = 500`. It is compile-time, publicly readable, checked before iteration, independent of the lifetime cap, and cannot be changed. Operations should normally use batches of approximately 100–200 for easier review, signing, monitoring, and reconciliation.

Validation precedence is exact:

1. caller is the authority;
2. distribution is not finalized;
3. the array is not empty;
4. the array has at most 500 entries;
5. the resulting `totalIssued` does not exceed `distributionCap`;
6. each recipient, in calldata order, is nonzero and has never been alerted.

Any failure reverts the complete call, including earlier writes and events. Duplicates within a call are rejected by the same permanent-status check as recipients from earlier calls. Active and burned prior recipients are both ineligible.

## Holder self-burn

`burn()` succeeds only when `msg.sender` is `Active`. It:

- changes only the caller from `Active` to `Burned`;
- reduces the caller's balance and `totalSupply` by one;
- leaves `totalIssued` and `wasAlerted(msg.sender)` unchanged; and
- emits `Transfer(msg.sender, address(0), 1)`.

Never-alerted and already-burned callers revert. No authority, deployer, operator, approved spender, or other account can burn for a holder. Burn remains available before and after finalization. It cannot erase transaction history, events, permanent alert history, or third-party cached records.

## Finalization

Only the authority may call `finalize()`. A successful call sets `finalized` permanently and emits `DistributionFinalized(authority, totalIssued)`. It changes no recipient state or counter at that moment.

Repeated finalization reverts. No issuance path remains after finalization, but an active holder may still burn. Consequently, `totalIssued` is fixed after finalization while `totalSupply` may decrease.

## Events

```solidity
event Transfer(address indexed from, address indexed to, uint256 value);
event DistributionFinalized(address indexed authority, uint256 finalIssued);
```

Issuance emits `Transfer(address(0), recipient, 1)`. Self-burn emits `Transfer(holder, address(0), 1)`. There is no on-chain batch identifier or manifest hash.

## Custom errors

| Error | Condition |
| --- | --- |
| `ZeroAuthority()` | Constructor authority is zero |
| `ZeroDistributionCap()` | Constructor cap is zero |
| `UnauthorizedCaller(address caller)` | Caller is not the authority |
| `DistributionAlreadyClosed()` | Distribution follows finalization |
| `EmptyRecipientArray()` | Recipient array is empty |
| `BatchSizeExceeded(uint256 provided, uint256 maximum)` | Recipient count exceeds 500 |
| `DistributionCapExceeded(uint256 attemptedIssued, uint256 cap)` | Attempted lifetime issuance exceeds the cap |
| `ZeroRecipient(uint256 index)` | Recipient at the reported index is zero |
| `RecipientAlreadyNotified(address recipient)` | Recipient is duplicated, active, or burned |
| `NoAlertBalance(address account)` | Caller has no active unit to burn |
| `TransferDisabled()` | Transfer or transfer-from is attempted |
| `ApprovalDisabled()` | Approval is attempted |
| `FinalizationAlreadyCompleted()` | Finalization is repeated |

## Forbidden functionality

The contract has no ownership or roles; authority transfer or recovery; secondary administrator; user mint or claim; delegated, authority, batch, or signature burn; permit or allowance mutation; pause; proxy or upgrade; `delegatecall`; `selfdestruct`; REP or migration-contract interaction; callback or hook; bridge or oracle; arbitrary external call; fallback or receive function; payable path; withdrawal or token recovery; mutable metadata; metadata URI; or migration URL in storage.

Exceptionally forced ETH is inert and unrecoverable, and contract behavior does not depend on its ETH balance.

## Security invariants

- Only the immutable authority can distribute or finalize; authority compromise cannot bypass the cap.
- Distribution is atomic, permanently rejects duplicate or burned recipients, and preserves calldata event order.
- `balanceOf(account)` is binary; a positive balance implies permanent alert history.
- `totalIssued` equals unique successful recipients; `totalSupply` equals active units.
- Failed calls change no state and leave no persistent events.
- Transfers and approvals cannot succeed, and allowance is always zero.
- Only an active holder can burn, and only their own unit.
- Finalization is irreversible, closes all issuance, and does not disable holder burn.
- No external interaction, privilege-recovery, movement, upgrade, or economic capability exists.

## Acceptance criteria

The candidate must pass unit, fuzz, stateful invariant, gas, coverage, ABI, storage-layout, compiler, and static-analysis review demonstrating:

- exact construction, metadata, initial state, interface, errors, and events;
- exact validation precedence and atomic rollback;
- successful issuance at 500 and exact oversized rejection at 501;
- cap-boundary success and over-cap rejection against `totalIssued`, including after burns;
- binary balances, permanent history, counter invariants, and permanent duplicate prevention;
- holder-only burn before and after finalization, with no delegated burn surface;
- authorized irreversible finalization and rejection of every later issuance;
- disabled movement and approval behavior before and after finalization; and
- absence of every forbidden surface listed above.

Independent review is required before deployment. Passing these criteria is evidence about tested behavior, not an audit or proof that vulnerabilities are absent.
