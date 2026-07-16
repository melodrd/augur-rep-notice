# REP Migration Notice Contract Product Specification

## Document status

Status: Draft — maintainer approval required

This document contains a combination of confirmed project constraints, conservative proposed defaults, unresolved maintainer decisions, matters deferred to the off-chain operations pipeline, and explicit non-goals. No production implementation should begin until the required contract-level decisions are approved.

Status labels used throughout:

- **CONFIRMED** — established project constraint that this draft does not reopen.
- **PROPOSED** — recommended default that still requires maintainer approval.
- **UNRESOLVED** — decision requiring explicit maintainer direction.
- **DEFERRED** — necessary decision assigned to a later project phase.
- **OUT OF SCOPE** — behavior deliberately excluded from this contract and milestone.

## 1. Document control

| Field | Value |
| --- | --- |
| Title | REP Migration Notice Contract Product Specification |
| Status | Draft — maintainer approval required |
| Current milestone | Product specification |
| Intended audience | Augur maintainers, contract implementers, reviewers, security reviewers, and operations planners |
| Approval requirement | Explicit maintainer approval of the behavior, administrative model, invariants, and acceptance criteria |
| Last updated | 2026-07-16 |
| Relationship to `AGENTS.md` | [`AGENTS.md`](../../AGENTS.md) remains the standing agent and security policy. An approved specification would define product behavior within those constraints. |
| Relationship to threat model | The draft must be reviewed against [`docs/security/THREAT_MODEL.md`](../security/THREAT_MODEL.md) before implementation. |
| Relationship to operations | Recipient selection, snapshots, manifests, rollout controls, and reconciliation are separate off-chain responsibilities and are not implemented by the contract. |

No approver names are assigned in this draft. This document has not received independent security review.

## 2. Executive summary

The REP Migration Notice is being considered as a minimal on-chain communications artifact. An approved authority would distribute one non-economic notice unit to each address in a precomputed recipient set. Some wallet, explorer, or portfolio interfaces may then surface the notice and prompt the holder to seek official Augur migration information.

The notice is not REP, migrated REP, replacement REP, a claim, a reward, a governance asset, or a migration mechanism. It has no economic value and grants no rights. A recipient must not need to interact with it.

The experiment tests a communications hypothesis, not a token economy. The contract must remain minimal because every additional capability creates audit burden, operational complexity, integration ambiguity, and scam surface without improving the notice's core purpose.

## 3. Problem statement

Some REP holders may need to learn about a migration process but may not follow Augur's public channels. An unsolicited on-chain notice might become visible in some interfaces used by those holders.

This visibility is an empirical hypothesis:

- Wallets may hide unsolicited assets.
- Interfaces may classify the notice as spam.
- Wallets may truncate the name or symbol.
- Third-party interfaces may attach incorrect metadata or pricing.
- The mechanism may fail to reach some or all intended holders.
- Scammers can deploy copies with identical names and symbols.

The notice must never be presented as a guaranteed communications channel. The deployed contract address, published through official Augur surfaces, is the only canonical on-chain identifier. Matching metadata is not proof of authenticity.

## 4. Product objective

**CONFIRMED:** The objective is to test whether a minimal, non-economic, on-chain notice can improve migration awareness among addresses selected by an Augur-maintained off-chain process.

The contract must not become:

- **OUT OF SCOPE:** a replacement REP token;
- **OUT OF SCOPE:** migrated REP;
- **OUT OF SCOPE:** a claim token;
- **OUT OF SCOPE:** a redemption instrument;
- **OUT OF SCOPE:** a reward;
- **OUT OF SCOPE:** a governance token;
- **OUT OF SCOPE:** a tradable or speculative asset;
- **OUT OF SCOPE:** a migration mechanism;
- **OUT OF SCOPE:** a wallet-connect or signature-request mechanism.

Success must be evaluated as a communications experiment. Deployment, token visibility, and receipt do not by themselves demonstrate that awareness improved.

## 5. User-facing meaning

**PROPOSED meaning:**

> The address was included in an Augur-maintained recipient set for a REP migration-awareness campaign. The notice itself has no economic value and does not perform migration.

Receipt records only that the distribution authority successfully issued a notice to the address. It does not prove:

- current migration eligibility;
- current REP ownership;
- incomplete migration;
- legal or beneficial ownership of the address;
- entitlement to REP or another asset;
- successful migration;
- unsuccessful migration;
- that the address is controlled by a human;
- that the recipient saw or understood the notice.

**DEFERRED:** The recipient set is an off-chain operational decision made before distribution. Eligibility evidence, snapshot semantics, exclusions, and campaign measurement belong to the operations pipeline.

## 6. Scope separation

### On-chain contract

The contract is responsible only for:

- **PROPOSED:** representing notice receipt through an ERC-20-shaped metadata, balance, supply, transfer, approval, and allowance interface used for compatibility experiments;
- **PROPOSED:** preventing duplicate notice issuance;
- **CONFIRMED:** enforcing distribution and finalization authorization;
- **CONFIRMED:** preventing transfer and approval behavior;
- **CONFIRMED:** permanently ending distribution through irreversible finalization;
- **PROPOSED:** enforcing an immutable upper bound on total notice issuance;
- **PROPOSED:** emitting events sufficient for reconciliation;
- **PROPOSED:** exposing the smallest useful public read surface.

