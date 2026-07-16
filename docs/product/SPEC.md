# REP Migration Notice Contract Product Specification

## Document status

Status: Approved for implementation planning

Approval date: 2026-07-16

Approval basis:

> The repository maintainer has explicitly authorized the resolution and approval of the product and architecture decisions defined in this task.

This approval resolves the product and contract architecture. It does not approve recipient data, a production authority address, implementation code, deployment, signing, or broadcast. It does not claim an audit, absence of vulnerabilities, production readiness, or wallet visibility.

Decision labels used throughout:

- **CONFIRMED** — approved product behavior, architecture, policy, or acceptance constraint.
- **DEFERRED WITH GATE** — a value that depends on later evidence, measurements, recipient data, or deployment configuration and has a deterministic resolution gate.
- **OUT OF SCOPE** — deliberately excluded behavior.

No other status label or bare placeholder is valid for a current decision.

## 1. Document control

| Field | Value |
| --- | --- |
| Title | REP Migration Notice Contract Product Specification |
| Status | Approved for implementation planning |
| Approval date | 2026-07-16 |
| Current milestone | Product specification complete; threat model and acceptance criteria in progress |
| Intended audience | Maintainers, implementers, independent reviewers, operations/data maintainers, deployment operators, and communications maintainers |
| Relationship to `AGENTS.md` | [`AGENTS.md`](../../AGENTS.md) remains the standing agent and security policy. Contract behavior must not be reinterpreted without an explicit specification revision. |
| Relationship to threat model | The design-stage [threat model](../security/THREAT_MODEL.md) must be approved and the acceptance criteria frozen before implementation begins. |
| Relationship to architecture record | The compact [architecture decision record](../architecture/DECISION_RECORD.md) records rationale, rejected alternatives, trade-offs, and verification gates. |
| Relationship to communications | The approved core message and publication rules are in [NOTICE_MESSAGING.md](../communications/NOTICE_MESSAGING.md). |

No approver name, organization, contract address, Safe address, signer identity, recipient count, snapshot block, or deployment date is asserted by this document.

## 2. Purpose

**CONFIRMED:** The contract is a minimal, non-economic, on-chain communication artifact intended to test whether selected REP-holder addresses can be made more aware of official REP migration information.

It tests a communications hypothesis. Wallets and other interfaces may hide the notice, classify it as spam, truncate it, attach misleading metadata, or fail to display it. Visibility and awareness must be measured empirically and must never be promised.

## 3. Meaning of receipt

**CONFIRMED:** Receiving one unit means only:

> The address was included in a reviewed recipient set for an Augur REP migration-awareness campaign, and the notice authority successfully issued one notice to that address.

Receipt does not prove:

- current REP ownership;
- legal or beneficial ownership of the address;
- current migration eligibility;
- incomplete migration;
- successful migration;
- failed migration;
- entitlement to REP or another asset;
- that a human controls the address;
- that the recipient saw or understood the notice.

No recipient interaction is required.

## 4. Confirmed non-goals

The notice is **OUT OF SCOPE** as:

- REP;
- migrated REP;
- replacement REP;
- a claim token;
- a reward;
- a redemption instrument;
- a governance asset;
- a staking asset;
- a tradable asset;
- a speculative asset;
- a migration mechanism;
- a wallet-connect mechanism;
- a general-purpose airdrop platform.

It grants no economic value, right, entitlement, governance power, migration capability, or claim.

The project does not support liquidity, pricing, transfer taxes, rebasing, staking, vesting, bridges, oracles, claims, callbacks, arbitrary multicalls, upgradeability, or generalized token extensibility.

## 5. Scope separation

### 5.1 On-chain responsibility

The contract is responsible only for:

- **CONFIRMED:** fixed notice metadata and an ERC-20-shaped compatibility ABI;
- **CONFIRMED:** binary balances and supply accounting;
- **CONFIRMED:** one atomic authorized distribution operation;
- **CONFIRMED:** duplicate prevention;
- **CONFIRMED:** an exact immutable issuance cap;
- **CONFIRMED:** disabled movement, approvals, permit, and burn;
- **CONFIRMED:** irreversible finalization;
- **CONFIRMED:** standard issuance events and one finalization event;
- **CONFIRMED:** the minimum public read surface needed for verification.

### 5.2 Off-chain responsibility

The operations pipeline owns:

