# Project documentation

Current status: foundation and the V2 product specification, threat model, and acceptance criteria are complete. The V2
core contract candidate is implemented and locally validated; maximum batch enforcement remains unresolved.

| Document | Responsibility |
| --- | --- |
| [Product specification](product/SPEC.md) | Authoritative contract purpose, metadata, interface, state, authority, distribution, cap, finalization, invariants, and acceptance criteria |
| [Product decisions](product/DECISIONS.md) | Major decisions, reasons, rejected alternatives, and trade-offs |
| [Threat model](security/THREAT_MODEL.md) | Threats, consequences, mitigations, remaining risks, and release controls |
| [Deployment runbook](operations/DEPLOYMENT_RUNBOOK.md) | Human-controlled deployment, distribution, reconciliation, and finalization checklists |
| [Etherscan runbook](operations/ETHERSCAN_RUNBOOK.md) | Source verification, metadata, logo, evidence, and correction workflow |
| [Messaging policy](communications/MESSAGING.md) | Canonical wording, approved meaning, prohibited claims, publication hierarchy, and incident messaging |
| [Roadmap](planning/ROADMAP.md) | Project phases, status, entry conditions, and exit conditions |
| [V2 contract validation report](reports/CONTRACT_VALIDATION_REPORT_V2.md) | Current local implementation, test, gas, ABI, storage, coverage, and static-analysis evidence for the V2 candidate |
| [V1 contract validation report](reports/CONTRACT_VALIDATION_REPORT.md) | Historical evidence for the superseded V1 metadata and no-burn candidate |
| [Foundation report](reports/FOUNDATION_SETUP_REPORT.md) | Historical repository-initialization record |
| [Toolchain report](reports/TOOLCHAIN_SETUP_REPORT.md) | Historical environment-setup record |

[`AGENTS.md`](../AGENTS.md) contains workflow, technical restrictions, and repository rules. Historical reports are reference material; current policy lives in the active documents listed above.

Etherscan is the only third-party metadata surface currently in scope. Broader wallet, tracker, token-list, and market-data work is deferred for a later specification and operations review.

No documentation approval authorizes RPC access, wallet or key handling, deployment, signing, submission, or broadcast.
