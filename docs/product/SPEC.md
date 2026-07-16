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

- **PROPOSED:** representing notice ownership through a wallet-compatible balance and metadata interface;
- **PROPOSED:** preventing duplicate notice issuance;
- **CONFIRMED:** enforcing distribution and finalization authorization;
- **CONFIRMED:** preventing transfer and approval behavior;
- **CONFIRMED:** permanently ending distribution through irreversible finalization;
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

**PROPOSED:** ERC-20-compatible balance and metadata interface.

Reasons:

- `balanceOf` is widely understood by wallets, explorers, and portfolio interfaces.
- Standard metadata offers the best available chance of familiar representation.
- Total supply and balances are straightforward to inspect.
- Reviewers and operators can use common Ethereum tooling.

Trade-offs:

- ERC-20 compatibility exposes familiar transfer and approval function selectors even though the notice has no legitimate movement or spender use case.
- Those functions must be deliberately disabled in contract logic.
- Some integrations may assume transferability despite reverts.
- ERC-20 compatibility does not guarantee automatic wallet display.
- Token names and symbols are copyable and do not authenticate the deployment.

This interface choice remains **PROPOSED** until approved. It does not select OpenZeppelin, inheritance, or a custom implementation. Library and implementation structure must be chosen later based on the approved behavior and reviewed pinned dependencies.

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
- **PROPOSED:** Each successful recipient receives exactly one unit.
- **PROPOSED:** No address may hold more than one unit.
- **PROPOSED:** Total supply equals the number of unique successfully notified addresses.
- **PROPOSED:** An already-notified address cannot receive another unit.
- **PROPOSED:** Failed distribution attempts do not change balances or supply.
- **PROPOSED:** Existing balances remain unchanged after finalization.

These properties depend on disabling ordinary transfers and holder burning. If balances could move, `balanceOf == 1` would no longer mean that the address was directly notified. If burning were allowed, total supply would no longer equal the number of successful notices. The proposed simple accounting invariant therefore requires both transfer and burn paths to remain disabled.

## 10. Transfer behavior

| Function or path | Status | Proposed behavior |
| --- | --- | --- |
| `transfer` | **PROPOSED** | Revert |
| `transferFrom` | **PROPOSED** | Revert |
| Internal ordinary transfer | **PROPOSED** | Not exposed through any external path |
| Mint/distribution | **PROPOSED** | Restricted to the approved authority while distribution is active |
| Burn | **PROPOSED** | Disabled unless explicitly approved |
| `burnFrom` | **OUT OF SCOPE** | Unsupported |
| Bridge movement | **OUT OF SCOPE** | Unsupported |
| Wrapping supplied by this project | **OUT OF SCOPE** | Unsupported |

**CONFIRMED:** Non-transferability must be enforced on-chain. Documentation, wallet UI, or frontend restrictions are insufficient.

The contract cannot prevent an unrelated third party from creating an external wrapper or derivative representation, but it must provide no native wrapping, bridging, transfer, approval, or callback support.

## 11. Approval behavior

| Function or feature | Status | Proposed behavior |
| --- | --- | --- |
| `approve` | **PROPOSED** | Revert |
| `allowance` | **PROPOSED** | Always return zero, or expose only the standard zero state required by the chosen implementation |
| Allowance increase/decrease | **PROPOSED** | Unsupported or revert |
| Permit | **OUT OF SCOPE** | Unsupported |
| Operator approvals | **OUT OF SCOPE** | Unsupported |
| Approval callbacks | **OUT OF SCOPE** | Unsupported |

Approvals should be disabled because:

- there is no legitimate spender use case;
- approval prompts may confuse recipients;
- approval and permit flows resemble common scam behavior;
- allowances create unnecessary integration and attack surface;
- transferable authority would contradict the notice's user-facing meaning.

The exact ABI treatment of non-standard allowance helpers is **UNRESOLVED** and depends on the approved ERC-20 implementation approach. No approval path may enable movement.

## 12. Burn behavior

**PROPOSED:** Holder burning is disabled.

Rationale:

- No user requirement for burning has been identified.
- Burning weakens historical balance visibility.
- Burning breaks the proposed equality between total supply and unique successful recipients.
- Users can hide unsolicited assets through wallet-interface controls without changing on-chain state.
- Burn functions expand the interface and test surface.
- Telling users to burn a notice could create dangerous behavioral expectations.

