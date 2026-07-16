# Threat Model

## Status and scope

Status: Approved for implementation planning — not audited

Approval date: 2026-07-16

Current milestone: Threat model and acceptance criteria

The repository maintainer has authorized the design-stage decisions reflected in this document. This approval permits implementation planning against the approved product specification. It does not authorize deployment, recipient selection, RPC access, wallet or key handling, signing, transaction submission, or broadcast.

No production contract, recipient pipeline, RPC integration, deployment script, or transaction functionality exists. This threat model does not establish that the future implementation is safe, free of vulnerabilities, independently audited, or production-ready.

## Risk-treatment vocabulary

Each risk register entry uses one or more of these treatments:

- **Mitigated by approved design** — the approved architecture removes or materially narrows the risk, subject to correct implementation and review.
- **Accepted architectural trade-off** — the maintainer accepts the stated residual limitation because avoiding it would require a less suitable architecture.
- **Assigned to implementation testing** — source review, unit tests, fuzz tests, invariant tests, gas tests, coverage, static analysis, or build reproduction must verify the treatment.
- **Assigned to operations pipeline** — deterministic recipient-data and manifest tooling must prevent, detect, or report the risk.
- **Assigned to deployment runbook** — human-controlled configuration, simulation, review, execution, reconciliation, or incident procedures must address the risk.
- **Assigned to communications** — canonical messaging and publication controls must reduce user confusion, impersonation, or phishing risk.
- **Blocked on later evidence** — the contract behavior is approved, but a release parameter cannot be frozen until the stated evidence satisfies a deterministic gate.

A risk may have more than one treatment. Classification does not imply that the risk is eliminated.

## Security objectives

- Preserve the notice-only, non-economic meaning.
- Prevent unauthorized, duplicate, partial, or over-cap distribution.
- Keep balances binary and total supply equal to unique successful recipients.
- Prevent every transfer, approval, permit, burn, recovery, upgrade, and authority-transfer path.
- Make finalization explicit, irreversible, and comprehensive.
- Keep REP, migration contracts, ETH handling, and arbitrary external calls outside the contract.
- Make recipient construction, transaction preparation, and reconciliation deterministic and reviewable.
- Avoid communications patterns that encourage dangerous wallet interactions.
- Treat wallet recognition and display as empirical hypotheses rather than protocol guarantees.

## Approved architectural boundary

The future candidate is constrained to:

- one standalone minimal contract with no OpenZeppelin ERC20, ownership, role, pausing, proxy, or generalized token inheritance;
- fixed metadata: `Augur REP Migration Notice`, `REPNOTICE`, and `0` decimals;
- an ERC-20-shaped ABI that does not claim full ERC-20 behavioral compliance;
- zero initial supply and one indivisible notice per unique recipient;
- one atomic `distribute(address[] recipients)` authorization and validation path;
- one nonzero constructor-supplied immutable authority;
- one nonzero immutable distribution cap equal to the exact count of unique addresses in the final approved production recipient manifest;
- a dedicated 2-of-3 Safe as the mainnet authority, with no enabled modules, no custom guard, a reviewed fallback handler, and independently controlled human signers;
- explicit irreversible finalization with no automatic finalization at the cap;
- standard mint-style `Transfer(address(0), recipient, 1)` events and one finalization event;
- no on-chain batch identifier or manifest hash;
- no intended external interaction or ETH path.

Correct implementation and later evidence remain mandatory despite these approved constraints.

## Role ownership

| Risk area | Default owner role |
| --- | --- |
| Contract implementation and tests | Contract implementer |
| Contract review | Independent contract reviewer |
| Recipient methodology and manifests | Operations/data maintainer |
| Independent recipient and operations review | Independent operations reviewer |
| Controller and deployment preparation | Deployment operator |
| Canonical communications | Communications maintainer |
| Independent communications review | Independent communications reviewer |
| Final release approval | Repository maintainer |
| Mainnet signing | Human Safe signers |

