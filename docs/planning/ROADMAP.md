# Roadmap

Foundation and reproducibility are complete. Product specification is in progress and still requires maintainer approval. No later phase has started.

## 1. Foundation and reproducibility — Complete

- Objective: Establish a minimal, pinned Foundry and Bun repository.
- Deliverables: Git foundation, dependencies, directory layout, documentation, Makefile, CI, and foundation checks.
- Exit status: Completed and recorded in the historical [foundation report](../reports/FOUNDATION_SETUP_REPORT.md).
- Non-goals: Production Solidity, recipient logic, RPC access, wallets, deployments, and transactions.

## 2. Product specification — In progress

- Objective: Define the notice's exact meaning and product behavior without implementing it.
- Deliverables: Reviewable contract behavior, metadata constraints, authority and finalization proposals, security invariants, acceptance criteria, and open maintainer decisions.
- Entry conditions: Phase 1 complete.
- Exit conditions: Maintainers approve [`docs/product/SPEC.md`](../product/SPEC.md) with no unresolved contract-level ambiguity.
- Non-goals: Contract implementation, tests, recipient extraction, RPC access, or deployment.

## 3. Threat model and acceptance criteria — Not started

- Objective: Review the approved behavior against abuse cases and convert it into accepted security and test gates.
- Deliverables: Approved threat model, owned mitigations, invariants, and acceptance criteria.
- Entry conditions: Product specification approved.
- Exit conditions: Maintainers accept mitigations and assign ownership for unresolved operational risks.
- Non-goals: Claiming an audit or absence of vulnerabilities.

## 4. Minimal contract implementation — Not started

- Objective: Implement only the approved notice behavior.
- Deliverables: One short production contract with approved authorization, unique distribution, non-transferability, and finalization behavior.
- Entry conditions: Phases 2 and 3 complete.
- Exit conditions: Implementation matches the approved specification and compiles without unresolved warnings.
- Non-goals: Snapshot tooling, deployment, upgradeability, callbacks, claims, or generalized frameworks.

## 5. Unit, fuzz, and invariant testing — Not started

- Objective: Exercise contract behavior and mandatory security invariants.
- Deliverables: Unit, fuzz, invariant, coverage, gas, and Slither reports.
- Entry conditions: Minimal contract candidate exists.
- Exit conditions: Relevant checks pass and findings are resolved or explicitly accepted by maintainers.
- Non-goals: Treating test coverage as an audit.

## 6. Snapshot and recipient tooling — Not started

- Objective: Build deterministic, evidence-backed recipient data processing.
- Deliverables: Schemas, fixtures, validation, filtering, reason codes, checksums, batches, and reconciliation.
- Entry conditions: Eligibility and migration rules approved.
- Exit conditions: The same reviewed inputs reproduce identical outputs.
- Non-goals: Public RPC access without an approved pinned plan or manual production-manifest edits.

## 7. Pinned mainnet-fork simulation — Not started

- Objective: Test approved assumptions against reproducible historical Ethereum state.
- Deliverables: Pinned fork tests, gas measurements, simulated batches, finalization, and reconciliation.
- Entry conditions: Contract and recipient tooling pass local review; snapshot block approved.
- Exit conditions: Fork results reconcile and operational limits are documented.
- Non-goals: Broadcast or latest-block dependencies.

## 8. Sepolia and wallet-display testing — Not started

- Objective: Empirically test deployment operations and wallet presentation.
- Deliverables: Verified Sepolia deployment records, authority handoff, distribution, finalization, and wallet observations.
- Entry conditions: Explicit maintainer authorization and all prior local gates complete.
- Exit conditions: Testnet behavior and communications risks are reviewed.
- Non-goals: Mainnet execution or promises of wallet visibility.

## 9. Independent review — Not started

- Objective: Obtain separate review of code, data, and deployment artifacts.
- Deliverables: Review findings, responses, dependency freeze, and candidate commit.
- Entry conditions: Sepolia candidate complete.
- Exit conditions: Findings are resolved or formally accepted by maintainers.
- Non-goals: Self-declaring the project audited.

## 10. Mainnet canary preparation — Not started

- Objective: Produce reproducible, unsigned material for a limited canary.
- Deliverables: Reproduced bytecode, Safe simulation, unsigned calldata, canary list, checks, and stop procedures.
- Entry conditions: Independent review and all release gates complete.
- Exit conditions: Human maintainers approve exact artifacts and stop conditions.
- Non-goals: Signing, submission, broadcast, or Safe operation by an agent.

## 11. Human-controlled canary — Not started

- Objective: Execute the approved canary under human control.
- Deliverables: Human-signed transactions, monitoring observations, and canary reconciliation.
- Entry conditions: Phase 10 approved and incident-response ownership active.
- Exit conditions: Maintainers approve continuation or stop.
- Non-goals: Autonomous rollout or agent-controlled transactions.

## 12. Reconciliation and irreversible finalization — Not started

- Objective: Reconcile the approved rollout and permanently disable distribution.
- Deliverables: Final reconciliation, human-approved finalization, post-finalization checks, and public verification records.
- Entry conditions: Every approved batch reconciles and maintainers authorize finalization.
- Exit conditions: Finalization is confirmed irreversible and records are complete.
- Non-goals: Unfinalization, upgrade, recovery minting, or new distribution authority.