### Off-chain operations pipeline

The later operations pipeline is responsible for:

- **DEFERRED:** REP holder discovery;
- **DEFERRED:** snapshot selection and verification;
- **DEFERRED:** migration-status evaluation;
- **DEFERRED:** balance thresholds;
- **DEFERRED:** exchange, protocol, custody, and burn-address classifications;
- **DEFERRED:** manual exclusions with evidence and approval;
- **DEFERRED:** recipient manifests and canonical ordering;
- **DEFERRED:** batch creation and checksums;
- **DEFERRED:** distribution reconciliation;
- **DEFERRED:** campaign effectiveness measurement.

**CONFIRMED:** The contract must not query REP balances, call REP contracts, call migration contracts, or determine eligibility on-chain.

## 7. Interface decision

### Proposed default

**PROPOSED:** The notice exposes an ERC-20-shaped metadata, balance, supply, transfer, approval, and allowance interface for wallet, explorer, and tooling recognition. It intentionally does not claim full ERC-20 behavioral compliance because token movement and approvals are disabled.

ERC-20 tooling commonly expects the selectors for `name`, `symbol`, `decimals`, `totalSupply`, `balanceOf`, `transfer`, `transferFrom`, `approve`, and `allowance`. The notice exposes the relevant selectors so the project can empirically test recognition by wallets, explorers, indexers, and common Ethereum tools.

This is a compatibility experiment, not a claim of strict ERC-20 behavior:

- movement and approval functions deliberately reject every use;
- zero-value transfers also reject;
- `allowance` always reports zero;
- permit and burn functions are absent;
- strict ERC-20 behavior ordinarily permits some calls that this notice intentionally rejects;
- familiar selectors do not guarantee wallet visibility or correct presentation;
- wallet display remains an empirical hypothesis requiring Sepolia and target-interface observation;
- metadata does not authenticate a deployment, and matching names or symbols are not proof of authenticity.

### Proposed read and interaction surface

| Function | Proposed behavior |
| --- | --- |
| `name()` | Return approved notice name |
| `symbol()` | Return approved notice symbol |
| `decimals()` | Return `0` |
| `totalSupply()` | Return successfully issued notice units |
| `balanceOf(address)` | Return `0` or `1` |
| `allowance(address,address)` | Always return `0` |
| `transfer(address,uint256)` | Revert for every invocation, including zero-value transfers |
| `transferFrom(address,address,uint256)` | Revert for every invocation |
| `approve(address,uint256)` | Revert for every invocation |
| `permit(...)` | Absent |
| Burn functions | Absent |

This interface choice remains **PROPOSED** until explicitly approved. Exact Solidity signatures beyond the conceptual standard selectors, implementation inheritance, library use, and override points remain **DEFERRED** until implementation design. The future implementation must be judged against the approved behavior rather than described broadly as fully ERC-20 compliant.

### Alternatives considered

| Alternative | Potential advantage | Principal disadvantage | Current disposition |
| --- | --- | --- | --- |
| Custom non-token contract | Small bespoke interface; no misleading transfer selectors | Less likely to appear in wallet token views | Not currently preferred; **UNRESOLVED** until ERC-20 choice is approved |
| ERC-721 notice | Unique-token semantics | NFT spam treatment, token IDs, metadata/URI complexity, unnecessary transfer surface | **OUT OF SCOPE** under the proposed design |
| ERC-1155 notice | Batch-oriented standard | More complex operator approval and multi-token semantics | **OUT OF SCOPE** under the proposed design |
| Event-only notification | Very small persistent state | Events are not normally surfaced as owned assets | Not currently preferred |
| Off-chain communication only | No contract risk | May not reach holders outside known channels | Remains a complementary option, not a contract behavior |

## 8. Token metadata

| Property | Status | Value or proposal | Rationale |
| --- | --- | --- | --- |
| Name | **UNRESOLVED** | — | Must communicate notice-only meaning without implying value or migration |
| Symbol | **UNRESOLVED** | — | Must avoid ticker confusion and misleading similarity to REP |
| Decimals | **PROPOSED** | `0` | One indivisible notice |
| Unit per recipient | **PROPOSED** | `1` | Clear binary ownership |
| Initial supply | **PROPOSED** | `0` | Notices issued only to approved recipients |
| Economic value | **CONFIRMED** | None | Communications artifact only |
| Canonical identity | **CONFIRMED** | Contract address | Names and symbols are copyable |

Naming constraints:

- The name must not imply migrated REP.
- The name must not imply claimable or redeemable value.
- The name must not imply that the notice is official replacement REP.
- The name and symbol should remain intelligible when truncated.
- The symbol should avoid confusing ticker similarity.
- Candidate metadata must be reviewed across target wallet and portfolio interfaces before approval.
- Metadata must not embed wording that tells a user to sign, approve, swap, transfer, burn, bridge, deposit, or claim.

Final name, symbol, descriptive wording, and communications presentation are **UNRESOLVED**.

## 9. Supply and balance semantics

Proposed defaults:

- **PROPOSED:** Initial total supply is zero.
- **PROPOSED:** Decimals are zero.
- **PROPOSED:** Each successful recipient receives exactly one unit.
- **PROPOSED:** No address may hold more than one unit.
- **PROPOSED:** Balances remain either zero or one.
- **PROPOSED:** Total supply equals the number of unique successfully notified addresses.
- **PROPOSED:** An already-notified address cannot receive another unit.
- **PROPOSED:** Failed distribution attempts do not change balances or supply.
- **PROPOSED:** Existing balances remain unchanged after finalization.
- **PROPOSED:** No supply is issued during construction.
- **PROPOSED:** The deployer never receives an inventory of notices.

These properties depend on transfers being impossible, approvals being unusable, burning being absent, and duplicate issuance being rejected. If balances could move, `balanceOf(address) == 1` would no longer mean that the address was directly notified. If burning were allowed, total supply would no longer equal the number of successful notices. If duplicate issuance were allowed, balances or supply could cease to represent unique successful recipients.

The final token name and symbol remain **UNRESOLVED**. This draft does not invent them.

## 10. Transfer behavior

| Function or path | Status | Proposed behavior |
| --- | --- | --- |
| `transfer` | **PROPOSED** | Revert for every invocation, including zero-value movement |
| `transferFrom` | **PROPOSED** | Revert for every invocation, including zero-value movement |
| Internal ordinary transfer | **PROPOSED** | Not exposed through any external path |
| Mint/distribution | **PROPOSED** | Restricted to the approved authority while distribution is active |
| Burn | **PROPOSED** | Absent |
| `burnFrom` | **OUT OF SCOPE** | Unsupported |
| Bridge movement | **OUT OF SCOPE** | Unsupported |
| Wrapping supplied by this project | **OUT OF SCOPE** | Unsupported |

**CONFIRMED:** Non-transferability must be enforced on-chain. Documentation, wallet UI, or frontend restrictions are insufficient.

The contract cannot prevent an unrelated third party from creating an external wrapper or derivative representation, but it must provide no native wrapping, bridging, transfer, approval, or callback support.

## 11. Approval behavior

| Function or feature | Status | Proposed behavior |
| --- | --- | --- |
| `approve` | **PROPOSED** | Revert for every invocation |
| `allowance` | **PROPOSED** | Always return zero |
| Allowance increase/decrease | **PROPOSED** | Absent |
| Permit | **OUT OF SCOPE** | Unsupported |
| Operator approvals | **OUT OF SCOPE** | Unsupported |
| Approval callbacks | **OUT OF SCOPE** | Unsupported |

Approvals should be disabled because:

- there is no legitimate spender use case;
- approval prompts may confuse recipients;
- approval and permit flows resemble common scam behavior;
- allowances create unnecessary integration and attack surface;
- spender authority would contradict the notice's user-facing meaning.

No allowance-changing helper, permit path, operator approval, or callback-based approval mechanism is proposed. Exact implementation inheritance remains **DEFERRED**, but no approval path may enable movement.

## 12. Burn behavior

**PROPOSED:** Burning is absent. There is no holder burn, authority burn, `burnFrom`, or burn-to-remove user flow.

Rationale:

- No user requirement for burning has been identified.
- Burning weakens historical balance visibility.
- Burning breaks the proposed equality between total supply and unique successful recipients.
- Users can hide unsolicited assets through wallet-interface controls without changing on-chain state.
- Burn functions expand the interface and test surface.
- Telling users to burn a notice could create dangerous behavioral expectations.

Users may hide the notice through wallet-interface controls instead. That preserves the direct-receipt record without teaching holders to interact with an unsolicited asset.

If burning were approved in a future specification revision, that revision would need to redefine:

- whether a burned address may be notified again;
- whether historical receipt requires a separate `wasNotified` mapping;
- how total supply reconciles with successful distribution events;
- whether burning is transferable movement to the zero address;
- how operations reports distinguish issued, held, and burned notices.

The proposed absence of burn behavior remains subject to maintainer approval.

## 13. Administrative model

The contract requires the minimum authority necessary to distribute notices and finalize distribution.

### Contract-level authority

**PROPOSED:** One immutable authority address.

The authority:

- is supplied explicitly during deployment;
- cannot be the zero address;
- may call `distribute` while distribution is active;
- may call `finalize`;
- cannot be changed or transferred;
- cannot nominate a successor;
- cannot create secondary administrators;
- cannot restore its powers after finalization.

The proposed design has no `Ownable`, `Ownable2Step`, `transferOwnership`, `acceptOwnership`, `renounceOwnership`, `setAuthority`, pending-authority state, role-based access control, or overlapping owner, minter, operator, or finalizer roles.

Rationale:

- removes authority-transfer and wrong-address handoff failure modes;
- removes pending-owner state and recovery-administrator ambiguity;
- avoids mutable contract-level governance;
- reduces bytecode, test, and review surface;
- fails closed if the authority becomes unavailable.

Trade-off:

- an incorrectly configured or permanently unavailable authority cannot be recovered in place;
- the candidate would need to be abandoned or redeployed;
- this is considered an acceptable proposed trade-off for a non-custodial communications artifact;
- authority correctness must therefore be independently verified before deployment.

The immutable-authority design remains **PROPOSED** pending approval. Exact Solidity implementation remains **DEFERRED**.

### Deployer and authority separation