No role assignment authorizes an agent to operate the Safe, handle production keys, sign, submit, or broadcast a transaction.

## Accepted architectural trade-offs

| Accepted trade-off | Residual consequence | Owner and later control |
| --- | --- | --- |
| Immutable-authority unrecoverability | If the authority address is wrong, or the authority becomes compromised beyond recovery or permanently unavailable, the contract cannot replace it. The candidate must be abandoned or redeployed. | Deployment operator verifies the constructor authority and Safe evidence; repository maintainer approves the exact configuration before release. |
| Exact-cap redeployment risk | The cap cannot increase. A final recipient-set change after deployment that exceeds or differs materially from the cap requires abandonment and redeployment. | Operations/data maintainer derives the exact count from the final approved manifest; deployment operator and independent reviewer verify equality before deployment. |
| Strict-batch operational friction | One invalid, duplicate, previously notified, zero, oversized, or over-cap entry reverts the entire submitted array. | Operations pipeline prevalidates every batch; implementation tests prove atomic rollback; deployment runbook requires manifest and calldata review. |
| Possible wallet invisibility | Wallets may hide the notice, classify it as spam, truncate it, or fail to recognize it, so the communications experiment may not reach recipients. | Communications maintainer and deployment operator run the mandatory category-based Sepolia matrix; repository maintainer reviews the evidence before mainnet. |
| Inability to prevent fake metadata copies | Third parties can copy the name, symbol, ABI, source, or apparent liquidity. Metadata cannot authenticate the canonical deployment. | Communications use the independently verified contract address and official Augur page as the only identity source. |
| Inert forced ETH is unrecoverable | Exceptional EVM mechanisms may force ETH to the address. It remains inert and permanently unrecoverable because no withdrawal or recovery path is approved. | Contract implementer proves logic is balance-independent; independent reviewer verifies the absence of payable, receive, fallback, and withdrawal behavior. |

## Contract risk register

