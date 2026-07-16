# Deployment Runbook

Status: Approved design-stage controls; non-operational

This runbook defines future human-controlled deployment, distribution, reconciliation, and finalization checks for `REP MIGRATION ALERT`. It does not authorize RPC access, wallet or key handling, deployment, signing, submission, or broadcast.

Agents may prepare unsigned artifacts and simulations only when an explicit task authorizes that work. Agents must never access the authority private key, sign, submit, or broadcast.

## 1. Stop conditions

Stop preparation or execution when:

- a required approval or independent review is missing;
- source, compiler settings, dependencies, bytecode, ABI, metadata, constructor data, chain, authority, cap, manifest, calldata, or checksum differs from the reviewed artifact;
- the final manifest count does not equal the immutable cap;
- historical state is unavailable or inconsistent;
- gas or calldata evidence does not support the frozen maximum batch size;
- the dedicated EOA address, intended chain, storage model, funding, or activity differs from the reviewed operating model;
- a simulation, test, static-analysis check, source-verification check, or reconciliation check fails;
- an unexplained transaction, nonce, replacement, event, balance, or supply change appears;
- key compromise, malware, manifest misuse, incorrect transaction preparation, or another incident is suspected;
- an action would expose secret material to an agent, repository file, script, shell history, documentation, log, or environment file.

Do not work around a stop condition. Preserve the evidence and return the decision to the responsible human.

## 2. Release prerequisites

- [ ] Product specification matches the candidate
- [ ] Threat model and frozen acceptance criteria match the candidate
- [ ] Architecture decisions match the candidate
- [ ] Independent contract review is complete
- [ ] Independent recipient and operations review is complete
- [ ] Independent communications review is complete
- [ ] Independent deployment-artifact review is complete
- [ ] Findings are resolved or explicitly accepted
- [ ] Evidence-dependent parameters are resolved under their documented gates
- [ ] Human maintainers approve the intended release stage

## 3. Candidate freeze

- [ ] Exact source commit and candidate tag recorded
- [ ] Solidity compiler, optimizer, EVM, and IR settings recorded
- [ ] Dependency tags and immutable commits recorded
- [ ] Candidate reproduced in a second environment
- [ ] Creation bytecode hash recorded
- [ ] Runtime bytecode hash recorded
- [ ] ABI recorded and compared with the approved public surface
- [ ] Constructor arguments and encoded constructor data recorded
- [ ] Source-verification inputs prepared
- [ ] Formatting, build, size, unit, fuzz, invariant, fork, gas, coverage, and static-analysis results reviewed
- [ ] Compiler warnings and static-analysis findings classified
- [ ] No unresolved mismatch remains

## 4. Contract conformance

- [ ] Candidate is standalone and non-upgradeable
- [ ] No prohibited token, ownership, role, proxy, pausing, or generalized framework inheritance exists
- [ ] Exactly one privileged array-based distribution path exists
- [ ] Authority is one nonzero constructor-supplied immutable address
- [ ] No hidden deployer permission, owner, role, handoff, successor, recovery, or secondary administrator exists
- [ ] Immutable cap is nonzero and enforced
- [ ] Transfers, transfer-from, approvals, permits, allowance helpers, operator approvals, and burns are disabled or absent as specified
- [ ] Finalization is explicit, one-time, irreversible, and closes every issuance path
- [ ] Events and public reads match the specification
- [ ] No REP, migration-contract, arbitrary-call, callback, hook, payable, receive, fallback, withdrawal, recovery, proxy, upgrade, or delegatecall path exists
- [ ] Contract behavior is independent of ETH balance

## 5. Metadata

- [ ] Name is compiled as `REP MIGRATION ALERT`
- [ ] Symbol is compiled as `CHECKREP`
- [ ] Decimals are compiled as `0`
- [ ] Constructor accepts no configurable metadata
- [ ] Initial total supply is zero
- [ ] Constructor issues no alert units
- [ ] Deployer receives no inventory

## 6. Recipient manifest and cap

- [ ] Final recipient manifest is approved
- [ ] Manifest contains only validated, nonzero, unique, canonically ordered addresses
- [ ] Snapshot, eligibility, exclusion, and reason-code evidence are approved
- [ ] JSON, CSV, summary, and checksums are recorded
- [ ] Output was regenerated from reviewed inputs without manual production edits
- [ ] Independent reproduction produced the same recipients and checksums
- [ ] Immutable `distributionCap` equals the exact unique-address count
- [ ] Cap is nonzero
- [ ] Cap-boundary success and cap-overflow atomic failure are demonstrated
- [ ] No discretionary margin or unused issuance headroom was added
- [ ] A material recipient change after deployment is treated as a redeployment decision

## 7. Maximum batch-size gate