The deployer and authority are separate concepts:

```text
Deployer:
- submits the deployment transaction;
- receives no persistent permission unless deliberately supplied as authority.

Authority:
- distributes notices;
- finalizes distribution;
- is immutable.
```

The constructor receives the intended authority address. The deployer does not need temporary administrative privilege, no post-deployment authority handoff is required, and deployment alone creates no hidden privilege.

### Production-controller policy

**PROPOSED operational requirement:**

> The production authority must be a dedicated, maintainer-approved address whose ownership, signer model, security assumptions, configuration, and incident procedures are documented and reviewed before deployment.

The current expected arrangement is:

- the project maintainer currently expects to operate the production authority;
- the authority should not be the maintainer's normal everyday wallet;
- the authority should not be a browser hot wallet used for unrelated activity;
- the preferred arrangement is a dedicated Safe;
- the Safe may initially be controlled by one dedicated signer;
- a one-owner, one-signature Safe must not be described as providing multisignature security;
- its initial benefits are address stability, transaction review, separation from daily activity, and future signer rotation;
- additional independent signers and a higher threshold should be evaluated before mainnet;
- the exact Safe address, owners, threshold, modules, guard, fallback handler, and recovery process remain **DEFERRED** operational decisions.

This draft does not claim organizational Augur control and does not invent other signers.

Using a Safe does not automatically eliminate operational risk. Future deployment review must verify the chain, Safe address, owners, threshold, signer independence, enabled modules, guard, fallback handler, signer key-storage method, recovery procedure, transaction simulation, dedicated-purpose status, and unrelated asset or protocol activity. These are **DEFERRED** operational requirements.

## 14. Distribution functions

**PROPOSED:** Expose one conceptual operation:

```text
distribute(address[] recipients)
```

The same operation supports one-address canaries and normal multi-address batches through one authorization path, validation path, event policy, and atomicity policy.

The minimum length is one. Empty arrays revert. The maximum length is **DEFERRED** until measured gas and calldata testing can support an approved limit with documented safety margin. This is a behavioral description, not an approved exact Solidity signature or implementation.

### Immutable issuance cap

**PROPOSED:** The contract has an immutable `distributionCap`.

Conceptually, distribution rejects an operation when:

```text
totalSupply + recipients.length > distributionCap
```

Rationale:

- places a hard upper bound on authority misuse;
- prevents unlimited spam issuance;
- makes the campaign's maximum scale inspectable;
- provides an additional reconciliation constraint;
- reduces damage if the authority is compromised.

Limitations:

- the cap does not prove recipient correctness;
- a compromised authority may still issue the capped supply to incorrect addresses;
- a cap that is too low may require a new deployment;
- the cap must not be guessed;
- the cap does not replace off-chain recipient validation.

The existence of an immutable issuance cap is **PROPOSED**. Its exact numeric value is **DEFERRED**. The derivation policy remains **UNRESOLVED**; the proposed source is an approved recipient manifest or approved conservative upper bound. Zero-cap validity is **UNRESOLVED**; if zero is not allowed, construction must reject it. Reaching the cap does not automatically finalize distribution. Explicit finalization remains required.

## 15. Recipient validation

| Condition | Status | Proposed result |
| --- | --- | --- |
| Zero address | **PROPOSED** | Revert |
| Already-notified recipient | **PROPOSED** | Revert |
| Duplicate inside one batch | **PROPOSED** | Revert the complete batch |
| Unauthorized caller | **CONFIRMED** | Revert |
| Distribution after finalization | **CONFIRMED** | Revert |
| Empty recipient array | **PROPOSED** | Revert |
| Batch above approved maximum | **PROPOSED** | Revert once a maximum is defined |
| Distribution above immutable cap | **PROPOSED** | Revert |
| Valid smart-contract address | **PROPOSED** | Technically permitted on-chain |

The contract should not attempt to distinguish EOAs from contracts. EOA/contract eligibility is **DEFERRED** to the off-chain pipeline because:

- `extcodesize`-style checks are incomplete;
- contracts under construction can appear to have no code;
- counterfactual and delegated account models complicate classification;
- exchange, protocol, and custody classifications require evidence rather than a bytecode-only rule.

## 16. Atomicity and batch failure semantics

**PROPOSED:** All-or-nothing batch execution.

One invalid recipient causes the complete batch to revert.

Ethereum transaction atomicity ensures that any earlier balance, supply, or event-producing changes attempted within the same failed call are rolled back. No state or event from the reverted distribution persists.

Advantages:

- deterministic reconciliation;
- no silent skipping;
- no ambiguous partial completion;
- easier Safe transaction review;
- easier reruns after a manifest is corrected;
- successful notice-event count matches manifest count;
- supply increase equals batch recipient count.

Trade-off:

- one malformed, zero, duplicate, previously notified, or otherwise invalid recipient blocks the whole batch.

The off-chain pipeline must therefore validate manifests before transaction construction. There is no silent skipping, partial success, best-effort behavior, or idempotent duplicate handling.

## 17. Duplicate semantics

### Duplicate inside one batch

**PROPOSED:** Revert the entire batch.

### Previously notified address in a later batch

**PROPOSED:** Revert the entire later batch.

### Repeated transaction submission