| Risk | Classification | Owner | Approved treatment and release requirement |
| --- | --- | --- | --- |
| Unauthorized distribution or minting | Assigned to implementation testing | Contract implementer; independent contract reviewer | Unit, fuzz, and invariant tests must prove that only the immutable authority can change balances or supply and that no alternate issuance path exists. |
| Immutable authority configured incorrectly | Assigned to deployment runbook; blocked on later evidence | Deployment operator; repository maintainer | Independently verify the checksummed Safe address, intended chain, Safe configuration, constructor data, unsigned artifact, and simulation. A mismatch stops deployment. |
| Hidden deployer or secondary privilege | Mitigated by approved design; assigned to implementation testing | Contract implementer; independent contract reviewer | Deployment grants no implicit privilege, no handoff exists, and no owner, pending owner, role, recovery administrator, or secondary finalizer may exist. ABI and source review must confirm this. |
| Immutable authority becomes unavailable or compromised beyond recovery | Accepted architectural trade-off; assigned to deployment runbook | Deployment operator; repository maintainer | The contract fails closed and cannot replace the authority. Use the approved 2-of-3 Safe controls; abandon or redeploy the candidate if control cannot be restored safely. |
| Safe signer compromise enables malicious issuance | Mitigated by approved design; assigned to deployment runbook; blocked on later evidence | Deployment operator; human Safe signers; repository maintainer | The exact cap bounds total issuance, while the 2-of-3 threshold, independent signer control, manual transaction review, incident procedure, and emergency finalization reduce controller risk. Exact signers and Safe state must pass the controller gate. |
| Authority issues notices to incorrect recipients | Assigned to operations pipeline; assigned to deployment runbook | Operations/data maintainer; deployment operator | The cap does not prove recipient correctness. Approved manifests, decoded calldata comparison, Safe simulation, batch review, and reconciliation are mandatory. |
| Distribution cap is derived incorrectly | Assigned to operations pipeline; blocked on later evidence | Operations/data maintainer; independent operations reviewer; repository maintainer | `distributionCap` must equal the exact number of unique addresses in the final approved production manifest. No discretionary margin or conservative upper bound is permitted. |
| Zero distribution cap is accepted | Mitigated by approved design; assigned to implementation testing | Contract implementer | Construction with a zero cap must revert. |
| Distribution cap is bypassed or misapplied | Assigned to implementation testing | Contract implementer; independent contract reviewer | Construction, boundary, fuzz, and sequence tests must prove `totalSupply + recipients.length <= distributionCap` for every success and atomic failure above it. |
| Accidental transferability | Mitigated by approved design; assigned to implementation testing | Contract implementer; independent contract reviewer | `transfer` and `transferFrom` always revert, including zero-value calls, and no internal or inherited movement path may be externally reachable. |
| Approval or allowance enables movement | Mitigated by approved design; assigned to implementation testing | Contract implementer; independent contract reviewer | `approve` always reverts, `allowance` always returns zero, and permit, allowance helpers, operator approvals, callbacks, and non-standard spender paths are absent. |
| Burning weakens direct-receipt and supply accounting | Mitigated by approved design; assigned to implementation testing | Contract implementer | Holder burn, authority burn, `burnFrom`, and burn-to-remove flows are absent. Tests and ABI review must confirm no burn surface. |
| Duplicate recipient increases balance or supply | Mitigated by approved design; assigned to implementation testing | Contract implementer | Duplicates within an array and previously notified recipients revert the complete call. No address may hold more than one unit. |
| Incorrect total-supply accounting | Assigned to implementation testing | Contract implementer | Supply starts at zero, increases by exactly one per unique successful recipient, never exceeds the cap, and remains unchanged on every failure and after finalization. |
| Invalid recipient is silently skipped | Mitigated by approved design; assigned to implementation testing | Contract implementer | Empty arrays, the zero address, duplicates, prior recipients, oversized arrays, and cap overflow use explicit complete-call reverts. |
| Partial batch execution creates ambiguous reconciliation | Mitigated by approved design; accepted architectural trade-off; assigned to implementation testing | Contract implementer; operations/data maintainer | All-or-nothing execution is mandatory. Tests must confirm no persistent balance, supply, or event remains after any revert; operations accepts the resulting batch friction. |
| Batch duplication or repeated transaction submission | Assigned to operations pipeline; assigned to deployment runbook | Operations/data maintainer; deployment operator | On-chain prior-recipient rejection is backed by numbered manifests, checksums, transaction-status checks, and reconciliation before another submission. |
| Gas-unsafe maximum batch constant | Assigned to implementation testing; blocked on later evidence | Contract implementer; independent contract reviewer; repository maintainer | Freeze the compile-time maximum only after the approved worst-case gas and calldata procedure selects a call using no more than 50% of the pinned target block gas limit, or a lower tooling or Safe bound. |
| Finalization fails to disable every issuance path | Mitigated by approved design; assigned to implementation testing | Contract implementer; independent contract reviewer | The one array distribution path and every possible internal issuance path must permanently fail after finalization. |
| Finalization reversal or authority restoration | Mitigated by approved design; assigned to implementation testing | Contract implementer; independent contract reviewer | No unfinalize, emergency mint, recovery distribution, upgrade, delegatecall, or replacement authority path exists. Sequence invariants must prove permanent closure. |
| Repeated finalization is silently accepted | Mitigated by approved design; assigned to implementation testing | Contract implementer | Repeated finalization must revert and leave state unchanged. |
| Reaching the cap is mistaken for finalization | Mitigated by approved design; assigned to implementation testing; assigned to deployment runbook | Contract implementer; deployment operator | Reaching the cap does not change the finalized state. Explicit human-approved finalization remains required. |
| Finalization below the cap obscures reconciliation | Assigned to deployment runbook | Deployment operator; repository maintainer | Below-cap finalization is technically valid only for a documented approved removal, operational stop, incident response, or campaign termination, with a written reconciliation explanation. |
| Unexpected external call, callback, hook, or recovery path | Mitigated by approved design; assigned to implementation testing | Contract implementer; independent contract reviewer | No REP or migration call, arbitrary call, callback, hook, oracle, bridge, token recovery helper, or ETH send may exist. Source, bytecode, ABI, and static analysis must confirm absence. |
| Upgrade, proxy, or delegatecall backdoor | Mitigated by approved design; assigned to implementation testing | Contract implementer; independent contract reviewer | Standalone immutable code is required. No proxy, upgrade state, delegatecall, module, or implementation indirection may exist. |
| Unexpected inherited callable surface | Mitigated by approved design; assigned to implementation testing | Contract implementer; independent contract reviewer | The candidate must not inherit OpenZeppelin ERC20, Ownable, Ownable2Step, AccessControl, Pausable, upgradeable contracts, proxies, or generalized token frameworks. ABI review must match the approved surface. |
| Fixed metadata differs from the approved values | Mitigated by approved design; assigned to implementation testing; assigned to deployment runbook | Contract implementer; deployment operator | Name, symbol, and decimals are compiled contract behavior, not constructor inputs. Tests, source review, bytecode reproduction, and post-deployment reads must match the exact approved values. |
| Issuance or finalization events are missing, duplicated, or incorrect | Assigned to implementation testing; assigned to deployment runbook | Contract implementer; deployment operator | Each successful recipient emits exactly one `Transfer(address(0), recipient, 1)` and finalization emits authority plus accurate final supply. Reverts persist no events. |
| An operator-supplied on-chain manifest hash creates a conflicting record | Mitigated by approved design; assigned to operations pipeline | Contract implementer; operations/data maintainer | No batch identifier or manifest hash is stored on-chain. Numbered manifests, recipient-array checksums, transaction hashes, decoded calldata, and events provide the reconciliation record. |
| Forced ETH affects contract logic | Mitigated by approved design; accepted architectural trade-off; assigned to implementation testing | Contract implementer; independent contract reviewer | No intended ETH receive or withdrawal path exists; logic must be independent of balance. Any exceptionally forced ETH is inert and permanently unrecoverable. |
| Compiler, dependency, or optimizer behavior differs from reviewed assumptions | Assigned to implementation testing; assigned to deployment runbook | Contract implementer; independent contract reviewer; deployment operator | Use exact pins, reproduce builds in a second environment, compare creation and runtime bytecode, review warnings and static-analysis findings, and freeze settings. If the candidate imports no OpenZeppelin code, remove that unused dependency in a separate reviewed `chore(deps)` commit. |
| Tooling assumes full ERC-20 compliance | Assigned to implementation testing; assigned to communications; blocked on later evidence | Contract implementer; communications maintainer | Test the ERC-20-shaped ABI and actual wallet behavior. Public material must explain disabled movement and approvals and must not call the artifact simply an ERC-20 token. |

