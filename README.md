# REP MIGRATION ALERT

This repository defines and will implement a minimal, non-economic on-chain alert related to Augur REP migration. The alert performs no migration, grants no rights or value, and requires no recipient interaction.

## Status

- Foundation: complete
- Product specification: complete
- Threat model and acceptance criteria: complete
- Minimal contract implementation: in progress

Core contract candidate implemented and validated; maximum batch enforcement remains blocked on the approved gas-limit
input.

A Solidity candidate exists, but no production-approved or deployed contract exists. No recipient tooling, deployment
script, wallet, key, or RPC configuration exists.

## Documentation

- [Documentation index](docs/README.md)
- [Product specification](docs/product/SPEC.md)
- [Architecture decisions](docs/product/DECISIONS.md)
- [Threat model](docs/security/THREAT_MODEL.md)
- [Deployment runbook](docs/operations/DEPLOYMENT_RUNBOOK.md)
- [Etherscan runbook](docs/operations/ETHERSCAN_RUNBOOK.md)
- [Messaging policy](docs/communications/MESSAGING.md)
- [Roadmap](docs/planning/ROADMAP.md)
- [Contract validation report](docs/reports/CONTRACT_VALIDATION_REPORT.md)

Run the local validation suite with:

```bash
make check
```

Documentation approval does not authorize RPC access, wallet operations, deployment, signing, submission, or broadcast.