**PROPOSED:** A second submission reverts because its recipients are already notified.

### Off-chain prevention

**DEFERRED:** The operations pipeline must reject duplicates before constructing transactions and must reconcile submitted batches before proceeding.

Silent idempotent skipping is not currently preferred because it can conceal incorrect manifests, cause event counts to diverge from recipient counts, complicate Safe review, and make repeated or partially duplicated submissions harder to diagnose.

## 18. Finalization

Proposed behavior:

- **CONFIRMED:** Only the approved authority can finalize.
- **PROPOSED:** Finalization is a distinct explicit operation.
- **PROPOSED:** Finalization is one-time and repeated calls revert.
- **PROPOSED:** Successful finalization emits an event.
- **CONFIRMED:** Finalization is irreversible.
- **CONFIRMED:** Every distribution and mint path is permanently disabled afterward.
- **CONFIRMED:** Existing balances remain.
- **CONFIRMED:** Transfers and approvals remain disabled.
- **CONFIRMED:** No emergency unfinalize function exists.
- **CONFIRMED:** No upgrade mechanism can bypass finalization.
- **PROPOSED:** Finalization below the immutable cap is valid.
- **PROPOSED:** No separate finalization timestamp or block number is stored.
- **PROPOSED:** Event block and transaction metadata provide timing information.

Because authority is immutable, there is no authority transfer, clearing, ownership renunciation, or later authority change to resolve after finalization. The authority address remains publicly readable as an audit record, but after finalization it has no effective contract power. Finalization, not ownership renunciation, permanently disables privileged behavior.

## 19. External interaction policy

| Capability | Status | Requirement |
| --- | --- | --- |
| Payable functions | **CONFIRMED** | None |
| Intended ETH receipt | **CONFIRMED** | None |
| ETH withdrawal | **CONFIRMED** | None |
| ERC-20 recovery helper | **CONFIRMED** | None |
| REP transfer | **CONFIRMED** | None |
| REP approval | **CONFIRMED** | None |
| Migration-contract call | **CONFIRMED** | None |
| Arbitrary external call | **CONFIRMED** | None |
| `delegatecall` | **CONFIRMED** | None |
| Callback support | **OUT OF SCOPE** | None |
| ERC-1363 | **OUT OF SCOPE** | Unsupported |
| ERC-777 hooks | **OUT OF SCOPE** | Unsupported |
| Oracle dependency | **OUT OF SCOPE** | None |
| Bridge | **OUT OF SCOPE** | None |
| Proxy | **CONFIRMED** | None |
| Upgrade path | **CONFIRMED** | None |

The contract exposes no intended ETH-receive or withdrawal path and does not rely on its ETH balance. A specification should not claim that the address can never contain ETH: mechanisms outside intended interfaces may force ETH to an address under applicable EVM behavior. Any forced ETH must have no effect on contract logic and must remain unrecoverable unless this confirmed policy is explicitly changed before implementation.

## 20. Events

### Standard issuance event

**PROPOSED:** Every successful issuance emits the familiar mint-style event:

```solidity
Transfer(address(0), recipient, 1)
```

One event is emitted per successful recipient. This supports standard explorer and indexer behavior. Because ordinary movement is impossible, every persistent `Transfer` event is unambiguously an issuance event. Reverted distributions leave no persistent event record.

A duplicate custom per-recipient event is not proposed by default. It should be added only if a concrete indexing requirement justifies duplicated gas and event surface.

### Finalization event

**PROPOSED concept:**

```solidity
DistributionFinalized(
    address indexed authority,
    uint256 finalSupply
)
```

The semantic requirement is one successful finalization event identifying the immutable authority and accurate final supply. Exact Solidity syntax remains **DEFERRED** until implementation design.

A batch-level manifest hash or batch identifier remains **UNRESOLVED** and must not be added automatically.

## 21. Public read interface

Likely minimum read surface:

| Read | Status | Purpose |
| --- | --- | --- |
| Name | **PROPOSED** | Standard metadata |
| Symbol | **PROPOSED** | Standard metadata |
| Decimals | **PROPOSED** | Standard metadata; proposed value `0` |
| `balanceOf(address)` | **PROPOSED** | Determine whether the address currently holds its notice |
| Total supply | **PROPOSED** | Reconcile successful unique recipients |
| `allowance(owner, spender)` | **PROPOSED** | Always return zero |
| Immutable authority | **PROPOSED** | Verify the address permitted to distribute before finalization |
| Finalized state | **PROPOSED** | Verify whether distribution is permanently closed |
| Immutable distribution cap | **PROPOSED** | Verify the maximum possible total supply |

No separate `wasNotified(address)` view is proposed. While transfers and burns are disabled and balances remain binary, `balanceOf(address) == 1` is sufficient to determine current and historical direct notice receipt.

Public functions must not exist solely for test convenience.

## 22. Errors and failure reporting

**PROPOSED:** Use explicit failures rather than silent no-ops or silent skipping.

The implementation should distinguish these semantic conditions:

- unauthorized caller;
- zero recipient address;
- duplicate recipient within the submitted operation;
- already-notified recipient;
- distribution already finalized;
- empty recipient array;
- oversized batch;
- distribution cap exceeded;
- transfer disabled;
- approvals disabled;
- finalization already completed;
- invalid authority or distribution-cap construction parameter.