- **DEFERRED WITH GATE:** REP source scope and holder discovery;
- **DEFERRED WITH GATE:** snapshot selection and verification;
- **DEFERRED WITH GATE:** migration-status evaluation;
- **DEFERRED WITH GATE:** thresholds and evidence-backed exclusions;
- **DEFERRED WITH GATE:** recipient manifests, ordering, checksums, and batches;
- **DEFERRED WITH GATE:** transaction preparation and reconciliation;
- **DEFERRED WITH GATE:** rollout, stop conditions, and campaign measurement.

The contract must not determine recipient eligibility on-chain.

## 6. Token metadata

| Property | Status | Approved value |
| --- | --- | --- |
| Name | **CONFIRMED** | `Augur REP Migration Notice` |
| Symbol | **CONFIRMED** | `REPNOTICE` |
| Decimals | **CONFIRMED** | `0` |
| Unit per recipient | **CONFIRMED** | `1` |
| Initial supply | **CONFIRMED** | `0` |

### 6.1 Name rationale

`Augur REP Migration Notice`:

- identifies Augur and REP;
- clearly uses the word “Notice”;
- does not imply replacement REP;
- does not imply migrated REP;
- does not imply a claim or reward;
- remains reasonably understandable when truncated;
- communicates the artifact’s purpose better than a short token-like brand.

### 6.2 Symbol rationale

`REPNOTICE`:

- is descriptive rather than financial;
- avoids `MREP`, `REP2`, `NEWREP`, and similar replacement-token interpretations;
- does not imply a new REP denomination;
- is intentionally less suitable for speculative presentation than a short ticker.

### 6.3 Fixed implementation

**CONFIRMED:** Name, symbol, and decimals are fixed contract behavior. The implementation must hardcode or compile them into the candidate and must not accept arbitrary constructor metadata.

This reduces deployment misconfiguration and ensures reviewed bytecode corresponds to reviewed metadata.

### 6.4 Canonical identity

**CONFIRMED:**

> The deployed contract address, verified through official Augur surfaces, is the only canonical on-chain identity.

Names, symbols, interfaces, logos, copied source code, price displays, and liquidity do not prove authenticity.

## 7. ERC-20-shaped interface boundary

**CONFIRMED:** The notice exposes an ERC-20-shaped ABI for wallet, explorer, indexer, and tooling recognition. It intentionally does not claim full ERC-20 behavioral compliance.

| Function | Approved behavior |
| --- | --- |
| `name()` | Return `Augur REP Migration Notice` |
| `symbol()` | Return `REPNOTICE` |
| `decimals()` | Return `0` |
| `totalSupply()` | Return unique successfully issued notice units |
| `balanceOf(address)` | Return `0` or `1` |
| `allowance(address,address)` | Always return `0` |
| `transfer(address,uint256)` | Always revert, including zero-value calls |
| `transferFrom(address,address,uint256)` | Always revert |
| `approve(address,uint256)` | Always revert |
| `permit(...)` | Absent |
| Allowance-changing helpers | Absent |
| Burn functions | Absent |

The interface is intentionally ERC-20-shaped rather than fully compliant:

- familiar selectors may improve recognition but do not guarantee display;
- some tools may misleadingly assume transferability;
- Sepolia testing must measure actual behavior;
- the project must not describe the contract simply as “an ERC-20 token” without explaining its disabled behavior.

## 8. Implementation architecture

**CONFIRMED:** The future implementation must be a standalone minimal contract with explicit state, functions, errors, and events.

It must not inherit from:

- OpenZeppelin `ERC20`;
- `Ownable`;
- `Ownable2Step`;
- `AccessControl`;
- `Pausable`;
- upgradeable contracts;
- proxy contracts;
- generalized token frameworks.

Rationale:

- the contract deliberately differs from normal ERC-20 behavior;
- no allowance storage is required;
- no ownership-transfer machinery is required;
- no inherited movement path should exist;
- explicit behavior is easier to review;
- the state and callable surface are very small;
- wallet recognition depends on ABI and events, not Solidity inheritance.

OpenZeppelin may remain pinned temporarily. Its presence does not imply usage.

**DEFERRED WITH GATE:** If the approved implementation imports no OpenZeppelin code, the dependency must be removed in a separate reviewed `chore(deps)` commit after implementation review confirms it is unused. This cleanup blocks the candidate dependency freeze, not implementation start.

