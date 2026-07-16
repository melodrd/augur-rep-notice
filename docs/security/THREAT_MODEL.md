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
| Unauthorized distribution or minting | Requires testing | One approved authority is proposed. Unit, fuzz, and invariant tests must show that unauthorized state changes fail. |
| Incorrect authority configured at deployment | Requires operational mitigation | Constructor inputs, deployment artifacts, handoff steps, and final authority must be independently reviewed and simulated. |
| Hidden deployer or secondary privilege | Mitigated by design | The specification forbids hidden or overlapping authority systems and requires removal of unintended deployer control after handoff. |
| Compromised authority or Safe signer | Requires operational mitigation | Use an Augur-controlled Safe, reviewed signer policy, transaction review, incident procedures, and limited rollout. The exact signer model remains unresolved. |
| Accidental transferability | Requires testing | Every movement path must be disabled in contract logic and exercised through unit, fuzz, and invariant tests. |
| Approval or allowance enables movement | Requires testing | Approval functions are proposed to revert and allowance to remain zero. Inherited and non-standard paths require review. |
| Approval confusion causes recipients to follow scam flows | Requires operational mitigation | The contract should expose no useful approval path, and communications must never instruct approval, permit, or wallet-connect actions. |
| Holder burning weakens receipt and supply accounting | Mitigated by design | Burning is proposed to be disabled. The decision remains subject to maintainer approval. |
| Duplicate recipient increases balance or supply | Requires testing | Recipient state must prevent a second notice and preserve the one-unit maximum. |
| Incorrect total-supply accounting | Requires testing | Supply must equal unique successful notices while burning is disabled. Failed operations must not change supply. |
| Partial batch execution creates ambiguous reconciliation | Mitigated by design | All-or-nothing batches are proposed. Tests must confirm no persistent state or events remain after a revert. |
| Batch duplication or repeated transaction submission | Requires operational mitigation | On-chain duplicate rejection is necessary, while off-chain manifests and reconciliation must prevent repeat submissions. |
| Finalization does not disable every distribution path | Requires testing | Finalization must cover single, batch, inherited mint, and any other issuance path. |
| Finalization reversal or restoration of authority | Mitigated by design | No unfinalize or upgrade path is permitted. Sequence invariants must still be tested. |
| Repeated finalization behavior is ambiguous | Unresolved | The proposed default is an explicit revert, but maintainers must approve it. |
| Authority transfer after finalization creates ambiguity | Unresolved | The proposed default freezes authority changes and retains the address as an audit record. |
| Unexpected external call or callback | Mitigated by design | REP calls, migration calls, arbitrary calls, hooks, callbacks, and recovery helpers are excluded. Implementation review must confirm the absence of call paths. |
| Upgrade, proxy, or delegatecall backdoor | Mitigated by design | Proxies, upgradeability, and delegatecall are prohibited. Bytecode and source review must verify this. |
| Forced ETH affects logic | Mitigated by design | The contract should expose no intended ETH path and must not depend on its balance. Forced ETH may still be technically possible and must be inert. |
| Compiler, dependency, or override behavior differs from assumptions | Requires testing | Exact pins, build reproduction, inherited-hook review, compilation checks, and static analysis are required. |

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

## Deployment and operational risk register

| Risk | Status | Required treatment |
| --- | --- | --- |
| Wrong network, Safe, target, constructor value, or bytecode | Requires operational mitigation | Use documented unsigned artifacts, explicit chain checks, bytecode hashes, Safe simulation, and independent review. |
| Dependency or compiler mismatch | Requires testing | Reproduce builds in a second environment and compare creation/runtime bytecode. |
| Repeated, skipped, reordered, or wrong batch | Requires operational mitigation | Use numbered manifests, checksums, human review, and reconciliation before the next rollout step. |
| Batch exceeds gas or calldata safety limits | Unresolved | Measure candidate sizes and approve a limit with block-gas safety margin. |
| Gas spike, nonce conflict, or transaction replacement | Requires operational mitigation | Human operators must apply rollout, nonce, fee, and stop procedures. |
| Incomplete reconciliation before continuing | Requires operational mitigation | Require event, balance, transaction, and cumulative-supply reconciliation per batch. |
| Premature finalization | Requires operational mitigation | Require explicit human approval only after all intended batches reconcile. |
| Failure to finalize | Requires operational mitigation | Track the open authority and finalization step as a release obligation with assigned human ownership. |
| Source-verification or runtime-bytecode mismatch | Requires operational mitigation | Compare reviewed artifacts with deployed code and stop on mismatch. |
| Production secret exposure | Mitigated by design | Agents must not request, inspect, store, or use production private keys and must not operate the Safe. |

## Communications and scam risk register

| Risk | Status | Required treatment |
| --- | --- | --- |
| Fake tokens use identical name and symbol | Requires operational mitigation | Publish and repeatedly verify the canonical contract address through official Augur surfaces. |
| Canonical-address substitution in public materials | Requires operational mitigation | Use reviewed source material, independent address verification, and controlled publication updates. |
| Public communications are inconsistent across channels | Requires operational mitigation | Approve canonical wording and ensure every official surface describes the same notice-only meaning. |
| Holders mistake the notice for REP or migrated REP | Requires operational mitigation | Metadata and communications must say notice-only, no value, and no migration effect. Wallet rendering must be tested. |
| Holders believe the notice has economic value | Requires operational mitigation | Avoid reward, redemption, price, claim, or replacement-token language. |
| Fake liquidity pools create apparent tradability | Requires operational mitigation | Warn that pools and price displays do not make the notice authentic or valuable; never promote trading. |
| Third-party interfaces attach misleading price metadata | Requires operational mitigation | Public materials must disclaim price metadata and identify the contract only by canonical address. |
| Wallets hide the notice as spam | Requires testing | Sepolia and target-interface observations are required; visibility must not be promised. |
| Wallets truncate or misrender the name or symbol | Requires testing | Candidate metadata must be reviewed empirically across target interfaces before approval. |
| Users follow a malicious link shown by a wallet | Requires operational mitigation | Tell users to navigate independently to official Augur surfaces rather than trusting token-attached links. |
| Approval, signature, burn, swap, or claim instructions resemble a drainer | Mitigated by design | The product requires no holder interaction, and communications must never request these actions. |
| Wallet visibility is treated as guaranteed | Requires operational mitigation | Frame visibility and awareness as hypotheses and publish observed limitations. |

## Assumptions

- Maintainers will approve the product specification, threat model alignment, authority model, metadata, and acceptance criteria before implementation.
- Production control is expected to use an Augur-controlled Safe rather than a personal hot wallet.
- Mainnet signing, submission, and broadcast remain human-controlled.
- Compiler settings, dependencies, artifacts, and recipient inputs remain pinned and reviewable.
- Users do not need to interact with the notice to migrate REP.
- Recipient selection occurs off-chain before distribution.

## Unresolved threats and decisions

- Final name and symbol, including wallet truncation behavior.
- ERC-20 compatibility and the exact disabled-approval interface.
- Administrative primitive, deployment/handoff method, and post-finalization authority state.
- Safe signer and incident-response model.
- Recipient discovery, snapshot completeness, and migration-detection methodology.
- Contract, exchange, protocol, and custody-address eligibility.
- Gas-safe maximum batch size and canary stop conditions.
- Canonical public wording, migration URL, and address-publication controls.
- Wallet-display and spam-classification behavior across target interfaces.

Independent review remains required. No residual risk is accepted merely because it appears in this document.