Exact custom-error names and parameter lists are **UNRESOLVED** implementation details. The approved semantics must remain testable and unambiguous.

## 23. Security invariants

These invariants are mandatory acceptance properties for any implementation of the approved design.

### Balance and supply invariants

- **PROPOSED:** Initial supply is zero.
- **PROPOSED:** Each successful recipient receives exactly one unit.
- **CONFIRMED:** No address holds more than one notice.
- **CONFIRMED:** The zero address never receives a notice.
- **PROPOSED:** Total supply equals unique successful recipients.
- **PROPOSED:** Total supply never exceeds the immutable distribution cap.
- **CONFIRMED:** Failed transactions do not alter balances or supply.
- **CONFIRMED:** Notice balances cannot move between addresses.
- **PROPOSED:** Notice balances cannot be burned.
- **CONFIRMED:** Finalization preserves all existing balances.

### Distribution invariants

- **CONFIRMED:** Only the approved authority can distribute.
- **PROPOSED:** Distribution accepts one or more recipients.
- **PROPOSED:** Empty recipient arrays fail.
- **PROPOSED:** Invalid, duplicate, or previously notified recipients cause complete transaction failure.
- **PROPOSED:** No partial batch succeeds.
- **CONFIRMED:** Distribution after finalization always fails.
- **PROPOSED:** Distribution above the immutable cap always fails.

### Authority invariants

- **PROPOSED:** Authority is nonzero and immutable.
- **PROPOSED:** Deployment creates no implicit deployer privilege unless the deployer is explicitly supplied as authority.
- **PROPOSED:** No authority-transfer path exists.
- **CONFIRMED:** No secondary privileged role exists.
- **CONFIRMED:** Only the approved authority can finalize.
- **CONFIRMED:** Unauthorized actions cannot modify state.
- **CONFIRMED:** Finalization cannot be reversed.
- **CONFIRMED:** Finalization permanently removes all effective authority powers.

### Interface invariants

- **PROPOSED:** `transfer` always fails, including for zero value.
- **PROPOSED:** `transferFrom` always fails.
- **PROPOSED:** `approve` always fails.
- **PROPOSED:** `allowance` always reports zero.
- **PROPOSED:** Permit and burn functions are absent.
- **CONFIRMED:** No movement can be enabled through another path.

### Value-safety invariants

- **CONFIRMED:** No REP interaction exists.
- **CONFIRMED:** The contract exposes no intended ETH-receive path.
- **CONFIRMED:** The contract exposes no ETH-withdrawal path.
- **CONFIRMED:** The contract cannot execute arbitrary external calls.
- **CONFIRMED:** No upgrade path exists.
- **CONFIRMED:** No mechanism can restore distribution after finalization.

### Event invariants

- **PROPOSED:** Every successful issuance emits one standard mint-style issuance event.
- **PROPOSED:** Reverted distributions produce no persistent issuance events.
- **PROPOSED:** Successful distribution increases supply by exactly the recipient count.
- **PROPOSED:** Finalization emits one finalization event containing the accurate final supply.

## 24. Acceptance criteria

All boxes remain unchecked because the specification and implementation are not approved.

### Construction

- [ ] Final approved name is returned.
- [ ] Final approved symbol is returned.
- [ ] Decimals are zero if the proposed default is approved.
- [ ] Initial total supply is zero.
- [ ] Immutable authority is the configured nonzero address.
- [ ] Zero authority is rejected.
- [ ] Proposed immutable distribution cap is configured.
- [ ] Invalid cap is rejected if the approved design disallows zero.
- [ ] Distribution is not finalized initially.

### Distribution

- [ ] A one-recipient array succeeds.
- [ ] A valid multi-recipient array succeeds.
- [ ] Every successful recipient receives exactly one unit.
- [ ] Empty arrays revert.
- [ ] A zero address reverts the complete operation.
- [ ] A duplicate inside the array reverts the complete operation.
- [ ] A previously notified recipient reverts the complete operation.
- [ ] Unauthorized callers revert.
- [ ] Supply accounting exactly matches successful recipients.
- [ ] One exact standard issuance event is emitted per successful recipient.
- [ ] Distribution at the cap succeeds.
- [ ] Distribution beyond the cap reverts atomically.
- [ ] No failed distribution leaves partial balances, supply, or events.
- [ ] An oversized batch fails once a maximum is approved.

### Authority

- [ ] Authority is immutable.
- [ ] No authority-transfer method exists.
- [ ] Deployer has no implicit privilege.
- [ ] Controller type does not alter contract semantics.
- [ ] Only authority can distribute.
- [ ] Only authority can finalize.

### Movement and approval

- [ ] Positive-value `transfer` reverts.
- [ ] Zero-value `transfer` reverts.
- [ ] `transferFrom` reverts.
- [ ] `approve` reverts.
- [ ] `allowance` remains zero.
- [ ] Permit is absent.
- [ ] Burn is absent.

### Finalization

- [ ] Authorized finalization succeeds.
- [ ] Unauthorized finalization fails.
- [ ] Repeated finalization fails.
- [ ] Distribution afterward fails.
- [ ] Existing balances remain.
- [ ] Authority address remains readable.
- [ ] Authority has no effective post-finalization power.
- [ ] Final supply is emitted accurately.
- [ ] Finalization below the cap remains valid.

