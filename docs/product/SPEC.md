# REP MIGRATION ALERT Contract Specification

Status: Approved for implementation

Revision date: 2026-07-16

Current phase: Product specification, threat model, and acceptance criteria complete. Minimal contract implementation is next.

This specification defines the contract behavior. Changes require a specification update, threat-model review, and acceptance-criteria update before implementation.

## 1. Purpose and meaning

The contract is a minimal, non-economic on-chain communication artifact related to Augur REP migration. It records that the authority issued one alert unit to an address in a reviewed recipient set.

Receiving the alert:

- does not migrate REP;
- does not prove current REP ownership or migration eligibility;
- does not grant REP, a claim, a reward, governance power, or another right;
- does not require approval, transfer, swap, burn, bridge, claim, signature, or wallet connection;
- does not prove that a human controls the address or saw the alert.

The canonical public wording and publication rules are maintained in
[`docs/communications/MESSAGING.md`](../communications/MESSAGING.md).

## 2. Metadata

| Property | Approved value |
| --- | --- |
| Name | `REP MIGRATION ALERT` |
| Symbol | `CHECKREP` |
| Decimals | `0` |
| Unit per recipient | `1` |
| Initial supply | `0` |

### 2.1 Name rationale

`REP MIGRATION ALERT` clearly identifies REP migration as the subject and is more noticeable than passive notice wording. `ALERT` signals importance without claiming economic value. The name does not claim to be REP, migrated REP, replacement REP, or a claim, and it does not instruct the recipient to interact with the token.

The name remains understandable without supporting context, but third-party interfaces may truncate it, hide it, or classify it as spam.

### 2.2 Symbol rationale

`CHECKREP` directs attention toward checking official REP migration information. It is not a replacement REP denomination and must not be presented as an instruction to interact with the alert.

```text
CHECKREP means:
Check official REP migration information.

CHECKREP does not mean:
Approve, transfer, swap, burn, claim, sign, or connect a wallet.
```

### 2.3 Fixed metadata and canonical identity

Name, symbol, and decimals are compiled into the contract. They are not constructor parameters and cannot change after deployment. A metadata change requires a new reviewed candidate and deployment.

The deployed contract address, verified through official Augur sources, is the only canonical on-chain identity. Matching metadata, source, ABI, logos, price data, or liquidity does not prove authenticity.

### 2.4 Current third-party scope

Etherscan is the only third-party metadata surface currently in scope. Source verification and metadata operations follow the
[Etherscan runbook](../operations/ETHERSCAN_RUNBOOK.md).

Browser and mobile wallets, portfolio trackers, token lists, CoinGecko, CoinMarketCap, and other market-data or asset-listing services are deferred for a later specification and operations review. No wallet-product matrix or submission to those services is currently approved, and no current release gate depends on their inclusion.

The project does not claim that wallets will automatically display the alert.

## 3. Contract architecture

The implementation must be one standalone, non-upgradeable contract with explicit state, functions, errors, and events.

It must not inherit from OpenZeppelin `ERC20`, `Ownable`, `Ownable2Step`, `AccessControl`, `Pausable`, proxy, upgradeable, or generalized token contracts.

It must not include:

- a proxy, implementation pointer, upgrade mechanism, or `delegatecall`;
- authority transfer, ownership, role administration, successor nomination, or recovery administration;
- arbitrary external calls, callbacks, hooks, bridges, or oracles;
- REP custody, REP approval, REP transfer, or migration-contract calls;
- payable functions, an intended receive path, ETH withdrawal, or token recovery;
- a fallback function;
- a metadata URI or mutable metadata system;
- a user claim flow.

Exceptionally forced ETH is inert and permanently unrecoverable. Contract behavior must not depend on its ETH balance.

## 4. ERC-20-shaped interface

The contract exposes familiar selectors for explorer, indexer, wallet, and tooling recognition. It does not claim full ERC-20 behavioral compliance.

| Function | Required behavior |
| --- | --- |
| `name()` | Return `REP MIGRATION ALERT` |
| `symbol()` | Return `CHECKREP` |
| `decimals()` | Return `0` |
| `totalSupply()` | Return the number of unique successful recipients |
| `balanceOf(address)` | Return `0` or `1` |
| `allowance(address,address)` | Always return `0` |
| `transfer(address,uint256)` | Always revert, including zero-value calls |
| `transferFrom(address,address,uint256)` | Always revert |
| `approve(address,uint256)` | Always revert |
| `authority()` | Return the immutable authority |
| `distributionCap()` | Return the immutable cap |
| `finalized()` | Return the finalization state |
| Maximum-batch read | Return the compile-time maximum after it is frozen |
| `distribute(address[] recipients)` | Execute the only issuance path |
| `finalize()` | Permanently close issuance |

