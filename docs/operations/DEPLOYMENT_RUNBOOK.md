# Deployment Runbook

Status: Approved design-stage deployment gates — non-operational

This runbook defines future human-controlled deployment, distribution, reconciliation, and finalization gates for the REP Migration Notice. It does not authorize RPC access, deployment, signing, transaction submission, broadcast, or Safe operation. It remains non-operational until the approved [product specification](../product/SPEC.md), design-stage [threat model](../security/THREAT_MODEL.md), frozen acceptance criteria, implementation checks, independent reviews, and environment-specific release gates are complete.

Unchecked items are future release requirements, not evidence that an action is currently authorized or complete. Agents may prepare and review unsigned artifacts and simulations only within an explicitly authorized task. Agents must never sign, submit, broadcast, or operate the production Safe.

## Stop conditions

Stop preparation or execution when any of the following occurs:

- a required approval or independent review is missing;
- the source, compiler settings, dependencies, bytecode, metadata, constructor data, chain, authority, cap, recipient manifest, batch calldata, or checksum differs from the approved artifact;
- the recipient manifest count does not equal the immutable distribution cap;
- a required historical state query is unavailable or inconsistent;
- gas or calldata measurements do not support the frozen maximum batch size;
- the Safe owner, threshold, module, guard, fallback-handler, signer-control, or chain configuration differs from the reviewed configuration;
- a simulation, test, static-analysis check, source-verification check, or reconciliation check fails;
- an unknown transaction, nonce conflict, replacement, unexpected event, balance, or supply change appears;
- controller compromise, manifest misuse, incorrect transaction preparation, or another active incident is suspected;
- a requested action would require an agent to access a key, sign, submit, broadcast, or operate the Safe.

Do not work around a stop condition. Record it, preserve the relevant artifacts, and return the decision to the responsible human maintainer.

## Document and release approval

- [ ] Product specification remains approved for the candidate behavior
- [ ] Design-stage threat model remains approved for implementation planning and is not described as an audit
- [ ] Frozen acceptance criteria are satisfied by the candidate
- [ ] Architecture decision record matches the candidate
- [ ] Evidence-dependent parameters are resolved under their documented gates
- [ ] Release gates are approved by the repository maintainer
- [ ] Independent contract review is complete
- [ ] Independent recipient and operations review is complete
- [ ] Independent communications review is complete
- [ ] Independent deployment-artifact review is complete
- [ ] Review findings are resolved or explicitly accepted by the responsible human maintainer

## Candidate freeze

- [ ] Exact source commit and candidate tag recorded
- [ ] Solidity compiler version, optimizer settings, EVM version, and IR settings recorded
- [ ] Dependency tags and immutable commits recorded
- [ ] Candidate reproduced in a second environment
- [ ] Creation bytecode hash recorded
- [ ] Runtime bytecode hash recorded
- [ ] Constructor arguments and encoded constructor data recorded
- [ ] Exact ABI recorded
- [ ] Source-verification inputs prepared
- [ ] Contract-size result recorded
- [ ] Coverage result recorded as a diagnostic, not a security claim
- [ ] Static-analysis findings classified and reviewed
- [ ] Unit, fuzz, invariant, fork, and gas checks passed for the frozen candidate

## Approved architecture verification

- [ ] Candidate is a standalone minimal contract
- [ ] Candidate does not inherit OpenZeppelin ERC20, Ownable, Ownable2Step, AccessControl, Pausable, an upgradeable contract, a proxy contract, or a generalized token framework
- [ ] No unexpected inherited or otherwise externally callable path exists
- [ ] No proxy, upgrade, delegatecall, arbitrary external-call, callback, hook, recovery, fallback, or receive path exists
- [ ] No payable interface or ETH withdrawal path exists
- [ ] Contract behavior does not depend on its ETH balance and exceptionally forced ETH remains inert and unrecoverable
- [ ] No REP, migration-contract, oracle, bridge, or token-recovery interaction exists
- [ ] Exactly one privileged array-based distribution path exists
- [ ] Transfer and transferFrom always revert, including zero-value transfer calls
- [ ] Approve always reverts and allowance always returns zero
- [ ] Permit, allowance-changing helpers, operator approvals, and burn functions are absent
- [ ] Finalization is explicit, one-time, irreversible, and closes every issuance path
- [ ] Every successful recipient emits `Transfer(address(0), recipient, 1)` and no ordinary transfer event can occur
- [ ] Finalization emits `DistributionFinalized(authority, finalSupply)` with the accurate final supply
- [ ] No on-chain manifest hash, batch identifier, or duplicate per-recipient notice event was added
- [ ] Reaching the immutable cap does not automatically finalize distribution