## Recipient-data risk register

Recipient selection remains off-chain. These entries are approved evidence gates, not unresolved contract behavior.

| Risk | Classification | Owner | Approved treatment and release requirement |
| --- | --- | --- | --- |
| Incorrect REP contract address, version, universe, snapshot block, or chain | Assigned to operations pipeline; blocked on later evidence | Operations/data maintainer; independent operations reviewer; repository maintainer | Approve exact inputs and record chain ID, block number, block hash, timestamp, and queried contracts before recipient construction. |
| Incomplete holder discovery | Assigned to operations pipeline; blocked on later evidence | Operations/data maintainer; independent operations reviewer | Document and test the discovery method with fixtures and independently reproduce its output before the data gate passes. |
| Unavailable or inconsistent historical state | Assigned to operations pipeline; blocked on later evidence | Operations/data maintainer | Use a suitable archive source, pin the state, record the source category without secrets, and fail closed when required state cannot be verified. |
| Incorrect migration-status evaluation | Assigned to operations pipeline; blocked on later evidence | Operations/data maintainer; repository maintainer | Approve deterministic definitions for successful, partial, and incomplete migration before pipeline implementation or recipient generation. |
| Eligible holders are excluded or ineligible holders are included | Assigned to operations pipeline; blocked on later evidence | Operations/data maintainer; independent operations reviewer | Every inclusion and exclusion rule requires a stable identifier, deterministic implementation, tests, counts, evidence, and reason-coded reports. |
| Malformed, zero, duplicate, or non-canonical address | Assigned to operations pipeline | Operations/data maintainer | Schema validation, checksum handling, zero rejection, canonical sorting, and deterministic deduplication must be tested. |
| Exchange, protocol, contract, or custody address is misclassified | Assigned to operations pipeline; blocked on later evidence | Operations/data maintainer; repository maintainer | Classifications require evidence and explicit approval; bytecode presence alone cannot decide inclusion or exclusion. |
| Floating-point balance error changes eligibility | Mitigated by approved design; assigned to operations pipeline | Operations/data maintainer | Raw integer balances and `bigint` are mandatory; threshold and decimal-conversion fixtures must be tested. |
| Manual edits or non-deterministic generation change production artifacts | Mitigated by approved design; assigned to operations pipeline | Operations/data maintainer | Production manifests must be regenerated from reviewed inputs, deterministically ordered, checksummed, and independently reproducible. |
| Final manifest count and immutable cap differ | Assigned to operations pipeline; assigned to deployment runbook; blocked on later evidence | Operations/data maintainer; deployment operator; repository maintainer | The final unique recipient count must equal the constructor cap exactly. Any mismatch stops deployment and requires corrected artifacts or redeployment. |
| Checksum or manifest mismatch | Assigned to operations pipeline; assigned to deployment runbook | Operations/data maintainer; deployment operator | Verify input, recipient-array, batch, and cumulative checksums before signing and again during reconciliation. |
| Duplicate or invalid batch data reaches transaction preparation | Assigned to operations pipeline | Operations/data maintainer | Preflight validation rejects empty arrays, malformed or zero addresses, duplicates, prior recipients, oversized batches, and cap overflow. |
| Submitted calldata differs from the approved manifest | Assigned to deployment runbook | Deployment operator; human Safe signers | Before signing, compare decoded calldata, order, count, checksums, expected cumulative supply, and remaining cap against the approved batch. |