## 9. Supply and balance semantics

**CONFIRMED:**

- initial supply is zero;
- the constructor issues no notice units;
- the deployer receives no notice inventory;
- each successful recipient receives exactly one unit;
- no address may ever hold more than one unit;
- balances are always zero or one;
- total supply equals the number of unique successful recipients;
- failed calls change no balance or supply;
- balances remain after finalization;
- transfers cannot alter balances;
- burns cannot alter balances;
- duplicate issuance cannot alter balances or supply.

The invariant:

```text
balanceOf(address) == 1
```

means the authority directly issued one notice to that address.

No separate `wasNotified(address)` mapping or view is approved.

## 10. Distribution operation

**CONFIRMED:** There is one conceptual privileged function:

```text
distribute(address[] recipients)
```

It supports a one-address canary and multi-address batches through one authorization path, validation path, event path, cap check, finalization check, and atomicity policy.

Separate single-recipient and batch-recipient entry points are rejected.

The exact Solidity syntax may be finalized during implementation, but the approved behavior may not change.

## 11. Recipient validation

| Condition | Approved result |
| --- | --- |
| Empty recipient array | Revert |
| Zero-address recipient | Revert entire call |
| Duplicate within submitted array | Revert entire call |
| Previously notified address | Revert entire call |
| Unauthorized caller | Revert |
| Distribution after finalization | Revert |
| Batch above approved maximum | Revert |
| Distribution above issuance cap | Revert |
| Valid contract address | Technically accepted on-chain |

The contract does not distinguish EOAs, smart-contract wallets, exchanges, protocols, custody addresses, or counterfactual accounts. Those classifications belong to the off-chain recipient pipeline.

`extcodesize` or equivalent account-type filtering is not an approved contract rule.

## 12. Atomic batch behavior

**CONFIRMED:** Distribution is all-or-nothing.

If any recipient is invalid:

- no recipient in the submitted call receives a notice;
- no balance persists;
- total supply does not change;
- no issuance event persists;
- the complete transaction reverts.

Silent skipping, partial success, best-effort batches, idempotent duplicate handling, and successful empty operations are rejected.

Strict atomicity intentionally shifts responsibility to deterministic off-chain validation.

## 13. Immutable authority and deployer separation

**CONFIRMED:** The contract has one nonzero constructor-supplied immutable authority.

The authority:

- can distribute before finalization;
- can finalize;
- cannot be changed;
- cannot be transferred;
- cannot nominate a successor;
- cannot create another administrator;
- cannot regain power after finalization.

The design rejects:

- `Ownable`;
- `Ownable2Step`;
- ownership transfer or acceptance;
- ownership renunciation;
- pending ownership;
- role-based access control;
- separate minter and finalizer roles;
- recovery administrators;
- emergency authority replacement.

Accepted architectural trade-off:

> If the immutable authority is incorrect, compromised beyond recovery, or permanently unavailable, the candidate cannot repair authority in place. The candidate must be abandoned or redeployed.

This is accepted because the contract holds no REP or user funds and performs no migration. Failing closed is safer than adding mutable recovery power.

Deployer and authority are separate concepts:

```text
Deployer:
- submits the creation transaction;
- receives no implicit privilege.

Authority:
- is supplied in the constructor;
- distributes notices;
- finalizes;
- is immutable.
```

The deployer may equal the authority only when deliberately configured and documented. No post-deployment authority handoff exists.

## 14. Immutable issuance cap

**CONFIRMED:** The contract has an immutable `distributionCap`.

Every successful distribution must satisfy:

```text
totalSupply + recipients.length <= distributionCap
```

The cap derivation rule is approved:

> `distributionCap` must equal the exact number of unique addresses in the final approved production recipient manifest.

A discretionary margin, conservative upper bound, or unused issuance headroom is rejected.

Construction with `distributionCap == 0` must revert.

Accepted architectural trade-off:

> If the final approved recipient set changes after deployment, the existing deployment cannot increase its cap. A materially changed recipient set requires abandonment and redeployment.

Reaching the cap does not automatically finalize distribution. Explicit human-approved finalization remains required.

Finalization below the cap is technically valid only in documented exceptional cases, including approved recipient removals, an operational stop, incident response, or campaign termination. A below-cap finalization requires a written reconciliation explanation.

