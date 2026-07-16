# CHECK AUGUR REP MIGRATION

This repository defines and contains a locally validated candidate for a minimal, non-economic on-chain alert directing
recipients to independently check official Augur REP migration information. The alert performs no migration, grants no
rights or value, and requires no recipient interaction. An active holder may optionally self-burn only their own unit;
burning is not a migration step and provides no economic benefit.

## Status

- Foundation: complete
- V2 product specification: complete
- V2 threat model and acceptance criteria: complete
- V2 contract implementation and validation: in progress

The V2 core candidate is implemented and locally validated. Maximum batch enforcement remains unresolved because no
approved target-chain block gas limit exists. The previously validated V1 candidate remains superseded historical
evidence.

No production-approved or deployed contract exists. No recipient tooling, deployment script, wallet, key, or RPC
configuration exists.

## Documentation

- [Documentation index](docs/README.md)
- [Product specification](docs/product/SPEC.md)
- [Architecture decisions](docs/product/DECISIONS.md)
- [Threat model](docs/security/THREAT_MODEL.md)
- [Deployment runbook](docs/operations/DEPLOYMENT_RUNBOOK.md)
- [Etherscan runbook](docs/operations/ETHERSCAN_RUNBOOK.md)
- [Messaging policy](docs/communications/MESSAGING.md)
- [Roadmap](docs/planning/ROADMAP.md)
- [Current V2 contract validation report](docs/reports/CONTRACT_VALIDATION_REPORT_V2.md)
- [Historical V1 contract validation report](docs/reports/CONTRACT_VALIDATION_REPORT.md)

Run the local validation suite with:

```bash
make check
```

Documentation approval does not authorize RPC access, wallet operations, deployment, signing, submission, or broadcast.
