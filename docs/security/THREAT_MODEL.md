# Threat Model

## Status and scope

Status: Draft

Current milestone: Product specification

No production contract, recipient pipeline, RPC integration, deployment script, or transaction functionality exists. This document identifies risks that must inform specification approval, implementation, testing, operations, and communications. It does not establish that the proposed design is safe, audited, or production-ready.

Risk-status vocabulary:

- **Identified** — recognized risk without a complete approved treatment.
- **Mitigated by design** — the draft design removes or materially narrows the risk, subject to correct implementation.
- **Requires operational mitigation** — the contract alone cannot address the risk.
- **Requires testing** — the proposed design must be demonstrated through tests or empirical evaluation.
- **Unresolved** — a maintainer decision or mitigation remains open.
- **Accepted** — maintainers have explicitly accepted the residual risk. No risk is marked accepted in this draft.

## Security objectives

- Preserve the notice-only, non-economic meaning.
- Prevent unauthorized or duplicate distribution.
- Prevent transfer, approval, burn, and upgrade paths unless explicitly approved.
- Make finalization irreversible and comprehensive.
- Keep REP, migration contracts, ETH handling, and arbitrary external calls outside the contract.
- Make recipient construction and transaction execution reproducible and reviewable.
- Avoid communications patterns that encourage dangerous wallet interactions.

## Contract risk register

| Risk | Status | Draft treatment or required action |
| --- | --- | --- |
| Unauthorized distribution or minting | Requires testing | One immutable authority is proposed. Unit, fuzz, and invariant tests must show that every unauthorized state-changing attempt fails. |
| Immutable authority configured incorrectly | Requires operational mitigation | Independently review the checksummed constructor argument, intended chain, controller evidence, unsigned deployment artifact, and simulation before deployment. Immutable design cannot repair a wrong address in place. |
| Hidden deployer or secondary privilege | Mitigated by design | The proposed constructor supplies the authority directly. Deployment alone creates no permission, no handoff is required, no authority-transfer path exists, and overlapping roles are excluded. Correct implementation still requires review. |
| Immutable authority becomes unavailable | Unresolved | The contract fails closed and cannot recover or replace the authority. Abandonment or redeployment is the proposed accepted trade-off for a non-custodial communications artifact, but maintainers have not yet approved that trade-off. |
| Authority issues notices to incorrect recipients | Requires operational mitigation | Immutable authority does not prove recipient correctness. Reviewed manifests, transaction simulation, batch review, and reconciliation remain necessary. |
| Authority compromise enables malicious issuance | Requires operational mitigation | Issuance-cap mitigation: the proposed immutable cap bounds total misuse but does not prevent issuance to incorrect addresses within the cap. Controller security and operational review remain required. |
| Issuance cap derived incorrectly | Unresolved | The exact cap must come from an approved recipient manifest or approved conservative upper bound. A cap that is too high weakens the misuse bound; a cap that is too low may require redeployment. |
| Issuance cap is bypassed or misapplied | Requires testing | Construction and sequence tests must show that supply never exceeds the immutable cap and that over-cap distributions revert atomically. |
| Sole signer compromise | Requires operational mitigation | A dedicated controller, signer isolation, transaction review, limited rollout, and incident procedures are required. A one-owner Safe does not provide multisignature security. |
| Sole signer loss | Requires operational mitigation | Document key-storage and recovery assumptions before deployment. With immutable authority, permanent controller loss may require abandonment or redeployment. |
| Safe owners or threshold configured incorrectly | Requires operational mitigation | Verify owners, threshold, signer independence, intended chain, and controller address from primary Safe state before deployment. |
| Malicious or unnecessary Safe module | Requires operational mitigation | Review every enabled module and reject unexplained capability. Safe use alone does not remove controller risk. |
| Unsafe Safe guard or fallback handler | Requires operational mitigation | Inspect and approve guard and fallback-handler configuration and include them in simulation and independent review. |
| Accidental transferability | Requires testing | Every movement path must be disabled in contract logic and exercised through unit, fuzz, and invariant tests. |
| Approval or allowance enables movement | Requires testing | Approval functions are proposed to revert and allowance to remain zero. Inherited and non-standard paths require review. |
| Approval confusion causes recipients to follow scam flows | Requires operational mitigation | The contract should expose no useful approval path, and communications must never instruct approval, permit, or wallet-connect actions. |
| Holder burning weakens receipt and supply accounting | Mitigated by design | Burning is proposed to be disabled. The decision remains subject to maintainer approval. |
| Duplicate recipient increases balance or supply | Requires testing | Recipient state must prevent a second notice and preserve the one-unit maximum. |
| Incorrect total-supply accounting | Requires testing | Supply must equal unique successful notices while burning is disabled. Failed operations must not change supply. |
| Partial batch execution creates ambiguous reconciliation | Mitigated by design | All-or-nothing batches are proposed. Tests must confirm no persistent state or events remain after a revert. |
| Batch duplication or repeated transaction submission | Requires operational mitigation | On-chain duplicate rejection is necessary, while off-chain manifests and reconciliation must prevent repeat submissions. |
| Finalization does not disable every distribution path | Requires testing | Finalization must cover the one array-based distribution operation, inherited mint behavior, and every other possible issuance path. |
| Finalization reversal or restoration of authority | Mitigated by design | No unfinalize or upgrade path is permitted. Sequence invariants must still be tested. |
| Repeated finalization behavior is ambiguous | Unresolved | The proposed default is an explicit revert, but maintainers must approve it. |
| Finalization before reconciliation | Requires operational mitigation | Require explicit review of every intended batch, event, balance, manifest checksum, and cumulative supply before authorizing finalization. |
| Failure to finalize promptly | Requires operational mitigation | Assign a human owner and deadline for finalization; the capped authority remains effective until finalization succeeds. |
| Unexpected external call or callback | Mitigated by design | REP calls, migration calls, arbitrary calls, hooks, callbacks, and recovery helpers are excluded. Implementation review must confirm the absence of call paths. |
| Upgrade, proxy, or delegatecall backdoor | Mitigated by design | Proxies, upgradeability, and delegatecall are prohibited. Bytecode and source review must verify this. |
| Forced ETH affects logic | Mitigated by design | The contract should expose no intended ETH path and must not depend on its balance. Forced ETH may still be technically possible and must be inert. |
| Compiler, dependency, or override behavior differs from assumptions | Requires testing | Exact pins, build reproduction, inherited-hook review, compilation checks, and static analysis are required. |
| Tooling assumes full ERC-20 compliance | Requires testing | Wallets, explorers, indexers, and integrations may assume transfers or zero-value calls succeed. The ERC-20-shaped compatibility boundary requires empirical and ABI-level testing. |