## 15. Maximum batch-size gate

The exact maximum batch size is **DEFERRED WITH GATE** because it depends on candidate bytecode, execution gas, calldata, target-chain conditions, tooling, and Safe simulation.

The decision rule is:

1. Implement the candidate distribution logic.
2. Measure worst-case gas for entirely new recipients.
3. Include calldata cost.
4. Test one-address, typical, maximum, duplicate, cap-boundary, and revert scenarios.
5. Measure against the approved target-chain block gas limit at the pinned test block.
6. Choose a compile-time maximum whose worst-case successful call uses no more than 50% of that block gas limit.
7. Use the lower safe bound if calldata, execution, tooling, or Safe simulation imposes a stricter limit.
8. Record the benchmark, block conditions, chosen constant, and safety margin.
9. Require independent review before freezing the number.

The contract must enforce the frozen maximum. The exact number blocks the implementation-candidate freeze, not specification approval.

## 16. Movement, approvals, permit, and burn

### 16.1 Movement

**CONFIRMED:**

- `transfer` always reverts;
- zero-value `transfer` also reverts;
- `transferFrom` always reverts;
- no externally reachable internal movement path exists.

### 16.2 Approvals

**CONFIRMED:**

- `approve` always reverts;
- `allowance` always returns zero;
- increase/decrease allowance helpers are absent;
- operator approvals are absent;
- approval callbacks are absent.

### 16.3 Permit

**OUT OF SCOPE:**

- permit functions;
- signature-based spending permission;
- permit nonces;
- permit domain separators.

### 16.4 Burn

**OUT OF SCOPE:**

- holder burn;
- authority burn;
- `burnFrom`;
- burn-to-remove workflows.

Users should hide the notice through wallet UI rather than interact with the contract.

## 17. Finalization

**CONFIRMED:**

- only the immutable authority can finalize;
- finalization is explicit;
- finalization is one-time;
- repeated finalization reverts;
- finalization is irreversible;
- distribution permanently fails afterward;
- no unfinalize function exists;
- no emergency mint or recovery distribution exists;
- no upgrade path can reopen issuance;
- existing balances remain;
- authority remains publicly readable;
- authority has no effective power after finalization;
- no separate finalization timestamp or block number is stored.

Timing is derived from the finalization transaction, block number, block timestamp, and event.

### 17.1 Normal finalization gate

Normal finalization requires:

1. every intended batch submitted;
2. every transaction confirmed;
3. every issuance event reconciled;
4. every balance and cumulative supply reconciled;
5. cumulative supply matched to the approved manifest count unless an approved exception exists;
6. no unresolved incident;
7. at least 24 hours of observation after the final normal batch;
8. independent review of the final reconciliation;
9. controller approval of the finalization transaction.

### 17.2 Emergency finalization

Immediate emergency finalization is approved when there is credible evidence of:

- controller compromise;
- manifest misuse;
- unexpected issuance;
- an active operational incident;
- incorrect transaction preparation;
- a need to stop all further distribution.

Emergency finalization does not reverse previous notices. It only stops further issuance.

## 18. Events

**CONFIRMED:** The standard event is:

```solidity
event Transfer(
    address indexed from,
    address indexed to,
    uint256 value
);
```

Every successful issuance emits:

```solidity
Transfer(address(0), recipient, 1)
```

No ordinary transfer event can occur because movement is disabled. A duplicate custom per-recipient `NoticeDistributed` event is rejected.

**CONFIRMED:** One custom finalization event has these fields and semantics:

```solidity
event DistributionFinalized(
    address indexed authority,
    uint256 finalSupply
);
```

The exact syntax may be finalized during implementation without changing these fields or semantics.

An on-chain batch identifier, manifest identifier, manifest hash, or arbitrary operator-supplied checksum is rejected for the first version.

The operations pipeline must instead retain numbered batch manifests, deterministic recipient ordering, recipient-array checksums, transaction hashes, decoded-calldata verification, and event reconciliation.

## 19. Public reads and failure surface

The minimum public read surface is **CONFIRMED**:

- name;
- symbol;
- decimals;
- total supply;
- balance of address;
- allowance;
- immutable authority;
- finalized state;
- immutable distribution cap;
- maximum batch size after it is frozen.

Rejected reads include:

- `wasNotified`;
- owner or pending owner;
- role enumerators;
- arbitrary metadata URI;
- recovery state;
- pause state;
- upgrade state.

