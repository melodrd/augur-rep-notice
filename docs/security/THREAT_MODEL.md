# Threat Model

Status: Approved for implementation

Revision date: 2026-07-16

This threat model covers the approved `REP MIGRATION ALERT` contract architecture, recipient-data responsibilities, the dedicated EOA authority model, deployment operations, and public communications. It is not an independent security audit and does not establish production readiness.

## 1. Security objectives

- Preserve the alert-only, non-economic meaning.
- Prevent unauthorized, duplicate, partial, or over-cap issuance.
- Keep balances binary and total supply equal to unique successful recipients.
- Prevent transfer, approval, permit, burn, recovery, upgrade, and authority-transfer paths.
- Make finalization explicit, irreversible, and comprehensive.
- Keep REP, migration contracts, ETH handling, and arbitrary external calls outside the contract.
- Make recipient construction, transaction preparation, and reconciliation deterministic and reviewable.
- Prevent private-key handling by agents or repository tooling.
- Avoid communications that encourage unsafe wallet interaction.
- Treat third-party presentation as untrusted and visibility as unguaranteed.

## 2. Trust boundaries

The future contract is constrained to:

- fixed metadata: `REP MIGRATION ALERT`, `CHECKREP`, and `0` decimals;
- one standalone, non-upgradeable implementation;
- zero initial supply and one unit per unique recipient;
- one atomic `distribute(address[] recipients)` path;
- one nonzero constructor-supplied immutable authority;
- one nonzero immutable cap equal to the final approved manifest count;
- one dedicated project-owner EOA used deliberately as both deployer and authority;
- explicit irreversible finalization;
- no REP interaction, arbitrary external call, intended ETH path, recovery path, proxy, or upgrade.

Off-chain systems and humans remain responsible for recipient correctness, unsigned artifact preparation, simulation, signing, reconciliation, incident response, and publication of the canonical contract address.

## 3. Accepted trade-offs

| Trade-off | Consequence | Required control |
| --- | --- | --- |
| Immutable authority | A wrong, lost, or irrecoverably compromised authority cannot be replaced | Verify the exact checksummed EOA and constructor data; abandon or redeploy when necessary |
| Dedicated single EOA | One project owner provides less authorization redundancy than multi-party control | Dedicated use, hardware-backed signing where available, manual transaction review, limited funding, and independent artifact review |
| Exact immutable cap | A material recipient-set change after deployment can require redeployment | Freeze and checksum the final manifest before deployment |
| Strict atomic batches | One invalid recipient reverts the complete batch | Deterministic prevalidation, simulation, and reconciliation |
| Permanent receipt | Recipients cannot move or burn the balance | Keep transfer and burn paths absent; explain that interface hiding requires no on-chain action |
| Copyable metadata | Fraudulent deployments can copy name, symbol, ABI, source, and branding | Authenticate only by the checksummed contract address published through official Augur sources |
| Unrecoverable forced ETH | Exceptionally forced ETH may remain permanently | Keep logic balance-independent and add no withdrawal authority |
| Unguaranteed third-party display | Interfaces may hide, truncate, misclassify, or misrender the alert | Make no visibility promise and keep official Augur information canonical |

## 4. Contract risks