## Hardcoded metadata verification

- [ ] Name is hardcoded as `Augur REP Migration Notice`
- [ ] Symbol is hardcoded as `REPNOTICE`
- [ ] Decimals are hardcoded as `0`
- [ ] Constructor does not accept configurable token metadata
- [ ] Initial total supply is zero
- [ ] Constructor issues no notice units
- [ ] Deployer receives no notice inventory

## Recipient manifest and immutable cap

- [ ] Final production recipient manifest is approved
- [ ] Manifest contains only validated, nonzero, unique, canonically ordered addresses
- [ ] Snapshot, eligibility, exclusions, and reason-code evidence are approved
- [ ] Manifest JSON, reviewable CSV, summary report, and checksums are recorded
- [ ] Manifest was regenerated from reviewed inputs without manual production edits
- [ ] Independent reproduction produced the same recipient set and checksums
- [ ] Immutable `distributionCap` equals the exact unique-address count in the approved manifest
- [ ] Constructor cap is nonzero
- [ ] Zero-cap construction reverts in the frozen candidate
- [ ] Cap-boundary success and cap-overflow atomic reversion are demonstrated
- [ ] No discretionary issuance margin or unused headroom was added
- [ ] Any recipient-set change after candidate deployment is treated as requiring abandonment and redeployment

## Maximum batch-size gate

- [ ] Worst-case gas is measured using entirely new recipients
- [ ] Calldata cost is included
- [ ] Measurements cover one-address, typical, proposed-maximum, duplicate, previously notified, cap-boundary, cap-overflow, and other revert scenarios
- [ ] Measurements use the approved target-chain block gas limit at the pinned test block
- [ ] The compile-time maximum uses no more than 50% of that block gas limit in the worst-case successful call
- [ ] A lower maximum is used if calldata, execution, tooling, or Safe simulation imposes a stricter bound
- [ ] The benchmark records the block conditions, calldata size, gas per batch, gas per recipient, chosen constant, and safety margin
- [ ] The contract enforces the frozen maximum
- [ ] An independent reviewer approved the benchmark and constant before candidate freeze

## Deployer and constructor verification

- [ ] Intended network and chain ID confirmed
- [ ] Deployment target and creation transaction type confirmed
- [ ] Deployer address checksum independently reviewed
- [ ] Deployer and immutable authority are documented as separate concepts
- [ ] Deployment creates no implicit deployer privilege
- [ ] No post-deployment authority handoff is planned
- [ ] Constructor authority is the reviewed production Safe address
- [ ] Constructor authority is nonzero
- [ ] Constructor cap equals the approved manifest count
- [ ] Constructor arguments are independently decoded and reviewed
- [ ] Deployment simulation confirms the authority, cap, metadata, zero supply, and unfinalized state

## Dedicated 2-of-3 Safe gate

The production authority must be a dedicated 2-of-3 Safe. The exact address, Safe version, and signer identities remain evidence-dependent deployment parameters until reviewed and approved. The immutable contract authority is the Safe address; Safe signer custody does not create a contract-level authority-transfer path.

- [ ] Safe exists on the intended chain and its checksum address is independently verified
- [ ] Safe version and implementation are recorded and reviewed
- [ ] Exactly three owners are configured
- [ ] Threshold is exactly two
- [ ] Each signer is controlled independently
- [ ] No person, device, seed, custodian, or recovery arrangement controls more than one signer
- [ ] Signer key-storage and backup procedures are independently reviewed
- [ ] Hardware-backed signer storage is used unless a documented exception is approved
- [ ] No test key is reused for mainnet
- [ ] No Safe module is enabled
- [ ] No custom guard is configured
- [ ] Fallback handler is identified, reviewed, and approved
- [ ] No unexplained extension, delegate, session key, automation, or delegated signing capability exists
- [ ] Safe is dedicated to the campaign
- [ ] Safe holds no unrelated assets beyond limited operational ETH
- [ ] Safe has no unrelated DeFi or protocol activity
- [ ] Safe nonce and transaction history are reviewed before every rollout stage
- [ ] Owner, threshold, version, module, guard, fallback-handler, or custody changes after final rehearsal trigger an incident-level review and candidate reapproval
- [ ] Distribution and finalization transactions are simulated through the exact reviewed Safe configuration
- [ ] Human Safe signers understand that finalization is irreversible

