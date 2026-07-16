# Augur REP Migration Notice

This repository is intended to hold the smart contract and deterministic operational tooling for an experimental, non-economic Augur REP migration notice.

## Status

Foundation complete. The repository has reproducible Foundry and Bun toolchains, dependency pins, documentation, CI, and a foundation-level TypeScript test. Product specification is the next milestone and has not started.

**No production Solidity contract, token, deployment script, recipient-selection logic, wallet, key, or RPC configuration exists yet.**

## Toolchain

- Foundry with Solidity `0.8.36`
- forge-std `v1.16.1`
- OpenZeppelin Contracts `v5.6.1`
- Bun `1.3.14` for package management, TypeScript execution, and tests
- TypeScript `7.0.2` for static type checking
- Biome `2.5.4` for TypeScript formatting and linting
- Slither `0.11.5`, installed as a Python CLI with `uv`
- Node.js as a compatibility fallback only

Bun is the sole repository JavaScript package manager. `TOOLCHAIN_SETUP_REPORT.md` is a historical pre-foundation environment record whose disposable pnpm and `tsx` checks are not current repository policy.

## Repository layout

```text
src/                 Future production Solidity source
test/                Future unit, fuzz, invariant, and fork tests
script/              Future Foundry scripts
ops/src/             Future operational TypeScript source
ops/test/            Foundation and future operational tests
data/                Reviewed inputs and generated-artifact namespaces
deployments/         Environment-specific deployment records
.github/workflows/   Foundation CI
```

Empty directories contain `.gitkeep` files only. No placeholder contract is used.

## Standard commands

```bash
make help
make ops-install
make fmt-check
make build
make test
make coverage
make audit
make check
```

From `ops/`:

```bash
bun install --frozen-lockfile
bun run check
```

All current checks are local and require no public Ethereum RPC. Deployment and transaction broadcast are outside this milestone.