## Deployment and operational risk register

| Risk | Classification | Owner | Approved treatment and release requirement |
| --- | --- | --- | --- |
| Wrong network, Safe, target, constructor value, or bytecode | Assigned to deployment runbook; blocked on later evidence | Deployment operator; independent contract reviewer; repository maintainer | Use explicit chain checks, independently reviewed constructor arguments, exact source commit, bytecode hashes, unsigned artifacts, Safe simulation, and stop-on-mismatch controls. |
| Safe address, owners, threshold, or version is wrong | Assigned to deployment runbook; blocked on later evidence | Deployment operator; repository maintainer | Verify primary Safe state for the intended chain. Mainnet requires the approved dedicated 2-of-3 model; exact address, version, and signer identities remain gated evidence. |
| Safe signer control is not independent | Assigned to deployment runbook; blocked on later evidence | Deployment operator; repository maintainer | Document independent control and storage for all three signers. If two independent approvals cannot be reliably obtained, mainnet must not proceed. |
| Malicious or unnecessary Safe module | Mitigated by approved design; assigned to deployment runbook | Deployment operator; independent operations reviewer | The production Safe must have no enabled modules. Any module causes the controller gate to fail. |
| Unsafe custom guard or unreviewed fallback handler | Mitigated by approved design; assigned to deployment runbook; blocked on later evidence | Deployment operator; independent operations reviewer | The production Safe must have no custom guard, and its fallback handler must be identified and reviewed before rehearsal and mainnet preparation. |
| Signer key storage, backup, or incident response is inadequate | Assigned to deployment runbook; blocked on later evidence | Deployment operator; human Safe signers; repository maintainer | Document hardware-backed or comparably controlled storage, backups, custody changes, compromise response, and emergency-finalization procedure. |
| Controller is used for unrelated assets or protocol activity | Assigned to deployment runbook; blocked on later evidence | Deployment operator | Confirm dedicated-purpose use and review unrelated assets, modules, and transaction activity before release. |
| Dependency, compiler, or bytecode reproduction mismatch | Assigned to implementation testing; assigned to deployment runbook | Contract implementer; independent contract reviewer; deployment operator | Reproduce the candidate in a second environment and stop if compiler settings, dependencies, creation bytecode, or runtime bytecode differ. |
| Batch exceeds gas, calldata, tooling, or Safe limits | Assigned to implementation testing; blocked on later evidence | Contract implementer; independent contract reviewer; repository maintainer | Benchmark entirely new recipients and all required boundary/revert scenarios at a pinned target block. Freeze the lower safe bound and publish the exact margin. |
| Repeated, skipped, reordered, or wrong batch | Assigned to operations pipeline; assigned to deployment runbook | Operations/data maintainer; deployment operator | Use numbered immutable manifests, checksums, human review, transaction status, and reconciliation before advancing. |
| Gas spike, nonce conflict, or transaction replacement changes execution | Assigned to deployment runbook | Deployment operator; human Safe signers | Apply documented fee, nonce, replacement, monitoring, and stop procedures under human control. |
| Incomplete reconciliation before the next batch | Assigned to deployment runbook | Deployment operator; independent operations reviewer | Reconcile transaction, decoded calldata, issuance events, balances, cumulative supply, checksums, manifest count, and cap headroom before continuing. |
| Premature normal finalization | Assigned to deployment runbook | Deployment operator; repository maintainer; human Safe signers | Require all intended batches confirmed and reconciled, no unresolved incident, at least 24 hours after the last normal batch, independent reconciliation review, and human approval. |
| Emergency finalization is delayed during an active incident | Assigned to deployment runbook | Deployment operator; repository maintainer; human Safe signers | Maintain a reviewed procedure for immediate finalization on credible controller compromise, manifest misuse, unexpected issuance, incorrect preparation, or another active stop condition. |
| Failure to finalize leaves issuance authority active | Assigned to deployment runbook | Deployment operator; repository maintainer; human Safe signers | Track finalization as an open release obligation until confirmed; assign incident ownership and verify permanent closure afterward. |
| Final supply does not reconcile with the manifest and cap | Assigned to deployment runbook | Deployment operator; independent operations reviewer; repository maintainer | Normally final supply must equal the approved manifest count and cap. Any below-cap exception requires written approval and reconciliation evidence. |
| Source verification or runtime bytecode differs from the candidate | Assigned to deployment runbook | Deployment operator; independent contract reviewer | Compare deployed runtime code and verified source to the frozen candidate and stop public rollout on any mismatch. |
| Production secret is exposed to an agent or repository | Mitigated by approved design; assigned to deployment runbook | Deployment operator; human Safe signers | Agents may not request, inspect, store, or use keys and may not operate the Safe. No secret may enter repository files or logs. |
| Final Sepolia rehearsal does not match mainnet control assumptions | Assigned to deployment runbook; blocked on later evidence | Deployment operator; repository maintainer | The final rehearsal must use the same dedicated 2-of-3 control model, review flow, batch checks, finalization procedure, and human signing assumptions intended for mainnet. Test keys must not be reused. |
| Agent signs, submits, broadcasts, or operates the Safe | Mitigated by approved design; assigned to deployment runbook | Deployment operator; human Safe signers | All production signing and submission remain human-only. Agents may prepare and review unsigned material but must never operate the Safe or broadcast. |