If burning were approved later, the specification would need to redefine:

- whether a burned address may be notified again;
- whether historical receipt requires a separate `wasNotified` mapping;
- how total supply reconciles with successful distribution events;
- whether burning is transferable movement to the zero address;
- how operations reports distinguish issued, held, and burned notices.

No burn behavior is approved in this draft.

## 13. Administrative model

The contract requires the minimum authority necessary to distribute notices and finalize distribution.

Proposed model:

- **PROPOSED:** One clearly defined distribution authority.
- **PROPOSED:** The same authority can finalize.
- **PROPOSED:** The initial authority is supplied explicitly and cannot be the zero address.
- **PROPOSED:** Production authority is expected to be an Augur-controlled Safe.
- **CONFIRMED:** No personal hot wallet should retain production control.
- **CONFIRMED:** No hidden secondary administrator or deployer privilege may remain after an approved handoff.
- **CONFIRMED:** Overlapping owner, admin, minter, and operator systems are not permitted without an approved need.

Unresolved decisions:

- **UNRESOLVED:** Whether the authority primitive is `Ownable`, `Ownable2Step`, or a custom minimal mechanism.
- **UNRESOLVED:** Whether authority transfer is supported before finalization.
- **UNRESOLVED:** Whether authority transfer is possible after finalization.
- **UNRESOLVED:** Whether ownership is renounced or merely rendered powerless after finalization.
- **UNRESOLVED:** Whether finalization clears the stored authority.
- **UNRESOLVED:** Whether the Safe deploys directly or receives authority through a handoff.

Conservative proposed behavior:

- permit an explicitly reviewed, two-step handoff before finalization if operationally necessary;
- reject invalid or zero-address authority transitions;
- freeze authority changes after finalization;
- retain the final authority address as an audit record rather than automatically renouncing or clearing it;
- make finalization, not ownership renunciation, the irreversible mechanism that disables distribution.

This behavior remains **PROPOSED**. The specification does not select an implementation library.

## 14. Distribution functions

**PROPOSED:** Expose both:

- one single-recipient distribution operation for controlled testing, canary activity, and intentionally isolated distribution; and
- one bounded batch distribution operation for normal distribution.

Conceptual operations:

```text
distribute(recipient)
distributeBatch(recipients)
```

These are behavioral descriptions, not approved Solidity signatures.

Both operations must use identical recipient validation and supply semantics. The batch maximum is **DEFERRED** until gas and calldata measurements are available. The specification must not guess a number. Once measured, the selected limit must leave a documented safety margin below relevant block gas and transaction constraints.

## 15. Recipient validation

| Condition | Status | Proposed result |
| --- | --- | --- |
| Zero address | **PROPOSED** | Revert |
| Already-notified recipient | **PROPOSED** | Revert |
| Duplicate inside one batch | **PROPOSED** | Revert the complete batch |
| Unauthorized caller | **CONFIRMED** | Revert |
| Distribution after finalization | **CONFIRMED** | Revert |
| Empty batch | **PROPOSED** | Revert |
| Batch above approved maximum | **PROPOSED** | Revert once a maximum is defined |
| Valid smart-contract address | **PROPOSED** | Technically permitted on-chain |

The contract should not attempt to distinguish EOAs from contracts. EOA/contract eligibility is **DEFERRED** to the off-chain pipeline because:

- `extcodesize`-style checks are incomplete;
- contracts under construction can appear to have no code;
- counterfactual and delegated account models complicate classification;
- exchange, protocol, and custody classifications require evidence rather than a bytecode-only rule.

## 16. Atomicity and batch failure semantics

**PROPOSED:** All-or-nothing batch execution.

One invalid recipient causes the complete batch to revert.

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

The off-chain pipeline must therefore validate manifests before transaction construction. Partial-success semantics are not currently preferred.

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
- **PROPOSED:** Successful finalization emits an event.
- **CONFIRMED:** Finalization is irreversible.
- **CONFIRMED:** Every distribution and mint path is permanently disabled afterward.
- **CONFIRMED:** Existing balances remain.
- **CONFIRMED:** Transfers and approvals remain disabled.
- **CONFIRMED:** No emergency unfinalize function exists.
- **CONFIRMED:** No upgrade mechanism can bypass finalization.

Conservative proposed defaults:

- **PROPOSED:** A repeated finalization call reverts with an explicit already-finalized failure.
- **PROPOSED:** Authority transfer after finalization reverts.
- **PROPOSED:** Finalization does not automatically renounce or clear the recorded authority.
- **PROPOSED:** No separate finalization timestamp or block number is stored.
- **PROPOSED:** The finalization event and transaction receipt provide timing information.

The repeated-call behavior, post-finalization authority behavior, authority clearing, and stored timing data remain **UNRESOLVED** until approved.

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

### `NoticeDistributed`

| Property | Proposed definition |
| --- | --- |
| Status | **PROPOSED** |
| Fields | Recipient address |
| Indexed fields | Recipient address |
| Emission time | Once per recipient after that recipient's notice balance and supply accounting are successfully updated |
| Reconciliation purpose | Links a successful state change to a recipient and permits event-count comparison with manifests |
| Failure behavior | Not emitted persistently for reverted operations |

### `DistributionFinalized`

| Property | Proposed definition |
| --- | --- |
| Status | **PROPOSED** |
| Fields | None required under the proposed minimal design |
| Indexed fields | None |
| Emission time | After finalized state is successfully set |
| Reconciliation purpose | Identifies the transaction and block that permanently ended distribution |
| Failure behavior | Not emitted persistently for reverted operations |

### Conditional standard ERC-20 events

If ERC-20 compatibility is approved:

- **PROPOSED:** Each successful issuance also emits the standard `Transfer` event from the zero address to the recipient for one unit.
- **PROPOSED:** Reverted issuance emits no persistent `Transfer` event.
- **PROPOSED:** Disabled approval calls emit no `Approval` event.

The proposed custom notice event and standard issuance event serve different purposes: `NoticeDistributed` communicates product semantics, while `Transfer` supports standard token-indexing expectations. Whether both are required remains part of the **UNRESOLVED** event decision.

If authority transfer is approved, an accurate administrative-transition event is required. Its exact fields are **UNRESOLVED**.

Batch identifiers are not currently proposed. Transaction hashes, reviewed manifests, and one event per recipient may be sufficient. A batch identifier should be added only if operations review shows it materially improves reconciliation without creating conflicting sources of truth.

## 21. Public read interface

Likely minimum read surface:

| Read | Status | Purpose |
| --- | --- | --- |
| Name | **PROPOSED** | Standard metadata |
| Symbol | **PROPOSED** | Standard metadata |
| Decimals | **PROPOSED** | Standard metadata; proposed value `0` |
| `balanceOf(address)` | **PROPOSED** | Determine whether the address currently holds its notice |
| Total supply | **PROPOSED** | Reconcile successful unique recipients while burning is disabled |
| Finalized state | **PROPOSED** | Verify whether distribution is permanently closed |
| Current/final authority | **PROPOSED** | Verify administrative control or retained audit record |
| `allowance(owner, spender)` | **PROPOSED** if ERC-20 compatibility is approved | Return zero under disabled approval semantics |
| Separate `wasNotified(address)` | **UNRESOLVED** | Potentially redundant while balances cannot move or burn |

The proposed preference is to omit `wasNotified(address)` because `balanceOf(address) == 1` conveys the same fact while transfers and burns are disabled. If burn or movement semantics change, a separate historical record may become necessary.

Public functions must not exist solely for test convenience.

## 22. Errors and failure reporting

**PROPOSED:** Use explicit failures rather than silent no-ops or silent skipping.

The implementation should distinguish these semantic conditions:

- unauthorized caller;
- zero recipient address;
- duplicate recipient within the submitted operation;
- already-notified recipient;
- distribution already finalized;
- empty batch;
- oversized batch;
- transfer disabled;
- approvals disabled;
- finalization already completed;
- invalid authority transition, if authority transfer is supported.

Exact custom-error names and parameter lists are **UNRESOLVED** implementation details. The approved semantics must remain testable and unambiguous.

## 23. Security invariants

These invariants are mandatory acceptance properties for any implementation of the approved design.

### Balance invariants

- **CONFIRMED:** No address holds more than one notice.
- **CONFIRMED:** The zero address never receives a notice.
- **PROPOSED:** Successful distribution changes the recipient balance from zero to one.
- **CONFIRMED:** Failed distribution does not alter balances.
- **PROPOSED:** Total supply equals unique successfully notified addresses while burning remains disabled.
- **CONFIRMED:** Notice balances cannot move between addresses.