Public functions must not exist only for tests or convenience.

Failures must be explicit and testable for unauthorized callers, invalid construction parameters, invalid recipients, duplicates, finalization state, batch limit, cap overflow, disabled movement, disabled approvals, and repeated finalization. Exact custom-error names and parameter lists are implementation details, not product behavior.

## 20. External interaction policy

**CONFIRMED:**

- no REP query, transfer, approval, or custody;
- no migration-contract call;
- no arbitrary external call;
- no callback or hook;
- no oracle or bridge;
- no proxy or upgrade;
- no `delegatecall`;
- no token recovery helper;
- no payable function;
- no intended ETH receive function;
- no ETH withdrawal.

Precise ETH policy:

> The contract exposes no intended ETH-receive or withdrawal path, does not depend on its ETH balance, and treats any exceptionally forced ETH as inert and permanently unrecoverable.

Inert forced ETH being unrecoverable is an accepted architectural trade-off.

## 21. Production-controller policy

**CONFIRMED:** The mainnet authority must be one dedicated 2-of-3 Safe address.

The Safe policy requires:

- exactly three independently controlled signer addresses;
- threshold two;
- no agent-controlled signer or Safe operation;
- no enabled modules;
- no custom guard;
- a reviewed fallback handler appropriate to the frozen Safe version;
- independent signer control and storage;
- hardware-backed key storage strongly recommended;
- no signer-key reuse across unrelated systems;
- no shared custody or delegated signing;
- no unrelated DeFi activity from the Safe or signer addresses;
- no unrelated Safe assets beyond limited operational ETH;
- manual review before every signature;
- incident-level documented review for any custody or control change before finalization.

The Safe is the single immutable contract authority. The signer EOAs are not separate contract administrators.

Early Sepolia testing may use a dedicated test controller. The final Sepolia rehearsal must use the same dedicated 2-of-3 control model intended for mainnet. Test keys must not be reused on mainnet.

If a securely controlled, independently reviewed 2-of-3 Safe is unavailable, mainnet deployment must not proceed.

The exact Safe address, signer identities, Safe version, and frozen configuration are **DEFERRED WITH GATE**. No identity or address is invented here.

## 22. Independent review requirements

Before mainnet:

### 22.1 Contract review

At least one independent smart-contract reviewer who did not author the implementation must review:

- source;
- compiler configuration;
- dependencies;
- bytecode;
- disabled movement and approval paths;
- authority;
- cap;
- atomicity;
- finalization;
- tests;
- static-analysis results.

### 22.2 Recipient and operations review

At least one independent reviewer must review:

- recipient methodology;
- source inputs;
- snapshot;
- exclusions;
- cap derivation;
- manifests;
- checksums;
- batch construction;
- calldata;
- reconciliation;
- finalization readiness.

### 22.3 Communications review

At least one reviewer other than the author of the final copy must verify:

- notice-only language;
- canonical address;
- official links;
- no approval, swap, claim, burn, bridge, transfer, or wallet-connect instruction;
- consistency across official surfaces.

These reviews are not a formal audit unless a formal audit is actually performed.

## 23. Wallet-display testing

Sepolia wallet-display testing is **CONFIRMED** and mandatory.

The minimum category-based matrix is:

- at least two browser wallets;
- at least two mobile wallets;
- at least one portfolio tracker;
- at least one block explorer;
- at least one interface with spam filtering;
- at least one interface supporting manual token import.

Testing must record:

- automatic visibility;
- manual import;
- name and symbol truncation;
- decimals and balance rendering;
- transfer and approval affordances;
- spam classification;
- price metadata;
- third-party links or descriptions;
- error presentation for attempted transfer or approval;
- behavior after finalization.

The exact product list is **DEFERRED WITH GATE** until immediately before the Sepolia phase, when current relevance can be assessed. The communications and testnet release gates block until the matrix and results are reviewed.

## 24. Communications requirements

The approved canonical wording, safety rules, and publication hierarchy are in [NOTICE_MESSAGING.md](../communications/NOTICE_MESSAGING.md).

**CONFIRMED:**