## Communications and scam risk register

| Risk | Classification | Owner | Approved treatment and release requirement |
| --- | --- | --- | --- |
| Fake tokens use identical name and symbol | Accepted architectural trade-off; assigned to communications | Communications maintainer | Publish and repeatedly verify the canonical contract address through the official Augur page; state that matching metadata proves nothing. |
| Fake deployments copy the full interface, source, or branding | Accepted architectural trade-off; assigned to communications | Communications maintainer | Treat only the independently verified contract address and reviewed bytecode as canonical identity. |
| Canonical-address substitution appears in public materials | Assigned to communications; assigned to deployment runbook | Communications maintainer; independent communications reviewer | Independently verify chain, address, and source-verification link before publication and use controlled correction procedures. |
| Public communications differ across channels | Assigned to communications | Communications maintainer; independent communications reviewer | Use the approved core message everywhere; the official Augur page is canonical and corrections propagate from it. |
| Holders mistake the notice for REP, migrated REP, or a claim | Assigned to communications; blocked on later evidence | Communications maintainer | Use notice-only, no-value, no-rights, no-migration-effect language and review actual wallet presentation during Sepolia. |
| Holders believe the notice has economic value | Assigned to communications | Communications maintainer | Avoid reward, redemption, price, claim, ticker, replacement-token, staking, or governance implications. |
| Fake liquidity or price data creates apparent legitimacy | Assigned to communications; blocked on later evidence | Communications maintainer | Warn that liquidity and third-party pricing do not indicate authenticity or value; record observed price metadata in wallet testing. |
| Wallet or explorer implies transferability or approvals | Assigned to implementation testing; assigned to communications; blocked on later evidence | Contract implementer; communications maintainer | Test transfer and approval affordances and error presentation across the required Sepolia matrix; explain that the selectors always reject. |
| Interface is described as fully ERC-20 compliant | Assigned to communications | Communications maintainer; independent communications reviewer | Use “ERC-20-shaped” and always explain disabled movement, approvals, permit, and burn behavior. |
| Wallets hide or spam-filter the notice | Accepted architectural trade-off; assigned to implementation testing; blocked on later evidence | Communications maintainer; deployment operator | Test the mandatory product categories, document visibility and spam behavior, and never promise display. |
| Wallets truncate or misrender metadata or balances | Assigned to implementation testing; blocked on later evidence | Communications maintainer; deployment operator | Record name, symbol, decimals, balance rendering, manual import, and post-finalization behavior across the approved matrix. |
| Users follow a malicious wallet-supplied link | Assigned to communications | Communications maintainer | Do not store a migration URL in contract metadata; tell users to navigate independently to the official Augur page. |
| Approval, signature, transfer, burn, swap, bridge, claim, or wallet-connect instructions resemble a drainer | Mitigated by approved design; assigned to communications | Communications maintainer; independent communications reviewer | The product requires no recipient interaction, and official material must never request any of these actions because of the notice. |
| Wallet visibility is treated as guaranteed | Accepted architectural trade-off; assigned to communications | Communications maintainer | Describe visibility and awareness as hypotheses and publish observed limitations. |
| Canonical page or URL is not ready or independently reviewed | Assigned to communications; blocked on later evidence | Communications maintainer; independent communications reviewer; repository maintainer | The exact URL is approved only after the page exists and contains the verified address, chain, source link, meaning, safety warning, and migration information. It blocks public Sepolia communication and mainnet. |
| Controller is described as organizationally controlled without evidence | Assigned to communications; assigned to deployment runbook | Communications maintainer; deployment operator | State only reviewed ownership, threshold, and signer facts; do not invent an organization, signer, or address. |
| Independent review is mislabeled as a formal audit | Assigned to communications | Communications maintainer; repository maintainer | Describe the required reviews accurately and retain the “not audited” status unless a formal audit actually occurs. |