| Threat | Consequence | Mitigation | Remaining risk | Release control |
| --- | --- | --- | --- | --- |
| Unauthorized issuance | Balances or supply change outside the approved authority path | One immutable authority and one issuance function | Implementation error could expose another path | Unit, fuzz, invariant, ABI, source, bytecode, and static-analysis review |
| Hidden deployer privilege | Deployment account retains an unintended power | Authority comes only from the explicit constructor argument | A constructor or authorization bug could violate the distinction | Test an unrelated deployer and verify it receives no privilege |
| Zero or wrong authority | Distribution and finalization fail or are controlled by the wrong address | Reject zero authority; verify constructor data and deployed read | A nonzero but incorrect address is unrecoverable | Independent address, chain, constructor, and simulation review |
| Authority compromise | Attacker distributes to incorrect recipients or finalizes early | Dedicated EOA controls, manual review, limited ETH, immutable cap | The cap limits quantity, not recipient correctness or premature finalization | EOA gate, transaction simulation, monitoring, stop procedure, and emergency-finalization preparation |
| Authority loss | Further distribution and finalization become impossible | Hardware-backed signing preferred; backup and loss assumptions documented | No recovery or replacement exists | Do not deploy until the operating model is reviewed; abandon deployment if control is lost |
| Duplicate issuance | A recipient balance or supply exceeds one | Reject prior recipients and duplicates within each array | An implementation defect could break binary accounting | Boundary, fuzz, and invariant tests |
| Partial batch execution | Manifests and state diverge | Strict all-or-nothing validation and revert behavior | One bad entry blocks the batch | Atomic rollback tests and deterministic prevalidation |
| Cap bypass | Total issuance exceeds the approved recipient count | Immutable exact cap and pre-effect cap check | Incorrect implementation or cap derivation remains possible | Cap-boundary tests, manifest-count review, and deployed-read verification |
| Zero cap accepted | Unusable or inconsistent deployment | Constructor rejects zero | None beyond implementation correctness | Constructor test and deployment simulation |
| Gas-unsafe batch maximum | Transactions fail or approach block limits | Compile-time maximum based on worst-case measured gas and calldata | Network or signing constraints may be stricter | Pinned benchmark, 50% block-gas rule, lower operational bound, independent review |
| Accidental transferability | Alert units become tradable or movable | `transfer` and `transferFrom` always revert; no internal movement path | Tooling may still display transfer controls | Positive and zero-value tests, ABI review, and public warning |
| Approval or permit path | Phishing-sensitive spending authority appears | `approve` reverts; allowance is zero; permit and helpers are absent | Interfaces may still display approval controls | Tests, ABI review, and messaging |
| Burn path | Receipt and supply reconciliation can be altered | No holder, authority, or delegated burn | Recipients cannot remove the on-chain balance | ABI and source review |
| Finalization bypass or reversal | Issuance continues after shutdown | One irreversible state transition; no recovery, upgrade, or alternate issuance | Implementation error remains possible | Sequence invariants, source and bytecode review |
| Premature finalization | Intended recipients cannot be issued later | Manual review and reconciliation before signing | Compromised authority can still finalize early | EOA transaction review and incident controls |
| Repeated finalization accepted | Operational state becomes ambiguous | Repeated finalization reverts | None beyond implementation correctness | Unit and invariant tests |
| Unexpected external interaction | Reentrancy, custody, or dependency risk appears | No REP, migration, arbitrary-call, callback, oracle, bridge, or recovery logic | Compiler or source mismatch could introduce behavior | Source, ABI, bytecode, and static-analysis review |
| Proxy, upgrade, or delegatecall | Reviewed behavior can change or finalization can be bypassed | Standalone immutable code | Deployment of wrong bytecode remains possible | Independent build reproduction and runtime-code comparison |
| ETH receive or withdrawal path | Asset custody and recovery authority are introduced | No payable, receive, fallback, send, or withdrawal path | Forced ETH can remain inert | Source and bytecode review; balance-independent logic tests |
| Metadata differs from approval | Users see the wrong name or symbol | Compile-time fixed values | Third parties may display stale or incorrect metadata | Tests, source review, deployed reads, and correction process |
| Incorrect events | Indexing and reconciliation become unreliable | Exact issuance and finalization events | Third-party indexers may interpret them differently | Event tests and post-transaction reconciliation |

## 5. EOA and signing risks