### Authority invariants

- **CONFIRMED:** Only the approved authority can distribute.
- **CONFIRMED:** Only the approved authority can finalize.
- **CONFIRMED:** Unauthorized actions cannot modify state.
- **CONFIRMED:** No hidden deployer privilege remains after an approved authority handoff.
- **CONFIRMED:** Finalization cannot be reversed.
- **CONFIRMED:** Distribution authority cannot be restored after finalization.

### Value-safety invariants

- **CONFIRMED:** The contract cannot transfer REP.
- **CONFIRMED:** The contract cannot approve REP.
- **CONFIRMED:** The contract exposes no intended ETH-receive path.
- **CONFIRMED:** The contract exposes no ETH-withdrawal path.
- **CONFIRMED:** The contract cannot execute arbitrary external calls.
- **CONFIRMED:** Notice approvals cannot enable token movement.
- **CONFIRMED:** No upgrade path exists.

### Operational invariants

- **PROPOSED:** A successful batch emits one notice event per recipient.
- **PROPOSED:** If ERC-20 compatibility is approved, a successful batch also emits the standard issuance event once per recipient.
- **PROPOSED:** A reverted batch emits no persistent notice events.
- **PROPOSED:** A reverted batch emits no persistent standard issuance events.
- **PROPOSED:** A successful batch increases total supply by exactly its recipient count.
- **CONFIRMED:** A repeated recipient cannot increase total supply.
- **CONFIRMED:** Finalization preserves all existing balances.

## 24. Acceptance criteria

All boxes remain unchecked because the specification and implementation are not approved.

### Construction and metadata

- [ ] Final approved name is returned.
- [ ] Final approved symbol is returned.
- [ ] Decimals are zero if the proposed default is approved.
- [ ] Initial total supply is zero.
- [ ] Initial authority is correct.
- [ ] Zero-address initial authority fails.
- [ ] Distribution is initially active.

### Single distribution

- [ ] Authorized distribution succeeds.
- [ ] Recipient receives exactly one unit.
- [ ] Total supply increases by one.
- [ ] Correct notice event is emitted.
- [ ] Conditional standard issuance event behavior matches the approved interface.
- [ ] Zero address fails.
- [ ] Repeated recipient fails.
- [ ] Unauthorized caller fails.

### Batch distribution

- [ ] A valid batch succeeds.
- [ ] Every recipient receives one unit.
- [ ] Total supply increases by the batch size.
- [ ] Events contain the correct recipients.
- [ ] Empty-batch behavior matches the approved specification.
- [ ] A duplicate inside the batch fails.
- [ ] A previously notified recipient fails.
- [ ] A zero address inside the batch fails.
- [ ] An oversized batch fails once a limit exists.
- [ ] Any invalid recipient causes no partial state change.

### Non-transferability and approvals

- [ ] `transfer` fails.
- [ ] `transferFrom` fails.
- [ ] Approval cannot enable movement.
- [ ] Allowance cannot produce transferable authority.
- [ ] Permit is unavailable.
- [ ] Allowance helper behavior matches the approved interface.
- [ ] Burn behavior matches the approved decision.

### Finalization

- [ ] Authorized finalization succeeds.
- [ ] Unauthorized finalization fails.
- [ ] Finalization event is emitted.
- [ ] Finalized state becomes true.
- [ ] Finalization cannot be reversed.
- [ ] Distribution after finalization fails.
- [ ] Existing balances remain.
- [ ] Transfers remain disabled.
- [ ] Approvals remain disabled.
- [ ] Repeated finalization behavior matches the approved specification.

### Authority

- [ ] Authority transfer behavior matches the approved specification.
- [ ] Invalid authority transfer fails.
- [ ] Deployer retains no unintended privilege.
- [ ] The production Safe can perform approved actions in simulation and authorized test environments.
- [ ] Authority behavior after finalization matches the approved specification.

### Interface and safety