## Deferred evidence gates

These items are `DEFERRED WITH GATE`. They do not leave contract behavior open.

| Deferred item | Why it cannot responsibly be fixed now | Owner | Required evidence and exact decision rule | Resolution phase and blocked gate |
| --- | --- | --- | --- | --- |
| Exact maximum batch size | It depends on candidate bytecode, calldata, target-chain block conditions, tooling, and Safe simulation. | Contract implementer proposes; independent contract reviewer reviews; repository maintainer freezes | Measure entirely new recipients; one, typical, proposed maximum, duplicate, cap-boundary, and revert scenarios; include calldata; use a pinned target block gas limit. The worst-case successful call must use at most 50% of that limit, or the lower Safe/tooling bound. | Implementation and pinned-fork gas work; blocks candidate freeze and the Contract gate. |
| Exact mainnet Safe address, Safe version, and signer identities | No production controller has been configured or reviewed in this documentation phase. | Deployment operator; human Safe signers; repository maintainer | Verify primary chain state for a dedicated 2-of-3 Safe with three independently controlled signers, no modules, no custom guard, reviewed fallback handler, documented custody and incident procedures, and a matching final Sepolia rehearsal. Otherwise mainnet does not proceed. | Testnet and mainnet preparation; blocks Testnet completion and Mainnet preparation. |
| Exact REP inputs, migration definition, snapshot, and classification rules | They depend on approved campaign scope and reproducible historical state. | Operations/data maintainer; independent operations reviewer; repository maintainer | Approve chain, REP versions and addresses, migration semantics, threshold, snapshot block/hash, discovery method, exclusions, and evidence. Fail closed on unavailable or inconsistent state. | Snapshot tooling and pinned-fork phases; blocks the Data gate. |
| Exact recipient set and exact cap number | They depend on the reviewed output of the future recipient pipeline. | Operations/data maintainer; independent operations reviewer; repository maintainer | Produce a deterministic, checksummed, independently reproduced final manifest. The cap must equal its unique-address count exactly and must be nonzero. | Data review before candidate deployment; blocks Data and Mainnet-preparation gates. |
| Canary list and stop conditions | They depend on the final manifest, gas evidence, controller readiness, and incident plan. | Operations/data maintainer; deployment operator; repository maintainer | Approve explicit recipients, size, cumulative supply expectations, observation criteria, and stop triggers before unsigned canary artifacts are frozen. | Mainnet preparation; blocks the Mainnet-preparation gate. |
| Exact canonical page URL | The page does not yet exist and cannot be verified in advance. | Communications maintainer; independent communications reviewer; repository maintainer | The page must publish the verified address and chain, source-verification link, notice meaning, safety warnings, and migration information. Approve it before public Sepolia communication or mainnet. | Communications preparation and Testnet; blocks public Testnet communication and Mainnet preparation. |
| Exact wallet-product matrix | Product relevance and spam behavior change over time. | Communications maintainer; deployment operator; repository maintainer | Select immediately before Sepolia at least two browser wallets, two mobile wallets, one portfolio tracker, one explorer, one spam-filtering interface, and one manual-import interface; execute and record every required observation. | Sepolia phase; blocks the Testnet gate. |
| Exact deployment commit and bytecode | No implementation candidate exists yet. | Contract implementer; independent contract reviewer; deployment operator; repository maintainer | Freeze the exact reviewed commit, compiler and optimizer settings, dependency pins, constructor arguments, creation/runtime hashes, independent reproduction, and source-verification plan. | Candidate review and mainnet preparation; blocks Contract review and Mainnet preparation. |

## Approval boundary

The approved architecture and treatment assignments are sufficient to begin minimal contract implementation planning once the product specification and frozen acceptance criteria are committed consistently.

They are not evidence that:

- the future contract has been implemented correctly;
- the tests are complete;
- recipient data is correct;
- the Safe is configured correctly;
- wallet display is useful;
- independent review has occurred;
- release gates have passed;
- the project is ready for Sepolia or mainnet;
- vulnerabilities are absent.

Every later gate remains subject to human maintainer approval.