### Architecture

- [ ] No external-call capability exists.
- [ ] No REP dependency exists.
- [ ] No payable interface exists.
- [ ] No ETH withdrawal exists.
- [ ] No proxy exists.
- [ ] No upgrade mechanism exists.
- [ ] No delegatecall exists.
- [ ] No unexpected administrative role exists.
- [ ] Bytecode remains within applicable size limits.
- [ ] Source compiles with the pinned Solidity version.
- [ ] Static analysis has no unexplained critical findings.
- [ ] Unit, fuzz, and invariant tests cover every approved behavior.
- [ ] This work receives the required independent review before a release gate advances.

## 25. Explicit non-goals

- **OUT OF SCOPE:** migrating REP;
- **OUT OF SCOPE:** taking custody of REP;
- **OUT OF SCOPE:** validating REP balances on-chain;
- **OUT OF SCOPE:** validating migration status on-chain;
- **OUT OF SCOPE:** rewarding holders;
- **OUT OF SCOPE:** distributing economic value;
- **OUT OF SCOPE:** creating liquidity;
- **OUT OF SCOPE:** enabling trading;
- **OUT OF SCOPE:** enabling approvals;
- **OUT OF SCOPE:** enabling bridging;
- **OUT OF SCOPE:** supporting claims or redemptions;
- **OUT OF SCOPE:** supporting governance or staking;
- **OUT OF SCOPE:** supporting upgradeability;
- **OUT OF SCOPE:** creating a general-purpose airdrop platform;
- **OUT OF SCOPE:** replacing official migration communications;
- **OUT OF SCOPE:** guaranteeing wallet visibility;
- **OUT OF SCOPE:** preventing scammers from copying metadata.

## 26. Deferred operations-pipeline decisions

The following are **DEFERRED**, not forgotten:

- REP contract addresses;
- REP versions and universes;
- snapshot block and block hash;
- archive RPC provider and failure policy;
- holder-discovery method;
- balance threshold;
- successful-migration definition;
- partial migration behavior;
- exchange exclusions;
- protocol exclusions;
- burn-address exclusions;
- custody classifications;
- manual exclusions and approval evidence;
- contract-address eligibility;
- canonical sorting;
- immutable distribution-cap value and supporting evidence;
- batch manifest format;
- artifact checksums;
- canary list;
- gas-price scheduling;
- rollout batch sequence;
- reconciliation procedure;
- campaign effectiveness metrics.

These decisions must be documented and approved before their corresponding pipeline or deployment phases. They must not be embedded in the notice contract.

## 27. Communications and safety requirements

Contract-related communications must:

- **CONFIRMED:** always describe the artifact as a notice;
- **CONFIRMED:** never call it migrated REP;
- **CONFIRMED:** never imply economic value;
- **CONFIRMED:** never instruct holders to approve the notice;
- **CONFIRMED:** never instruct holders to swap the notice;
- **CONFIRMED:** never instruct holders to transfer or bridge the notice;
- **CONFIRMED:** never instruct holders to burn the notice;
- **CONFIRMED:** never imply that matching metadata proves authenticity;
- **PROPOSED:** publish the canonical contract address on official Augur surfaces;
- **PROPOSED:** tell users to navigate independently to official sources;
- **PROPOSED:** explicitly warn that fraudulent copies may exist;
- **CONFIRMED:** avoid any migration call-to-action that resembles a drainer, approval, or wallet-connect flow.

Final user-facing wording, canonical migration URL, publication plan, and incident-response messaging remain **UNRESOLVED**. This specification does not approve final communications copy.

## 28. Alternatives and rationale

| Alternative | Advantages | Disadvantages and implications | Current disposition |
| --- | --- | --- | --- |
| Standard transferable ERC-20 | Maximum compatibility with token tooling | Creates movement, approval, market, scam, and accounting risks that contradict the notice meaning | **OUT OF SCOPE** |
| Non-transferable ERC-20-shaped notice | Familiar balances, supply, metadata, and selectors; simple one-unit accounting | Deliberately rejects movement and approvals, differs from strict ERC-20 behavior, and does not guarantee wallet visibility | **PROPOSED** |
| ERC-721 | Unique receipt semantics; broad NFT tooling | Token IDs, URI systems, transfer/operator approvals, and NFT spam treatment add complexity | Not preferred; **OUT OF SCOPE** under current constraints |
| ERC-1155 | Efficient standardized batch semantics | Multi-token and operator-approval surface is unnecessary | Not preferred; **OUT OF SCOPE** |
| Event-only approach | Minimal state and no token balance | Poor visibility in normal wallet asset views; harder holder-facing persistence | Considered, not currently preferred |
| Off-chain-only outreach | Avoids contract and token scam surface | May not reach holders outside known public channels | Complementary approach; not excluded from the broader campaign |
| Claim-based token | Recipients opt in; no unsolicited asset | Requires interaction, signatures, and phishing-sensitive instructions | **OUT OF SCOPE** |
| Merkle claim | Efficient eligibility commitment | Requires claim UX, proofs, wallet interaction, and gas; contradicts notice-only behavior | **OUT OF SCOPE** |
| Direct individual transactions without a notice token | Simple transaction history | No persistent standard balance/metadata surface and potentially higher operational overhead | Considered, not currently preferred |