- use “notice” consistently;
- never call it migrated REP;
- never imply value or required interaction;
- never embed approval, claim, swap, transfer, bridge, burn, signature, or wallet-connect instructions;
- never treat metadata as authentication;
- warn that fraudulent copies may use identical metadata;
- warn that third-party price data or liquidity does not indicate legitimacy or value;
- instruct users to navigate independently to the official Augur website;
- publish the canonical address only after independent verification;
- do not place a migration URL in token metadata or contract storage.

The exact canonical page URL is **DEFERRED WITH GATE** until the page exists. It must be independently approved before public Sepolia communication and before any mainnet deployment.

## 25. Security invariants

### 25.1 Balance and supply

- **CONFIRMED:** No address has a balance greater than one.
- **CONFIRMED:** The zero address never has a balance.
- **CONFIRMED:** A recipient balance cannot move or burn.
- **CONFIRMED:** Duplicate issuance cannot increase balance or supply.
- **CONFIRMED:** Total supply equals unique successful recipients.
- **CONFIRMED:** Total supply never exceeds the immutable cap.
- **CONFIRMED:** Failed calls change no balance, supply, or persistent event.

### 25.2 Authority and finalization

- **CONFIRMED:** Only the immutable authority distributes or finalizes.
- **CONFIRMED:** The deployer has no implicit privilege.
- **CONFIRMED:** No secondary administrator exists.
- **CONFIRMED:** No authority-transfer or recovery path exists.
- **CONFIRMED:** Finalization cannot be reversed or bypassed.

### 25.3 Interface and value safety

- **CONFIRMED:** Transfers and approvals always fail.
- **CONFIRMED:** Allowance always returns zero.
- **CONFIRMED:** Permit, burn, allowance helpers, callbacks, and hooks are absent.
- **CONFIRMED:** No REP, migration-contract, ETH-withdrawal, external-call, proxy, upgrade, or delegatecall capability exists.

### 25.4 Operational integrity

- **CONFIRMED:** Recipient ordering and artifacts are deterministic.
- **CONFIRMED:** Every exclusion has an evidence-backed reason.
- **CONFIRMED:** Every production artifact is cryptographically checksummed.
- **CONFIRMED:** Decoded calldata and events must reconcile to approved manifests.
- **CONFIRMED:** The exact manifest count equals the immutable cap.

## 26. Acceptance-criteria handoff

**CONFIRMED:** Unit, fuzz, invariant, gas, coverage, static-analysis, independent-review, and empirical wallet tests are mandatory.

Phase 3 must freeze the detailed acceptance criteria against this approved behavior before Phase 4 starts. That freeze may add test detail but may not reinterpret the architecture.

## 27. Deferred-with-gate register