Permit, allowance-changing helpers, operator approvals, approval callbacks, and burn functions are absent.

## 5. State and supply

- Initial total supply is zero.
- Construction issues no alert units.
- Each successful recipient receives exactly one unit.
- Balances are always zero or one.
- Total supply equals the number of unique successful recipients.
- The zero address never has a balance.
- Failed calls do not change balances, supply, finalization state, or persistent events.
- Existing balances remain after finalization.
- No transfer or burn can change a balance.

No separate `wasNotified(address)` state or read is required. A balance of one is the receipt record.

## 6. Authority and deployment model

The constructor receives one nonzero immutable authority.

The approved production authority is one dedicated externally owned account controlled by the project owner. The same dedicated EOA is expected to:

1. submit the contract deployment transaction;
2. be passed explicitly as the immutable authority constructor argument;
3. distribute alerts;
4. execute finalization.

The approved production arrangement is:

```text
deployer address == immutable authority address
```

Deployment alone grants no privilege. The deployer has authority only because the same address is deliberately supplied as the constructor authority argument. If another address deployed the same bytecode, that unrelated deployer would receive no implicit permission.

The authority:

- may distribute before finalization;
- may finalize;
- cannot be transferred, replaced, renounced, delegated, or restored;
- cannot nominate a successor or secondary administrator;
- has no effective power after finalization.

There is no post-deployment authority handoff. An incorrect authority requires abandonment or redeployment.

### 6.1 Dedicated EOA policy

The production EOA:

- is controlled by the project owner;
- is dedicated to this campaign and is not an everyday wallet;
- is not used for unrelated DeFi, protocol, token, or custody activity;
- intentionally holds only the ETH reasonably required for deployment and campaign transactions;
- should use hardware-backed signing;
- uses a mainnet key that is not reused for Sepolia;
- requires manual review of every chain, target, value, calldata, nonce, expected state change, and simulation before signing;
- must never expose its private key, seed phrase, recovery phrase, keystore contents, or secret environment values to the repository, documentation, shell history, agents, or automated tooling.

Agents and automated tools may prepare unsigned artifacts and simulations. They may never access the private key, sign, submit, or broadcast.

### 6.2 Accepted EOA risks

**Key loss.** Permanent key loss makes further distribution and finalization impossible. The authority cannot be replaced, and the deployment may need to be abandoned.

**Key compromise.** An attacker may distribute to incorrect addresses within the remaining cap or finalize prematurely. The cap limits total issuance but does not ensure recipient correctness. Emergency finalization helps only while legitimate control remains.

**Single-person operation.** One project owner manually reviews and signs privileged transactions. This provides less authorization redundancy than multi-party control and is accepted for the chosen operating model.

## 7. Distribution

There is exactly one issuance operation:

```text
distribute(address[] recipients)
```

It serves one-address canaries and multi-address batches through the same authorization, validation, cap, event, and finalization logic.

### 7.1 Validation

The complete call reverts when:

- the caller is not the immutable authority;
- distribution is finalized;
- the array is empty;
- any recipient is the zero address;
- any recipient appears more than once in the submitted array;
- any recipient already has a balance;
- the array exceeds the compile-time maximum batch size;
- `totalSupply + recipients.length` exceeds the immutable cap.

A valid contract address is technically accepted on-chain. Account classification and recipient eligibility are off-chain responsibilities.

### 7.2 Atomicity

Distribution is all-or-nothing. Any invalid recipient or failed condition reverts the complete call. No partial balance, supply, or event change may persist.

Silent skipping, partial success, best-effort behavior, and idempotent duplicate handling are rejected.

### 7.3 Immutable cap

The constructor receives a nonzero immutable `distributionCap`.

The cap must equal the exact number of unique addresses in the final approved production recipient manifest. A discretionary margin or unused issuance headroom is not allowed.

Every successful call satisfies:

```text
totalSupply + recipients.length <= distributionCap
```

Reaching the cap does not automatically finalize. A material recipient-set change after deployment may require abandonment and redeployment.

### 7.4 Maximum batch size

The exact maximum batch size remains deferred until candidate measurements exist.

The implementation must:

1. measure entirely new recipients and include calldata cost;
2. test batch sizes `1`, `10`, `25`, `50`, `100`, `200`, and `500` when feasible;
3. cover the proposed maximum, duplicate, prior-recipient, cap-boundary, cap-overflow, and revert cases;
4. use a pinned target-chain block gas limit;
5. choose a compile-time maximum whose worst-case successful call uses no more than 50% of that limit;
6. use a lower bound when execution, calldata, transaction tooling, or signing workflow is stricter;
7. record the benchmark, block conditions, constant, and margin;
8. obtain independent review before freezing the constant.

