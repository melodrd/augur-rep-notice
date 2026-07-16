# Roadmap

## Project status

- Foundation: complete
- Product specification: complete after the 2026-07-16 revision
- Threat model and acceptance criteria: complete after the 2026-07-16 revision
- Minimal contract implementation: in progress

## 1. Foundation and reproducibility

Status: Complete

Entry condition: Repository creation.

Exit condition: Pinned Foundry and Bun toolchains, directory structure, CI, standard commands, and historical setup reports are present.

## 2. Product specification

Status: Complete

Entry condition: Foundation complete.

Exit condition: Purpose, metadata, authority, distribution, cap, finalization, interface, communications meaning, and deferred evidence gates are approved.

## 3. Threat model and acceptance criteria

Status: Complete

Entry condition: Product specification approved.

Exit condition: Threats, accepted trade-offs, release controls, invariants, and frozen implementation acceptance criteria are approved.

## 4. Minimal contract implementation

Status: In progress

Entry condition: Specification, decisions, threat model, and acceptance criteria are committed consistently.

Exit condition: One minimal contract matches the specification and compiles without unresolved warnings.

## 5. Unit, fuzz, invariant, gas, and static-analysis work

Status: In progress

Entry condition: Minimal contract candidate exists.

Exit condition: Required tests and measurements pass; warnings and findings are resolved or explicitly accepted.

Core contract candidate implemented and validated; maximum batch enforcement remains blocked on the approved gas-limit
input. Unit, fuzz, invariant, gas, coverage, ABI, storage-layout, and static-analysis evidence is recorded in the
[contract validation report](../reports/CONTRACT_VALIDATION_REPORT.md).

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

Exit condition: Final supply is reconciled, finalization is confirmed irreversible, and official Augur and Etherscan verification records are complete.

No phase authorizes an agent to access a private key, sign, submit, or broadcast.

Broader browser-wallet, mobile-wallet, portfolio-tracker, token-list, CoinGecko, CoinMarketCap, and market-data work is deferred for a later specification and operations review. It is not a current release gate.