- [ ] No payable function exists.
- [ ] No arbitrary-call capability exists.
- [ ] No REP interaction exists.
- [ ] No proxy or upgrade mechanism exists.
- [ ] Bytecode remains within applicable size limits.
- [ ] Source compiles with the pinned Solidity version.
- [ ] Static analysis has no unexplained critical findings.
- [ ] Unit tests cover every approved behavior.
- [ ] Fuzz and invariant tests exercise mandatory security properties.
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
| Non-transferable ERC-20-compatible notice | Familiar balances and metadata; simple one-unit accounting | Transfer/approval selectors still exist and wallet visibility remains uncertain | **PROPOSED** |
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
| ERC-20 compatibility approved? | Yes, with movement and approvals disabled | Best available standard balance/metadata compatibility | Exposes familiar selectors that must reliably revert | **UNRESOLVED** |
| Final token name? | No proposal in this draft | Avoid inventing branding or misleading wording | A poor name can imply value or migrated REP | **UNRESOLVED** |
| Final symbol? | No proposal in this draft | Avoid ticker confusion | Copyable or REP-like symbols increase impersonation risk | **UNRESOLVED** |
| Zero decimals approved? | `0` | One indivisible notice | Simplifies accounting and avoids fractional interpretations | **UNRESOLVED** |
| One unit per recipient approved? | `1` | Binary receipt state | Supports balance and supply invariants | **UNRESOLVED** |
| Burn disabled? | Yes | Preserves balances and reconciliation | Enabling burn weakens historical and supply invariants | **UNRESOLVED** |
| Single distribution function needed? | Yes | Controlled canary and intentionally isolated distribution | Adds a small callable surface that must share all validation | **UNRESOLVED** |
| Batch function needed? | Yes | Operational efficiency | Loops and batch validation require gas and atomicity testing | **UNRESOLVED** |
| Empty batch behavior? | Revert | Detects malformed operations | Explicit failure avoids misleading success | **UNRESOLVED** |
| Duplicate behavior? | Revert | Exposes manifest errors | Prevents silent supply/event divergence | **UNRESOLVED** |
| All-or-nothing batch semantics? | Yes | Deterministic reconciliation | One bad entry blocks a batch, requiring strong prevalidation | **UNRESOLVED** |
| Administrative primitive? | One authority with reviewed two-step handoff if needed; library undecided | Minimizes roles while reducing wrong-address handoff risk | Primitive correctness governs all privileged behavior | **UNRESOLVED** |
| Authority transfer allowed? | Before finalization only | Supports deployer-to-Safe handoff without permanent mutability | Transfer is an additional privileged state transition | **UNRESOLVED** |
| Authority behavior after finalization? | Freeze changes; retain address as audit record | Finalization should be the disabling mechanism | Prevents post-finalization control ambiguity | **UNRESOLVED** |
| Repeated finalization behavior? | Revert | Explicitly reports an invalid repeated action | Avoids silent no-op assumptions in operations | **UNRESOLVED** |
| Finalization timestamp stored? | No; use event transaction/block metadata | Avoids redundant storage | Reviewers must rely on canonical chain history for timing | **UNRESOLVED** |
| Required events? | One indexed notice event and, if ERC-20 compatibility is approved, one standard issuance event per recipient; one finalization event | Supports direct reconciliation and standard indexing | Missing, redundant, or misleading events can impair operational verification | **UNRESOLVED** |
| Separate `wasNotified` view? | No while burn and transfer remain disabled | `balanceOf == 1` is equivalent | Adding redundant state/function surface increases complexity | **UNRESOLVED** |
| Maximum batch size determined later through gas testing? | Yes | A safe limit must be measured, not guessed | Oversized batches can fail or reduce operational margin | **UNRESOLVED** |
| Production authority expected to be a Safe? | Yes | Avoids personal hot-wallet control | Safe configuration and signer compromise remain operational risks | **UNRESOLVED** |
| Independent review requirement? | Yes | Security-sensitive contract and operations | Self-review is insufficient for release gating | **UNRESOLVED** |
| Sepolia wallet-display test requirement? | Yes | Wallet visibility is an empirical hypothesis | Findings may expose confusion or spam-classification risks before mainnet | **UNRESOLVED** |

Additional decisions remain for finalization triggers, Safe address, deployment method, canonical communications, and all deferred recipient-pipeline inputs.

## 30. Approval

This specification is not approved.

Required before implementation:

- [ ] Product behavior approved
- [ ] Administrative model approved
- [ ] Transfer and approval semantics approved
- [ ] Burn semantics approved
- [ ] Batch and duplicate semantics approved
- [ ] Finalization semantics approved
- [ ] Security invariants approved
- [ ] Acceptance criteria approved
- [ ] Threat-model alignment reviewed