## 8. Movement, approvals, permit, and burn

- `transfer` always reverts, including zero-value calls.
- `transferFrom` always reverts.
- `approve` always reverts.
- `allowance` always returns zero.
- No movement path is externally reachable.
- Permit and allowance-changing helpers are absent.
- Operator approvals and callbacks are absent.
- Holder burn, authority burn, and `burnFrom` are absent.

Recipients should hide the alert through interface controls rather than interact with it.

## 9. Finalization

Only the immutable authority may finalize.

Finalization:

- is explicit and one-time;
- is irreversible;
- permanently closes every issuance path;
- reverts when repeated;
- preserves balances and supply;
- does not create transferability;
- does not clear or replace the readable authority;
- stores no separate timestamp or block number.

Normal finalization requires all intended batches and events to be reconciled, no unresolved incident, at least 24 hours after the final normal batch, independent review of the final reconciliation, and project-owner approval of the transaction.

Finalization below the cap is technically valid only for a documented recipient removal, operational stop, incident response, or campaign termination.

Immediate finalization may be used during a credible authority compromise, manifest misuse, unexpected issuance, incorrect transaction preparation, or another active incident. It stops future issuance but cannot reverse prior alerts.

## 10. Events and public reads

Every successful recipient issuance emits:

```solidity
event Transfer(address indexed from, address indexed to, uint256 value);
```

with:

```solidity
Transfer(address(0), recipient, 1)
```

Finalization emits:

```solidity
event DistributionFinalized(address indexed authority, uint256 finalSupply);
```

There is no duplicate per-recipient custom event and no on-chain batch identifier, manifest identifier, or manifest hash.

The public read surface is limited to fixed metadata, total supply, balance, zero allowance, immutable authority, immutable cap, finalized state, and the frozen maximum batch size.

## 11. Off-chain responsibilities

The contract does not determine recipient eligibility.

The operations pipeline owns:

- REP source scope and holder discovery;
- snapshot block and historical-state verification;
- migration-status definitions;
- balance thresholds and exclusions;
- deterministic address validation, deduplication, and canonical ordering;
- recipient manifests, reason codes, checksums, and batches;
- unsigned transaction preparation and simulation;
- transaction, event, balance, supply, and cap reconciliation;
- rollout, stop conditions, and incident records.

All on-chain integers use exact integer handling. Off-chain token balances use `bigint`, never floating-point arithmetic.

## 12. Security invariants

### 12.1 Balance and supply

- No address has a balance greater than one.
- The zero address never has a balance.
- A recipient balance cannot move or burn.
- Duplicate issuance cannot increase balance or supply.
- Total supply equals unique successful recipients.
- Total supply never exceeds the immutable cap.
- Failed calls leave state unchanged.

### 12.2 Authority and finalization

- Only the immutable authority distributes or finalizes.
- Deployment alone grants no privilege.
- No hidden deployer permission exists.
- No secondary administrator or authority-transfer path exists.
- Authority loss does not create another administrator.
- Finalization cannot be reversed or bypassed.
- Authority compromise cannot bypass the immutable cap.

### 12.3 Value and execution safety

- Transfers and approvals always fail.
- Allowance is always zero.
- Permit, burn, callbacks, hooks, and allowance helpers are absent.
- No REP, migration-contract, arbitrary-call, ETH-send, withdrawal, proxy, upgrade, or delegatecall capability exists.

### 12.4 Operational integrity

- Recipient artifacts are deterministic and cryptographically checksummed.
- Every exclusion has an explicit reason.
- The final manifest count equals the immutable cap.
- Decoded calldata and events reconcile with approved manifests.

## 13. Frozen acceptance criteria

### 13.1 Metadata

The candidate must demonstrate:

- exact name `REP MIGRATION ALERT`;
- exact symbol `CHECKREP`;
- decimals `0`;
- fixed compile-time metadata;
- zero initial supply;
- no constructor-configurable metadata.

### 13.2 Construction, authority, and deployment

The candidate must demonstrate:

- rejection of a zero authority;
- one immutable authority;
- the selected dedicated EOA can be supplied as authority;
- the same EOA may deploy the contract;
- deployment alone grants no authority;
- an unrelated deployer receives no implicit privilege;
- no hidden deployer permission;
- no owner, pending owner, role, secondary administrator, recovery administrator, or successor;
- no authority transfer, acceptance, renunciation, replacement, or handoff;
- only the authority distributes;
- only the authority finalizes;
- authority remains readable but powerless after finalization;
- EOA compromise cannot bypass the cap;
- key loss creates no recovery administrator.