## Recipient-data risk register

Recipient selection is deferred to a later off-chain pipeline, but its risks affect the experiment's legitimacy and safety.

| Risk | Status | Required treatment |
| --- | --- | --- |
| Incorrect REP contract address, version, universe, snapshot block, or chain | Unresolved | Maintainers must approve exact inputs; artifacts must record chain ID, block number, block hash, and queried contracts. |
| Incomplete holder discovery | Identified | The discovery method must be documented, tested with fixtures, and independently reviewed. |
| Unavailable or inconsistent historical state | Requires operational mitigation | Use a suitable archive source, pin block data, fail closed, and record source category without committing secrets. |
| Incorrect migration-status evaluation | Unresolved | The definition of successful and partial migration must be approved before pipeline implementation. |
| Eligible holders excluded or ineligible holders included | Identified | Every rule needs deterministic logic, tests, counts, evidence, and reviewable reason codes. |
| Malformed, zero, duplicate, or non-canonical address | Requires testing | Schema validation, checksum handling, deterministic deduplication, and canonical sorting must be tested. |
| Exchange, protocol, contract, or custody address misclassification | Unresolved | Classification must be evidence-backed and must not rely only on code presence. |
| Floating-point balance errors | Mitigated by design | Raw integer balances and `bigint` are mandatory; tests must cover thresholds and decimal conversion. |
| Manual artifact edits or non-deterministic output | Mitigated by design | Generated production manifests must be reproducible, checksummed, and regenerated from reviewed inputs. |
| Checksum or manifest mismatch | Requires operational mitigation | Review tooling and operators must verify input, batch, and cumulative checksums before submission. |
| Duplicate or invalid batch data | Requires testing | Off-chain validation must reject empty batches, malformed or zero addresses, duplicates, previously issued recipients, oversized batches, and cap overflow before transaction construction. |
| Submitted transaction does not match approved manifest | Requires operational mitigation | Compare decoded calldata, recipient order, recipient count, batch checksum, input checksum, expected cumulative supply, and cap headroom before signing. |

## Deployment and operational risk register

| Risk | Status | Required treatment |
| --- | --- | --- |
| Wrong network, controller, target, constructor value, or bytecode | Requires operational mitigation | Use documented unsigned artifacts, explicit chain checks, bytecode hashes, controller-state review, transaction simulation, and independent review. |
| Dependency or compiler mismatch | Requires testing | Reproduce builds in a second environment and compare creation/runtime bytecode. |
| Repeated, skipped, reordered, or wrong batch | Requires operational mitigation | Use numbered manifests, checksums, human review, and reconciliation before the next rollout step. |
| Batch exceeds gas or calldata safety limits | Unresolved | Measure candidate sizes and approve a limit with block-gas safety margin. |
| Gas spike, nonce conflict, or transaction replacement | Requires operational mitigation | Human operators must apply rollout, nonce, fee, and stop procedures. |
| Incomplete reconciliation before continuing | Requires operational mitigation | Require event, balance, transaction, and cumulative-supply reconciliation per batch. |
| Premature finalization | Requires operational mitigation | Require explicit human approval only after all intended batches reconcile. |
| Failure to finalize | Requires operational mitigation | Track the open authority and finalization step as a release obligation with assigned human ownership. |
| Source-verification or runtime-bytecode mismatch | Requires operational mitigation | Compare reviewed artifacts with deployed code and stop on mismatch. |
| Production secret exposure | Mitigated by design | Agents must not request, inspect, store, or use production private keys and must not operate the Safe. |
| Controller used for unrelated assets or protocol activity | Requires operational mitigation | Prefer a dedicated controller and review unrelated balances, modules, and transaction history that could complicate incident response or signer decisions. |
| Controller recovery process is untested or unsafe | Requires operational mitigation | Document signer storage, recovery procedure, and limitations before deployment. Recovery must not be represented as contract-level authority mutability. |

