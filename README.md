# REP MIGRATION ALERT

This repository contains the foundation for an experimental, non-economic on-chain alert intended to help selected REP-holder addresses discover official migration information. The alert performs no migration and requires no recipient interaction.

## Status

Repository foundation, product specification, threat model, and acceptance criteria are complete after the 2026-07-16 revision. Minimal contract implementation is next and has not started.

**No production Solidity contract, deployment script, recipient-selection logic, wallet, key, or RPC configuration exists.**

Start with the [documentation index](docs/README.md), the approved [product specification](docs/product/SPEC.md), and the [architecture decision record](docs/architecture/DECISION_RECORD.md).

## Toolchain

- Foundry with Solidity `0.8.36`
- Bun `1.3.14` for package management, TypeScript execution, and tests
- TypeScript with `tsc --noEmit`
- Biome for TypeScript formatting and linting
- Slither managed as a Python CLI with `uv`

OpenZeppelin Contracts and `forge-std` are pinned dependencies. The approved production contract architecture is standalone and must not inherit OpenZeppelin token, ownership, access-control, proxy, or upgradeable contracts. An unused OpenZeppelin dependency will be removed later through a separate reviewed dependency change.

## Standard checks

```bash
make fmt-check
make build
make test
make coverage
make audit
make ops-check
make check
```

All current checks are local and require no public Ethereum RPC. Deployment and transaction broadcast are outside the current milestone.