| Parameter | Why it cannot responsibly be selected now | Owner role | Required evidence | Exact decision rule | Resolution phase | Gate blocked |
| --- | --- | --- | --- | --- | --- | --- |
| Exact REP contracts, versions, and universes | Requires approved campaign scope and primary-source verification | Operations/data maintainer | Checksummed addresses, chain evidence, version rationale, independent review | Include only explicitly approved REP sources whose identity and historical query behavior are verified | Snapshot/recipient design | Gate C: Data |
| Snapshot block and hash | Must correspond to approved campaign timing and available reproducible historical state | Repository maintainer with operations/data maintainer | Chain ID, block number/hash/timestamp, archive-state availability, independent reproduction | Select one immutable block only after required historical queries reproduce from reviewed sources | Snapshot/recipient design | Gate C: Data |
| Holder discovery and migration definition | Depends on approved REP scope and migration semantics | Operations/data maintainer | Method specification, fixtures, edge cases, independent review | Freeze only a deterministic method that classifies every input with an explicit outcome and fails closed on missing state | Snapshot/recipient design | Gate C: Data |
| Thresholds and exclusions | Depend on campaign policy and evidence for affected addresses | Repository maintainer with operations/data maintainer | Raw balances, integer threshold math, reason codes, evidence, affected-address reports | Approve only deterministic rules with tests, counts, and a reviewable reason for every exclusion | Snapshot/recipient design | Gate C: Data |
| Exact recipient manifest | Cannot exist before approved inputs and filters run | Operations/data maintainer | Deterministic JSON/CSV, canonical ordering, reasons, checksums, independent reproduction | Approve only the unique, validated, reproducible final output of the frozen pipeline | Recipient freeze | Gate C: Data |
| Exact numeric distribution cap | Equals a later data artifact rather than an architectural estimate | Repository maintainer | Final approved manifest and unique-address count | Set `distributionCap` exactly equal to the final manifest's unique address count; zero is invalid | Candidate deployment preparation | Gate E: Mainnet preparation |
| Exact maximum batch size | Depends on candidate gas, calldata, chain, tooling, and Safe simulation | Contract implementer with independent contract reviewer | Required benchmark matrix, pinned block gas limit, calldata measurements, Safe simulation | Freeze the lower safe bound whose worst-case success uses at most 50% of block gas and satisfies stricter tooling limits | Contract testing/fork simulation | Implementation-candidate freeze |
| Exact Safe address | Must be derived from reviewed deployment configuration, not prose | Deployment operator | Chain, Safe address, version, code, owners, threshold, configuration, simulation, independent review | Accept only the dedicated Safe proven to have exactly three approved independent signers, threshold two, no modules, no custom guard, and reviewed fallback handler | Final Sepolia/mainnet preparation | Gate D and Gate E |
| Safe signer identities and custody evidence | Individuals and custody must be verified privately and operationally | Repository maintainer and deployment operator | Three independent controls, storage and backup evidence, incident procedure, no key reuse | Proceed only when three independent signers and two-signature availability are verified without exposing secrets | Final Sepolia/mainnet preparation | Gate D and Gate E |
| Safe version and fallback handler | Current supported deployment details may change | Deployment operator with independent contract reviewer | Versioned Safe source/code evidence, handler purpose, compatibility review | Freeze only a reviewed supported version and handler with no unexplained capability | Final Sepolia rehearsal | Gate D: Testnet |
| Exact wallet product matrix | Interface relevance changes over time | Communications maintainer | Current usage/relevance rationale and category coverage | Choose current products immediately before testing while meeting every category minimum | Sepolia testing | Gate D: Testnet |
| Canonical official page URL | The page does not yet exist | Communications maintainer | Published official page, independent content/address review, change-control owner | Approve the exact HTTPS URL only after the page contains all required safety and verification material | Communications preparation | Gate D public communication and Gate E |
| Canary size, batch sequence, and stop conditions | Depend on final recipients, gas, budget, and rehearsals | Repository maintainer with deployment operator | Rehearsal results, gas report, budget, incident procedure, reconciliation plan | Approve a written sequence only after every batch is simulatable and each stop condition has an owner and observable trigger | Mainnet preparation | Gate E: Mainnet preparation |
| Exact deployment commit and bytecode | Do not exist before implementation and review freeze | Repository maintainer with independent contract reviewer | Tagged commit, reproducible creation/runtime hashes, compiler/dependency record, second-environment build | Freeze only byte-for-byte reproduced reviewed artifacts with no unresolved findings | Candidate freeze | Gate E: Mainnet preparation |

## 28. Explicitly rejected decisions

The first version rejects:

- a transferable or fully ERC-20-compliant token;
- OpenZeppelin token or ownership inheritance;
- constructor-configurable metadata;
- separate single and batch distribution functions;
- partial-success or idempotent batch handling;
- a discretionary issuance-cap margin;
- zero-cap construction;
- automatic finalization at the cap;
- mutable authority or authority recovery;
- a single EOA or 1-of-1 Safe as mainnet authority;
- separate minter and finalizer roles;
- movement, approvals, permit, or burn;
- custom per-recipient notice events;
- on-chain batch or manifest hashes;
- finalization timestamp storage;
- external calls, recovery helpers, proxies, upgrades, or `delegatecall`;
- token metadata or storage containing a migration URL.

## 29. Approval

The product model and contract architecture are approved as of 2026-07-16.

Approval covers:

- notice-only purpose and meaning;
- metadata;
- ERC-20-shaped interface boundary;
- standalone implementation constraint;
- supply and binary balances;
- one atomic array distribution operation;
- immutable authority and deployer separation;
- exact manifest-derived immutable cap;
- maximum-batch decision rule;
- disabled movement, approvals, permit, and burn;
- finalization and events;
- public reads;
- external-interaction exclusions;
- dedicated 2-of-3 Safe policy;
- independent review and wallet-testing requirements;
- communications rules;
- deterministic deferred gates.

Implementation may begin only after the design-stage threat model is approved and the acceptance criteria are frozen. This specification revision does not authorize code, RPC access, wallet operations, deployment, signing, or broadcast.