- [ ] Worst-case gas uses entirely new recipients
- [ ] Calldata cost is included
- [ ] Measurements cover `1`, `10`, `25`, `50`, `100`, `200`, and `500` when feasible
- [ ] Measurements cover the proposed maximum, duplicate, prior-recipient, cap-boundary, cap-overflow, and other revert cases
- [ ] Pinned target-chain block gas limit is recorded
- [ ] Worst-case successful use is no more than 50% of that limit
- [ ] A lower maximum is used when execution, calldata, transaction tooling, or signing workflow is stricter
- [ ] Benchmark records block conditions, calldata, batch gas, per-recipient gas, chosen constant, and margin
- [ ] Contract enforces the frozen maximum
- [ ] Independent reviewer approved the benchmark and constant

## 8. Dedicated EOA gate

The production authority is one dedicated EOA controlled by the project owner. The exact address is deferred until deployment preparation. Secret material must never be requested or recorded.

- [ ] Exact checksummed EOA address recorded
- [ ] Intended chain recorded
- [ ] Same address is intentionally used as deployer and constructor authority
- [ ] Deployment is understood to grant no privilege by itself
- [ ] Constructor authority is supplied explicitly
- [ ] EOA is controlled by the project owner
- [ ] EOA is dedicated to this campaign and is not an everyday wallet
- [ ] No intentional unrelated token balances or protocol positions are held
- [ ] No unrelated DeFi or protocol activity exists
- [ ] Unexpected balances or activity are reviewed and documented
- [ ] Only reasonably required operational ETH is funded
- [ ] Hardware-backed signing status is recorded; any exception is reviewed
- [ ] Storage model is documented without exposing secrets
- [ ] Backup and permanent-loss assumptions are documented without exposing secrets
- [ ] Mainnet key is not reused for Sepolia
- [ ] No private key, seed phrase, recovery phrase, raw keystore, or secret environment value is stored in project files, scripts, shell history, documentation, or logs
- [ ] No agent or automated tool has key access
- [ ] Project owner understands that key loss can prevent distribution and finalization
- [ ] Project owner understands that compromise can cause wrong-recipient issuance within the remaining cap or premature finalization
- [ ] Project owner accepts the single-person authorization model

## 9. Deployment and constructor review

- [ ] Network and chain ID confirmed
- [ ] Deployment transaction type confirmed
- [ ] Deployer checksum independently reviewed
- [ ] Deployer and authority equality is deliberate and documented
- [ ] An unrelated deployer would receive no implicit permission
- [ ] No post-deployment authority handoff is planned
- [ ] Constructor authority equals the selected EOA
- [ ] Constructor authority is nonzero
- [ ] Constructor cap equals the approved manifest count
- [ ] Constructor data is independently decoded
- [ ] Deployment target, value, creation data, nonce, and expected state change are reviewed
- [ ] Deployment simulation confirms metadata, authority, cap, zero supply, and unfinalized state

## 10. Sepolia rehearsal

- [ ] Sepolia work is explicitly authorized
- [ ] A separate Sepolia-only dedicated EOA and key are used
- [ ] Exact candidate bytecode is deployed and source-verified
- [ ] Metadata, constructor, authority, and cap semantics match the candidate
- [ ] One-address canary and representative batches are exercised
- [ ] Empty, zero, duplicate, prior-recipient, oversized, unauthorized, finalized, and cap-overflow failures are exercised
- [ ] Batch calldata, events, balances, supply, and cap headroom reconcile
- [ ] Normal and emergency finalization procedures are rehearsed
- [ ] Repeated finalization and post-finalization distribution fail
- [ ] Existing balances remain after finalization
- [ ] Rehearsal findings are independently reviewed
- [ ] Candidate changes after rehearsal require a new rehearsal

## 11. Communications and Etherscan gate

- [ ] Canonical alert language in [`docs/communications/MESSAGING.md`](../communications/MESSAGING.md) is approved
- [ ] Exact official Augur page URL is approved
- [ ] Official page states chain, verified address, source-verification link, alert meaning, safety warning, and migration information
- [ ] Contract address is published only after independent chain, address, bytecode, and source checks
- [ ] Communications do not request approval, transfer, swap, burn, bridge, claim, signature, or wallet connection
- [ ] Communications explain `CHECKREP` as checking official information independently
- [ ] Communications warn that copied metadata, price, liquidity, and third-party display do not establish authenticity or value
- [ ] Correction and incident owners are assigned
- [ ] Etherscan work follows [`ETHERSCAN_RUNBOOK.md`](ETHERSCAN_RUNBOOK.md)
- [ ] Exact current Etherscan instructions are reviewed after deployment
- [ ] Source, ABI, metadata, website, description, logo, submission, response, and correction evidence is recorded as applicable
- [ ] No Etherscan approval or display guarantee is made
- [ ] No current gate requires browser-wallet, mobile-wallet, portfolio-tracker, token-list, CoinGecko, CoinMarketCap, or other market-data inclusion

## 12. Pre-deployment simulation

