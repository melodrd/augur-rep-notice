# Project documentation

This directory contains the current product, security, planning, operational, and historical documentation for the Augur REP Migration Notice experiment.

| Document | Purpose | Status |
| --- | --- | --- |
| [Product specification](product/SPEC.md) | Defines approved product and contract behavior | Approved for implementation planning |
| [Architecture decision record](architecture/DECISION_RECORD.md) | Summarizes approved architecture, rationale, trade-offs, and gates | Approved |
| [Notice messaging](communications/NOTICE_MESSAGING.md) | Defines canonical notice-only language and publication controls | Approved core message; URL gated |
| [Threat model](security/THREAT_MODEL.md) | Classifies contract, operational, data, and communications risks | Approved for implementation planning — not audited |
| [Roadmap](planning/ROADMAP.md) | Defines gated project phases | Threat model and acceptance criteria complete; implementation next |
| [Deployment runbook](operations/DEPLOYMENT_RUNBOOK.md) | Defines future deployment controls and checklists | Approved design-stage gates; non-operational |
| [Toolchain report](reports/TOOLCHAIN_SETUP_REPORT.md) | Historical environment setup record | Historical |
| [Foundation report](reports/FOUNDATION_SETUP_REPORT.md) | Historical repository-initialization record | Historical |

[`AGENTS.md`](../AGENTS.md) contains standing instructions for Codex and other coding agents. The root [`README.md`](../README.md) is the human-facing project introduction.

Reports under [`docs/reports/`](reports/) are historical records, not current operating policy. Current operating policy is defined by [`AGENTS.md`](../AGENTS.md), current configuration files, the approved specification and architecture record, and later approved release-gate documents.

Bun is the repository's JavaScript package manager and TypeScript runtime. Foundry is the Solidity development framework. `uv` manages Python command-line tooling.

No production contract currently exists. Documentation approval does not authorize RPC access, wallet operations, deployment, signing, Safe operation, or transaction broadcast.
