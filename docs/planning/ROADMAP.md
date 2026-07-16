# Roadmap

## Project status

- Foundation: complete
- V2 product specification: complete after the 2026-07-16 metadata and self-burn revision
- V2 threat model and acceptance criteria: complete after the 2026-07-16 revision
- V2 core contract candidate: implemented and locally validated
- Maximum batch enforcement and the contract release gate: in progress

## 1. Foundation and reproducibility

Status: Complete

Entry condition: Repository creation.

Exit condition: Pinned Foundry and Bun toolchains, directory structure, CI, standard commands, and historical setup reports are present.

## 2. Product specification

Status: Complete

Entry condition: Foundation complete.

Exit condition: Purpose, V2 metadata, permanent alert history, holder-only self-burn, authority, distribution, cap,
finalization, interface, communications meaning, and deferred evidence gates are approved.

## 3. Threat model and acceptance criteria

Status: Complete

Entry condition: Product specification approved.

Exit condition: Threats, accepted trade-offs, release controls, V2 accounting and burn invariants, and frozen
implementation acceptance criteria are approved.

## 4. Minimal contract implementation

Status: In progress

Entry condition: Specification, decisions, threat model, and acceptance criteria are committed consistently.

Exit condition: One minimal V2 contract matches the specification and compiles without unresolved warnings.

The V2 core candidate now matches the revised metadata, accounting, self-burn, and finalization model and compiles
without Solidity warnings. This phase remains in progress because the measurement-driven maximum batch constant cannot
be selected without an approved target-chain block gas limit and independent review.

## 5. Unit, fuzz, invariant, gas, and static-analysis work

Status: In progress

Entry condition: Minimal contract candidate exists.

Exit condition: Required tests and measurements pass; warnings and findings are resolved or explicitly accepted.

Current V2 unit, fuzz, invariant, gas, coverage, ABI, storage-layout, and static-analysis evidence is recorded in the
[V2 contract validation report](../reports/CONTRACT_VALIDATION_REPORT_V2.md). The prior
[V1 validation report](../reports/CONTRACT_VALIDATION_REPORT.md) remains superseded historical evidence.

The required local V2 checks pass, but this phase remains in progress because maximum batch enforcement is blocked on
an approved target-chain gas-limit input and independent review of the selected constant.

## 6. Snapshot and recipient tooling

Status: Not started

Entry condition: REP sources, migration semantics, snapshot, thresholds, and exclusions are approved.

Exit condition: Deterministic inputs reproduce identical validated, reason-coded, checksummed outputs.

## 7. Pinned mainnet-fork simulation

Status: Not started

Entry condition: Contract and recipient tooling pass local review; snapshot block is approved.

Exit condition: Pinned-fork state, gas, distribution, reconciliation, and finalization results are reviewed.

## 8. Sepolia verification

Status: Not started

Entry condition: Explicit human authorization and all prior local gates complete.

Exit condition: Candidate deployment, Etherscan source verification, dedicated Sepolia EOA operation, distribution, failure cases, reconciliation, and finalization are reviewed.

## 9. Independent review and candidate freeze

Status: Not started

Entry condition: Sepolia candidate and operational evidence are complete.

Exit condition: Code, data, communications, and unsigned deployment artifacts are independently reviewed; exact commit and bytecode are frozen.

## 10. Mainnet canary preparation

Status: Not started

Entry condition: All contract, data, communications, EOA-control, and review gates complete.

Exit condition: Reproduced bytecode, constructor data, dedicated-EOA transaction simulations, canary manifests, unsigned calldata, checksums, and stop procedures are approved.

## 11. Human-controlled canary and rollout

Status: Not started

Entry condition: Exact artifacts and stop conditions are approved.

Exit condition: Human-signed transactions are confirmed and every batch reconciles or rollout is stopped.

## 12. Reconciliation and irreversible finalization

Status: Not started

Entry condition: Approved rollout is complete or an incident requires closure.

Exit condition: Final lifetime issuance and current active supply are separately reconciled, issuance finalization is
confirmed irreversible, valid holder self-burn remains available, and official Augur and Etherscan verification records
are complete.

No phase authorizes an agent to access a private key, sign, submit, or broadcast.

Broader browser-wallet, mobile-wallet, portfolio-tracker, token-list, CoinGecko, CoinMarketCap, and market-data work is deferred for a later specification and operations review. It is not a current release gate.