| Threat | Consequence | Mitigation | Remaining risk | Release control |
| --- | --- | --- | --- | --- |
| Malware, browser compromise, or clipboard substitution | Wrong target, address, or calldata is signed | Hardware-backed signing preferred; decode independently; compare checksummed data | A compromised review device can mislead the operator | Use reviewed artifacts, simulation, and a separate verification view where practical |
| Compromised deployment environment | Wrong bytecode or constructor data is prepared | Reproducible builds and independent artifact review | Both environments could share a defect | Compare source commit, settings, creation hash, runtime hash, and constructor encoding |
| Wrong-chain signing | Valid transaction executes on an unintended network | Review chain ID and network immediately before signing | User-interface mistakes remain possible | Chain-specific unsigned artifacts and manual chain confirmation |
| Incorrect target, value, or calldata | Deployment, distribution, or finalization does the wrong thing | Decode every transaction and compare expected state change | Human review can fail | Simulation and independent unsigned-artifact review |
| Nonce error or replacement mistake | Transaction order changes, stalls, or executes unexpectedly | Review nonce and pending transactions; document replacement procedure | Public mempool and fee conditions remain variable | Stop on unexplained nonce state and reconcile before continuing |
| Excessive ETH funding | Compromise causes a larger ETH loss | Hold only reasonably required operational ETH | Fees may change and unsolicited ETH may arrive | Record funding rationale and review balance before each stage |
| Unrelated EOA activity | Transaction history, approvals, assets, or compromise surface become harder to review | Dedicated campaign use; no intentional unrelated tokens, positions, or DeFi activity | Unsolicited dust cannot be prevented | Review and document unexpected balances or activity |
| Unsafe key backup | Key is exposed or permanently lost | Document storage and backup model without recording secrets | Backup security cannot be proven by repository checks | Project-owner review before release |
| Mainnet key reused on Sepolia | Test activity exposes the production authority | Separate Sepolia-only key | Operational mistakes remain possible | Record non-reuse confirmation; never inspect the key |
| Secret enters files, history, logs, or tooling | Private authority is compromised | Never store or request secret material; agents handle unsigned data only | Human error remains possible | Secret scan, clean repository review, and incident response |
| Agent or automation signs or broadcasts | Human control boundary is bypassed | Agents may prepare unsigned material only | Tool misuse remains possible outside repository controls | Explicit human-only signing and broadcast gate |

## 6. Recipient-data risks

| Threat | Consequence | Mitigation | Remaining risk | Release control |
| --- | --- | --- | --- | --- |
| Wrong REP contract, universe, chain, or snapshot | Recipient population is incorrect | Approve exact primary-source inputs and immutable block metadata | Historical assumptions may still be incomplete | Independent data-method review and reproduction |
| Incomplete holder discovery | Eligible addresses are omitted | Document and test the discovery method | Unknown historical edge cases may remain | Fixtures, counts, and independent output comparison |
| Unavailable historical state | Results are incomplete or non-reproducible | Use suitable archive access and fail closed | Provider behavior may differ | Record source category, block hash, and reproduction evidence |
| Incorrect migration-status definition | Migrated or unmigrated holders are misclassified | Freeze deterministic semantics before implementation | Product-policy ambiguity may remain until approved | Data gate blocks pipeline use |
| Incorrect threshold or balance math | Eligibility changes | Use raw integers and `bigint`; apply decimals explicitly | Bad source data remains possible | Boundary fixtures and reconciliation |
| Silent exclusion | Addresses disappear without explanation | Stable reason codes, affected-address reports, and counts | Manual policy may still be disputed | Independent exclusions review |
| Address normalization or duplicate error | Invalid or repeated recipients reach batches | Validate, checksum, reject zero, deduplicate, and sort canonically | Implementation defects remain possible | Schema and deterministic-output tests |
| Contract, exchange, or custody misclassification | Wrong inclusion or exclusion | Require evidence; do not decide from bytecode alone | Classification evidence can be stale | Explicit human approval and recorded rationale |
| Manual manifest edit | Production artifacts diverge from reviewed inputs | Regenerate deterministic outputs and checksums | Operators may select the wrong artifact | Hash verification before every transaction |
| Manifest count differs from cap | Deployment cannot complete correctly or has wrong headroom | Exact equality between unique count and immutable cap | A late recipient change requires redeployment | Independent manifest and constructor review |
| Calldata differs from manifest | Wrong recipients are issued | Decode arrays, compare order/count/checksum, and simulate | Human comparison can fail | Independent unsigned-artifact review and post-transaction reconciliation |

## 7. Deployment and operational risks