## Communications and scam risk register

| Risk | Status | Required treatment |
| --- | --- | --- |
| Fake tokens use identical name and symbol | Requires operational mitigation | Publish and repeatedly verify the canonical contract address through official Augur surfaces. |
| Fake deployments copy the full interface and metadata | Requires operational mitigation | Treat the canonical address and reviewed bytecode as identity. Familiar selectors and matching metadata do not authenticate a deployment. |
| Canonical-address substitution in public materials | Requires operational mitigation | Use reviewed source material, independent address verification, and controlled publication updates. |
| Public communications are inconsistent across channels | Requires operational mitigation | Approve canonical wording and ensure every official surface describes the same notice-only meaning. |
| Holders mistake the notice for REP or migrated REP | Requires operational mitigation | Metadata and communications must say notice-only, no value, and no migration effect. Wallet rendering must be tested. |
| Holders believe the notice has economic value | Requires operational mitigation | Avoid reward, redemption, price, claim, or replacement-token language. |
| Fake liquidity pools create apparent tradability | Requires operational mitigation | Warn that pools and price displays do not make the notice authentic or valuable; never promote trading. |
| Third-party interfaces attach misleading price metadata | Requires operational mitigation | Public materials must disclaim price metadata and identify the contract only by canonical address. |
| Wallet or explorer assumes the notice is transferable | Requires testing | Observe how target interfaces describe disabled transfer and approval functions and document misleading affordances or errors. |
| Interface is described as fully ERC-20 compliant | Requires operational mitigation | Use the approved ERC-20-shaped compatibility language and explicitly state that movement, approvals, and zero-value transfers reject. |
| Wallets hide the notice as spam | Requires testing | Sepolia and target-interface observations are required; visibility must not be promised. |
| Wallets truncate or misrender the name or symbol | Requires testing | Candidate metadata must be reviewed empirically across target interfaces before approval. |
| Users follow a malicious link shown by a wallet | Requires operational mitigation | Tell users to navigate independently to official Augur surfaces rather than trusting token-attached links. |
| Approval, signature, burn, swap, or claim instructions resemble a drainer | Mitigated by design | The product requires no holder interaction, and communications must never request these actions. |
| Wallet visibility is treated as guaranteed | Requires operational mitigation | Frame visibility and awareness as hypotheses and publish observed limitations. |
| One-owner Safe is described as multisignature security | Requires operational mitigation | Accurately disclose the owner and threshold model. Address stability and transaction review benefits must not be confused with independent-signature security. |
| Controller is described as organizationally controlled without evidence | Requires operational mitigation | Describe only the documented ownership and signer facts. Do not claim Augur organizational control unless it is true and reviewed. |

## Assumptions

- Maintainers will approve the product specification, threat model alignment, authority model, metadata, and acceptance criteria before implementation.
- Production control is expected to use a dedicated, maintainer-approved controller rather than an everyday or unrelated browser hot wallet; a dedicated Safe is preferred but not approved.
- Mainnet signing, submission, and broadcast remain human-controlled.
- Compiler settings, dependencies, artifacts, and recipient inputs remain pinned and reviewable.
- Users do not need to interact with the notice to migrate REP.
- Recipient selection occurs off-chain before distribution.

## Unresolved threats and decisions

- Final name and symbol, including wallet truncation behavior.
- ERC-20-shaped interface boundary and exact disabled movement and approval behavior.
- Immutable-authority proposal and its fail-closed redeployment trade-off.
- Immutable issuance-cap approval and exact derivation.
- Dedicated-controller type, Safe configuration if used, signer set, threshold, storage, recovery, and incident-response model.
- Recipient discovery, snapshot completeness, and migration-detection methodology.
- Contract, exchange, protocol, and custody-address eligibility.
- Gas-safe maximum batch size, batch identifier decision, and canary stop conditions.
- Canonical public wording, migration URL, and address-publication controls.
- Wallet-display and spam-classification behavior across target interfaces.

Independent review remains required. No residual risk is accepted merely because it appears in this document.