## 29. Open maintainer decisions

Every item below requires explicit approval or rejection before implementation.

| Decision | Proposed default | Rationale | Security implication | Current status |
| --- | --- | --- | --- | --- |
| ERC-20-shaped interface approved? | Yes, without claiming full behavioral compliance | Best available familiar balance, supply, metadata, and selector surface for compatibility testing | Integrations may assume transferability; movement and approval selectors must reliably revert | **UNRESOLVED** |
| Final token name? | No proposal in this draft | Avoid inventing branding or misleading wording | A poor name can imply value or migrated REP | **UNRESOLVED** |
| Final symbol? | No proposal in this draft | Avoid ticker confusion | Copyable or REP-like symbols increase impersonation risk | **UNRESOLVED** |
| Zero decimals approved? | `0` | One indivisible notice | Simplifies accounting and avoids fractional interpretations | **UNRESOLVED** |
| One unit per recipient approved? | `1` | Binary receipt state | Supports balance and supply invariants | **UNRESOLVED** |
| Movement and approval reverts approved? | Revert every `transfer`, `transferFrom`, and `approve`; return zero allowance | Preserves notice-only behavior while retaining familiar selectors | Deliberately differs from strict ERC-20 behavior and must be tested across tooling | **UNRESOLVED** |
| Burn disabled? | Yes | Preserves balances and reconciliation | Enabling burn weakens historical and supply invariants | **UNRESOLVED** |
| One array-based distribution operation approved? | `distribute(address[] recipients)` for canaries and batches | One authorization, validation, event, and atomicity path | Array handling and gas limits require careful testing | **UNRESOLVED** |
| Strict atomic batch semantics approved? | Yes; every invalid entry reverts the complete operation | Deterministic reconciliation and no silent skipping | One bad entry blocks a batch, requiring strong prevalidation | **UNRESOLVED** |
| Immutable authority approved? | One nonzero constructor-supplied immutable authority with no transfer path | Removes handoff, pending-owner, and mutable-governance surface | Misconfiguration or loss requires abandonment or redeployment | **UNRESOLVED** |
| Immutable issuance cap approved? | Yes | Bounds authority misuse and campaign scale | Does not prove recipient correctness and may force redeployment if too low | **UNRESOLVED** |
| Exact issuance-cap derivation? | Approved recipient manifest or approved conservative upper bound | Cap must be evidence-based rather than guessed | Wrong derivation can permit excess issuance or block intended recipients | **UNRESOLVED** |
| Repeated finalization behavior? | Revert | Explicitly reports an invalid repeated action | Avoids silent no-op assumptions in operations | **UNRESOLVED** |
| Finalization timestamp stored? | No; use event transaction/block metadata | Avoids redundant storage | Reviewers must rely on canonical chain history for timing | **UNRESOLVED** |
| Required events? | One standard mint-style issuance event per recipient and one finalization event with authority and final supply | Supports standard indexing and direct reconciliation without duplicate per-recipient events | Missing, redundant, or misleading events can impair operational verification | **UNRESOLVED** |
| Batch manifest hash or identifier? | No default | Avoid conflicting sources of truth unless operations demonstrates a need | Omitting it relies on transaction, manifest, and checksum discipline | **UNRESOLVED** |
| Maximum batch size determined later through gas testing? | Yes | A safe limit must be measured, not guessed | Oversized batches can fail or reduce operational margin | **UNRESOLVED** |
| Final production-controller arrangement? | Dedicated maintainer-approved controller; dedicated Safe preferred | Separates campaign authority from daily activity and enables reviewable control | Controller compromise, loss, or misconfiguration can misuse or halt capped issuance | **UNRESOLVED** |
| Mainnet signer set and threshold? | Evaluate independent signers and a higher threshold before mainnet | A one-owner Safe is not multisignature security | Signer compromise, loss, and coordination remain operational risks | **UNRESOLVED** |
| Independent review requirement? | Yes | Security-sensitive contract and operations | Self-review is insufficient for release gating | **UNRESOLVED** |
| Sepolia wallet-display test requirement? | Yes | Wallet visibility is an empirical hypothesis | Findings may expose confusion or spam-classification risks before mainnet | **UNRESOLVED** |
| Communications wording and canonical publication plan? | Notice-only wording and contract-address verification through official surfaces | Metadata alone cannot authenticate the deployment | Inconsistent or misleading publication increases phishing and impersonation risk | **UNRESOLVED** |

Additional decisions remain for finalization triggers, exact Safe configuration and recovery, deployment method, and all deferred recipient-pipeline inputs.

## 30. Approval

This specification is not approved.

Required before implementation:

- [ ] Product behavior approved
- [ ] Administrative model approved
- [ ] ERC-20-shaped interface boundary approved
- [ ] Transfer and approval semantics approved
- [ ] Burn semantics approved
- [ ] Array distribution, cap, and atomic batch semantics approved
- [ ] Event policy approved
- [ ] Finalization semantics approved
- [ ] Security invariants approved
- [ ] Acceptance criteria approved
- [ ] Threat-model alignment reviewed