## Final Sepolia rehearsal

- [ ] Sepolia use is explicitly authorized by the human maintainer
- [ ] Exact frozen candidate bytecode is deployed and source-verified
- [ ] Constructor metadata, authority, and cap semantics match the mainnet candidate
- [ ] A dedicated 2-of-3 Safe with three independent test signers is used as authority
- [ ] Safe modules are absent, no custom guard is configured, and the fallback handler is reviewed
- [ ] Test signers and keys are not reused for mainnet
- [ ] One-address canary and representative multi-address batches are exercised
- [ ] Empty, zero-address, duplicate, previously notified, oversized, unauthorized, finalized, and cap-overflow failures are observed
- [ ] Batch calldata, events, balances, and cumulative supply reconcile
- [ ] Normal and emergency finalization procedures are rehearsed
- [ ] Repeated finalization and post-finalization distribution fail
- [ ] Existing balances remain after finalization
- [ ] Exact wallet-product test matrix is selected immediately before testing and recorded
- [ ] Matrix includes at least two browser wallets, two mobile wallets, one portfolio tracker, one block explorer, one interface with spam filtering, and one interface supporting manual token import
- [ ] Tests record automatic visibility, manual import, metadata truncation, decimals and balance rendering, transfer and approval affordances, spam classification, price metadata, third-party links or descriptions, failure presentation, and post-finalization behavior
- [ ] Final rehearsal findings are independently reviewed
- [ ] Any candidate or controller change after rehearsal requires a new final rehearsal

## Communications gate

- [ ] Canonical notice language in [`docs/communications/NOTICE_MESSAGING.md`](../communications/NOTICE_MESSAGING.md) is approved
- [ ] Exact official Augur canonical page URL is approved
- [ ] Canonical page is available before public Sepolia communication and before mainnet deployment
- [ ] Canonical page states the chain, verified contract address, source-verification link, notice-only meaning, safety warning, and official migration information
- [ ] Contract address is published only after independent chain, address, bytecode, and source-verification checks
- [ ] Communications do not request approval, transfer, swap, burn, bridge, claim, signature, or wallet connection
- [ ] Communications warn that copied metadata, third-party prices, and apparent liquidity do not establish authenticity or value
- [ ] Official channels link back to the canonical page and use the approved core message
- [ ] Incident and correction publication procedures are assigned to human owners

## Pre-deployment simulation

- [ ] Formatting, compilation, size, test, coverage, gas, and static-analysis checks passed
- [ ] Pinned mainnet-fork simulation passed without broadcast
- [ ] Candidate creation bytecode and constructor data match the reviewed artifacts
- [ ] Immutable authority and cap configuration are simulated
- [ ] One-address canary, representative batches, maximum-size batch, and all relevant failure paths are simulated
- [ ] Every simulated batch uses the approved manifest ordering and checksum
- [ ] Cumulative balances, events, supply, and cap headroom reconcile after every simulated batch
- [ ] Normal finalization is simulated after the required reconciliation state
- [ ] Emergency finalization is simulated from an interrupted rollout state
- [ ] Post-finalization distribution, transfer, approval, and repeated finalization fail as expected
- [ ] Simulation results are independently reviewed

## Unsigned artifact review

- [ ] Every artifact states the exact network and chain ID
- [ ] Deployment target, value, creation data, and constructor data are decoded and reviewed
- [ ] Every numbered batch identifies the input checksum, recipient checksum, count, first and last address, and expected cumulative supply
- [ ] Batch calldata decodes to the exact approved recipient array in canonical order
- [ ] Batch size is at or below the frozen maximum
- [ ] Expected cumulative supply never exceeds the cap
- [ ] Safe target, value, operation type, calldata, nonce, and simulation result are reviewed
- [ ] Finalization calldata and expected final supply are reviewed
- [ ] Emergency-finalization calldata is prepared, decoded, simulated, and kept unsigned
- [ ] Artifact and checksum review is independently repeated
- [ ] No private key, seed phrase, signing payload approval, or secret environment value is requested or recorded

## Human-controlled execution

