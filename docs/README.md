# Project documentation

This directory contains the current product, security, planning, operational, and historical documentation for the Augur REP Migration Notice experiment.

| Document | Purpose | Status |
| --- | --- | --- |
| [Product specification](product/SPEC.md) | Defines intended contract behavior and acceptance criteria | Draft / awaiting approval |
| [Threat model](security/THREAT_MODEL.md) | Identifies contract, operational, data, and communications risks | Draft |
| [Roadmap](planning/ROADMAP.md) | Defines gated project phases | Foundation complete; specification in progress |
| [Deployment runbook](operations/DEPLOYMENT_RUNBOOK.md) | Defines future deployment controls and checklists | Placeholder / unapproved |
| [Toolchain report](reports/TOOLCHAIN_SETUP_REPORT.md) | Historical environment setup record | Historical |
| [Foundation report](reports/FOUNDATION_SETUP_REPORT.md) | Historical repository-initialization record | Historical |

[`AGENTS.md`](../AGENTS.md) contains standing instructions for Codex and other coding agents. The root [`README.md`](../README.md) is the human-facing project introduction.

Reports under [`docs/reports/`](reports/) are historical records, not current operating policy. Current operating policy is defined by [`AGENTS.md`](../AGENTS.md), current configuration files, and approved project documents.

Bun is the repository's JavaScript package manager and TypeScript runtime. Foundry is the Solidity development framework. `uv` manages Python command-line tooling.

No production contract currently exists.