Tests must not inspect or require the actual private key.

### 13.3 Cap and initial state

The candidate must demonstrate:

- a nonzero immutable distribution cap;
- rejection of a zero cap;
- no constructor issuance or deployer inventory;
- an initially unfinalized state;
- exact cap-boundary success;
- atomic rejection above the cap;
- reaching the cap does not automatically finalize.

### 13.4 Distribution

The candidate must demonstrate:

- exactly one array-based issuance path;
- one-recipient and multi-recipient success;
- contract-address recipient success;
- empty-array rejection;
- zero-address rejection at every position;
- duplicate-within-array rejection;
- previously notified rejection;
- unauthorized-caller rejection;
- post-finalization rejection;
- maximum-batch boundary success and overflow rejection after the constant is frozen;
- repeated-submission rejection;
- one-unit balances and exact supply accounting;
- complete rollback of balance, supply, and events on failure.

### 13.5 Interface and finalization

The candidate must demonstrate:

- positive and zero-value transfer rejection;
- `transferFrom` and `approve` rejection;
- allowance always zero;
- absence of permit, allowance helpers, operator approvals, callbacks, and burns;
- authorized finalization;
- unauthorized and repeated-finalization rejection;
- permanent closure of issuance;
- preservation of balances and supply;
- valid below-cap finalization;
- accurate event fields and counts;
- no unfinalize, emergency mint, recovery distribution, or stored finalization timestamp.

### 13.6 Architecture

The candidate must demonstrate:

- standalone code with no prohibited inheritance;
- no unexpected callable surface;
- no REP or migration-contract interaction;
- no arbitrary external call, callback, hook, payable, receive, fallback, withdrawal, or recovery path;
- no proxy, upgrade, implementation indirection, or `delegatecall`;
- no logic that depends on ETH balance;
- no on-chain batch or manifest identifier.

### 13.7 Verification methods

Before the contract release gate advances:

- unit tests cover every approved behavior and boundary;
- fuzz tests cover recipients, unauthorized callers, batch composition, duplicate and zero placement, ordering, finalization timing, and supply properties;
- invariant tests exercise authorized and unauthorized sequences, invalid calls, movement and approval attempts, cap boundaries, and finalization;
- gas tests cover the required batch matrix and failure cases;
- formatting, compilation, contract-size, coverage, and static-analysis results are reviewed;
- compiler warnings and Slither findings are classified;
- creation and runtime bytecode are independently reproduced;
- at least one independent reviewer examines source, configuration, ABI, tests, gas results, bytecode, and static analysis.

These requirements do not constitute an audit or prove absence of vulnerabilities.

## 14. Deferred parameters

| Parameter | Decision rule | Resolution phase |
| --- | --- | --- |
| Production EOA address | Use only the exact checksummed dedicated project-owner EOA reviewed for the intended chain; do not record secret material | Deployment preparation |
| EOA key-storage and operational evidence | Confirm dedicated use, hardware-backed signing status, backup and loss assumptions, no mainnet/Sepolia key reuse, limited ETH, unrelated-activity review, and manual transaction review | Sepolia rehearsal and mainnet preparation |
| REP contracts and universes | Include only explicitly approved sources verified from primary evidence | Recipient design |
| Snapshot block and hash | Select one reproducible historical state after required queries are independently reproduced | Recipient design |
| Migration definition, thresholds, and exclusions | Freeze deterministic, tested rules with explicit outcomes and reason codes | Recipient design |
| Final recipient manifest | Approve only the unique, validated, checksummed output of the frozen pipeline | Recipient freeze |
| Numeric distribution cap | Set exactly equal to the final manifest unique-address count; zero is invalid | Deployment preparation |
| Maximum batch size | Freeze the lower reviewed bound satisfying the 50% block-gas rule and stricter transaction constraints | Contract testing |
| Official canonical page URL | Approve only after the official page exists and contains verified address, chain, source link, safety wording, and migration information | Communications preparation |
| Canary recipients and stop conditions | Freeze only after manifest, gas, simulation, reconciliation, and incident procedures are reviewed | Mainnet preparation |
| Deployment commit and bytecode hashes | Freeze only byte-for-byte reproduced reviewed artifacts | Candidate freeze |

Do not invent evidence-dependent values.

## 15. Change control

The contract architecture and acceptance criteria are approved for implementation. This revision does not authorize RPC access, wallet or key handling, deployment, signing, transaction submission, or broadcast.

Any change to metadata, authority, cap derivation, distribution semantics, movement, approvals, burn, finalization, events, external interactions, upgradeability, or public meaning requires a specification revision before implementation.
