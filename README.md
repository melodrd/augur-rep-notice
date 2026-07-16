# Augur REP Migration Notice

This repository contains the foundation for an experimental, non-economic on-chain notice intended to test whether some REP holders can be made more aware of official migration information.

## Status

Repository foundation, product architecture, design-stage threat model, and acceptance criteria are complete. Minimal contract implementation is the next phase and has not started.

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