- [ ] All local and pinned-fork checks pass without broadcast
- [ ] Creation bytecode and constructor data match reviewed artifacts
- [ ] Authority and cap configuration are simulated
- [ ] Canary, representative, maximum-size, and failure cases are simulated
- [ ] Every batch uses approved ordering and checksum
- [ ] Balances, events, supply, and cap headroom reconcile after every batch
- [ ] Normal finalization is simulated after the required state
- [ ] Emergency finalization is simulated from an interrupted rollout
- [ ] Post-finalization distribution, transfer, approval, and repeated finalization fail
- [ ] Results are independently reviewed

## 13. Unsigned artifact review

- [ ] Every artifact states network and chain ID
- [ ] Deployment target, value, creation data, constructor data, and nonce are decoded
- [ ] Every batch records input checksum, recipient checksum, count, first and last address, and expected cumulative supply
- [ ] Batch calldata equals the approved canonical recipient array
- [ ] Batch size is within the frozen maximum
- [ ] Expected supply never exceeds the cap
- [ ] Finalization calldata and expected final supply are reviewed
- [ ] Emergency-finalization calldata is prepared and simulated
- [ ] Transaction target, value, calldata, nonce, simulation, and expected state change are reviewed
- [ ] Independent artifact and checksum review is complete
- [ ] No secret or signing authorization is included

## 14. Human-controlled execution

- [ ] Human maintainers approve the exact rollout stage
- [ ] Project owner confirms chain, target, value, calldata, nonce, constructor or manifest checksum, simulation, and expected state change
- [ ] Project owner manually signs
- [ ] Humans alone submit and broadcast
- [ ] No agent signs, submits, broadcasts, or controls the EOA
- [ ] Transaction hash, block, confirmations, fee, nonce, and replacement history are recorded
- [ ] Runtime bytecode and source verification are checked before distribution

## 15. Distribution and reconciliation

- [ ] Canary recipients and stop conditions are approved
- [ ] Exact batch sequence is approved
- [ ] Each transaction matches its numbered manifest and checksum
- [ ] No batch is repeated, skipped, reordered, or substituted without approval
- [ ] Each confirmed transaction is decoded and reconciled before the next batch
- [ ] Issuance events exactly match the submitted array
- [ ] Every recipient balance is one
- [ ] Sampled nonrecipients remain zero
- [ ] Cumulative supply equals unique successful recipients
- [ ] Remaining cap equals remaining approved recipients
- [ ] Gas, nonce, replacement, EOA activity, and unexpected events are monitored
- [ ] Any mismatch activates a stop condition

## 16. Normal finalization

- [ ] Every intended batch is confirmed
- [ ] Events, balances, cumulative supply, manifest count, and cap are reconciled
- [ ] No incident or unexplained discrepancy remains
- [ ] At least 24 hours elapsed after the final normal batch
- [ ] EOA address, chain, balance, nonce, and activity are rechecked
- [ ] Finalization target, value, calldata, nonce, simulation, and expected final supply are decoded
- [ ] Independent reviewer approved the final reconciliation
- [ ] Human maintainers approved irreversible finalization
- [ ] Project owner manually signed the finalization transaction

Below-cap finalization requires a written explanation for an approved recipient removal, operational stop, incident response, or campaign termination.

## 17. Emergency finalization

Emergency finalization may be considered during credible key compromise, manifest misuse, unexpected issuance, incorrect transaction preparation, or another active incident.

- [ ] Normal distribution stops
- [ ] Incident evidence and current reconciled state are preserved
- [ ] Remaining cap and EOA transaction state are recorded
- [ ] Finalization calldata is decoded and simulated against current state
- [ ] Human maintainers approve immediate finalization
- [ ] Project owner retains legitimate control and manually signs
- [ ] Confirmation and finalization event are recorded
- [ ] Further distribution is confirmed impossible
- [ ] Existing balances remain unchanged
- [ ] Supply shortfall is documented
- [ ] Required public correction or warning is issued

Emergency finalization cannot recover a lost key, reverse prior issuance, or guarantee recovery after full compromise.

## 18. Final records

- [ ] Network, chain ID, contract address, deployment transaction, block, timestamp, and deployer recorded
- [ ] Source commit, compiler settings, constructor data, creation hash, and runtime hash recorded
- [ ] Name, symbol, decimals, initial supply, authority, cap, and maximum batch size rechecked
- [ ] Dedicated EOA checksummed address and non-secret control evidence recorded
- [ ] Source-verification status and link recorded
- [ ] Etherscan submission, response, displayed-field, and correction records are preserved
- [ ] Every manifest, checksum, calldata, transaction, event set, and reconciliation report recorded
- [ ] Final supply reconciled with manifest and cap
- [ ] Any shortfall has a written explanation
- [ ] Finalization transaction, event, state, final supply, and observation period recorded
- [ ] Distribution, transfer, transfer-from, approval, and repeated finalization remain unavailable
- [ ] Existing balances remain preserved
- [ ] Canonical official page and public verification material are independently rechecked
- [ ] No private key or wallet secret was accessed by an agent
- [ ] No transaction was signed, submitted, or broadcast by an agent