- [ ] Human maintainers approve the exact rollout stage
- [ ] Human deployer independently confirms the network, creation data, and constructor arguments before signing
- [ ] Human Safe signers independently confirm the Safe, chain, target, value, operation, calldata, nonce, manifest checksum, and simulation before approving
- [ ] At least two of the three reviewed Safe owners approve each Safe transaction
- [ ] Humans alone sign, submit, and broadcast
- [ ] No agent operates the Safe or signs, submits, or broadcasts a transaction
- [ ] Transaction hashes, blocks, confirmations, and replacement history are recorded
- [ ] Source verification and runtime-bytecode checks complete before distribution begins

## Distribution controls

- [ ] Canary recipients and canary stop conditions are approved
- [ ] Exact batch sequence is approved
- [ ] Each transaction matches its numbered manifest and checksum
- [ ] No batch is repeated, skipped, reordered, or substituted without documented approval
- [ ] Each confirmed transaction is decoded and reconciled before the next batch
- [ ] Issuance events match the submitted recipient array exactly
- [ ] Every recipient balance is one and every nonrecipient sample remains zero
- [ ] Cumulative supply equals cumulative unique successful recipients
- [ ] Remaining cap headroom equals remaining approved manifest recipients
- [ ] Gas, nonce, replacement, Safe-state, and unexpected-event conditions are monitored
- [ ] Any mismatch activates a stop condition and the emergency-finalization review

## Normal finalization gate

Normal finalization requires every item below:

- [ ] Every intended batch was submitted and confirmed
- [ ] Every issuance event was reconciled
- [ ] Every intended balance and cumulative supply was reconciled
- [ ] Cumulative supply equals the approved manifest count and immutable cap
- [ ] No incident or unexplained discrepancy remains
- [ ] At least 24 hours elapsed after confirmation of the final normal batch
- [ ] Safe owners, threshold, modules, guard, fallback handler, nonce, and signer control were rechecked
- [ ] An independent reviewer approved the final reconciliation
- [ ] Human maintainers approved irreversible finalization
- [ ] At least two of the three reviewed Safe owners approved the finalization transaction

Finalization below the cap is permitted only for a documented exceptional case such as an approved recipient removal, operational stop, incident response, or campaign termination. The written record must explain the shortfall against both the approved manifest and immutable cap before human approval.

## Emergency-finalization procedure

Immediate emergency finalization may be considered when there is credible evidence of controller compromise, manifest misuse, unexpected issuance, incorrect transaction preparation, or another active operational incident requiring distribution to stop.

- [ ] Further normal distribution is stopped
- [ ] Incident evidence and current reconciled supply are preserved
- [ ] Exact Safe state and remaining cap headroom are recorded
- [ ] Prepared finalization calldata is re-decoded and simulated against current state
- [ ] Human maintainers approve emergency finalization
- [ ] At least two of the three reviewed Safe owners approve, sign, and submit
- [ ] Finalization confirmation and event are recorded
- [ ] Further distribution is confirmed impossible
- [ ] Existing balances are confirmed unchanged
- [ ] Supply shortfall against the manifest and cap is documented
- [ ] Communications and incident owners publish any required correction or warning

Emergency finalization stops future issuance only. It does not reverse, recover, or alter notices already issued, and it does not authorize an agent to operate the Safe.

## Post-deployment and final records

- [ ] Network, chain ID, contract address, deployment transaction, block, timestamp, and deployer recorded
- [ ] Source commit, compiler settings, constructor arguments, creation hash, and runtime hash recorded
- [ ] Hardcoded name, symbol, decimals, zero initial supply, authority, cap, and maximum batch size rechecked
- [ ] Production Safe address, version, owners, threshold, modules, guard, and fallback handler recorded
- [ ] Source-verification status and link recorded
- [ ] Every batch manifest, checksum, calldata, transaction, event set, and reconciliation report recorded
- [ ] Final supply reconciled against the approved manifest and immutable cap
- [ ] Any approved shortfall has a written reconciliation explanation
- [ ] Finalization state, transaction, event, final supply, and observation period recorded
- [ ] Authority remains readable but has no effective contract power
- [ ] Distribution, transfer, transferFrom, approval, and repeated finalization remain unavailable
- [ ] Existing balances remain preserved
- [ ] Canonical communications page and public verification material were independently rechecked
- [ ] No production key was accessed by an agent
- [ ] No transaction was signed, submitted, or broadcast by an agent