| Threat | Consequence | Mitigation | Remaining risk | Release control |
| --- | --- | --- | --- | --- |
| Wrong network, bytecode, constructor value, or EOA | Incorrect or irrecoverable deployment | Exact chain, hashes, arguments, checksummed address, and simulation | Human error remains possible | Stop on any mismatch; independent deployment-artifact review |
| Deployer and authority relationship misunderstood | Code derives authority from deployer or operators expect a handoff | Constructor-supplied authority remains explicit; production uses the same address deliberately | Documentation can still be misread | Acceptance test with unrelated deployer and deployment checklist |
| Batch repeated, skipped, reordered, or substituted | Recipients or supply diverge from plan | Numbered immutable manifests and per-batch reconciliation | Transaction replacement can complicate state | Confirm transaction status before advancing |
| Gas spike or transaction replacement | Execution is delayed or altered | Fee, nonce, replacement, and monitoring procedure | Chain conditions remain unpredictable | Human stop conditions and reconciliation |
| Incomplete reconciliation | Later batches compound an error | Reconcile calldata, events, balances, supply, and headroom before continuing | RPC or indexing lag may delay evidence | Do not advance until direct state checks agree |
| Failure to finalize | Authority remains active | Track finalization as an open obligation | Key loss can make closure impossible | Finalization readiness review and incident ownership |
| Emergency finalization delayed | Attacker retains remaining issuance power | Prepare and simulate finalization calldata | Full compromise may remove legitimate control | Immediate human incident decision while control remains |
| Source verification or runtime mismatch | Public verification points to different code | Compare deployed runtime with frozen candidate | Explorer processing may be delayed | Stop public rollout until direct bytecode checks pass |

## 8. Communications and third-party risks

Etherscan is the only third-party metadata surface currently in scope. Other wallet, tracker, token-list, and market-data work is deferred and does not block a current release gate.

| Threat | Consequence | Mitigation | Remaining risk | Release control |
| --- | --- | --- | --- | --- |
| Holders mistake the alert for REP, replacement REP, or a claim | Unsafe interaction or economic confusion | Canonical non-economic wording and no-interaction instructions | Metadata alone cannot convey the full message | Independent communications review |
| `CHECKREP` is treated as a transaction instruction | Users approve, transfer, claim, sign, or connect | Explicitly define it as checking official information independently | Third-party interfaces may omit context | Use the canonical core message on official surfaces |
| Fake deployment copies metadata or branding | Users trust an attacker contract | Publish only the checksummed canonical address through official Augur sources | Copies can remain visually identical | Address verification and correction procedure |
| Incorrect official contract address is published | Users verify the wrong deployment | Independently verify chain, transaction, bytecode, and address | Compromised publication channels remain possible | Canonical-page review and incident process |
| Third-party price or liquidity data implies value | Alert appears economically legitimate | State that price, liquidity, or listings create no authenticity or value | Third parties control their own presentation | Communications warning |
| Etherscan metadata, link, description, or logo is wrong | Explorer users receive misleading information | Review source data, preserve submissions, and correct through the current official process | Etherscan controls display, timing, and review outcome | Post-deployment evidence and correction record |
| Etherscan source verification is incomplete or wrong | ABI and source presentation cannot be trusted | Reproduce compiler settings and compare runtime bytecode directly | Explorer verification can be delayed | Do not rely on explorer status alone |
| Wallets or trackers hide, truncate, spam-filter, or misrender the alert | Recipients may not see or understand it | Make no automatic-visibility claim; retain official Augur publication | Broader behavior remains untested in the current scope | Deferred for a later specification and operations review |
| Malicious wallet-supplied link | User visits a phishing site | No URL in contract metadata; users navigate independently to official Augur sources | Interfaces may still add third-party links | Canonical messaging and incident correction |
| Independent review is described as an audit | Users overestimate assurance | Use accurate review language | Public summaries may simplify status | Keep “not audited” status until a formal audit occurs |

## 9. Deferred evidence

The following remain release-gated:

- exact checksummed production EOA and intended chain;
- non-secret EOA storage, hardware-signing, backup, loss, funding, and unrelated-activity evidence;
- REP sources, migration definition, snapshot, thresholds, exclusions, and recipient manifest;
- exact immutable cap derived from the final manifest;
- maximum batch size and benchmark;
- official Augur page URL;
- canary sequence and stop conditions;
- deployment commit, compiler settings, constructor arguments, and bytecode hashes;
- incident-response ownership and finalization procedure.

Broader wallet, portfolio-tracker, token-list, CoinGecko, CoinMarketCap, and market-data work is not a current release gate. It is deferred for a later specification and operations review.

## 10. Release boundary

The approved treatments are sufficient to begin minimal contract implementation. They do not prove that:

- the implementation is correct;
- recipient data is correct;
- the production EOA is safely controlled;
- independent review has occurred;
- Etherscan or another interface will display correct information;
- Sepolia or mainnet release gates have passed;
- vulnerabilities are absent.

This revision does not authorize RPC access, wallet or key handling, deployment, signing, submission, or broadcast.
