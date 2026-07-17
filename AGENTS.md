# AGENTS.md

## Purpose

This repository contains the contract and operational tooling for CHECK AUGUR REP MIGRATION, a minimal non-economic
on-chain alert. It is not REP, migrated REP, replacement REP, a claim, reward, governance asset, or tradable
instrument.

Treat contract changes, recipient transformations, deployment preparation, and transaction artifacts as
security-sensitive production infrastructure. A passing build is not evidence of an audit, safety, usefulness, or
deployment readiness.

## Source of authority

When instructions conflict, follow:

1. Explicit human instructions for the current task.
2. [docs/SPEC.md](docs/SPEC.md) for required contract behavior.
3. [docs/OPERATIONS.md](docs/OPERATIONS.md) for recipient, deployment, wallet, and communications controls.
4. [docs/VALIDATION.md](docs/VALIDATION.md) for current evidence and known limitations.
5. This file.
6. Existing tests and code comments.

Stop before changing code when a request conflicts with a security invariant or approved behavior.

## Current contract invariants

- Fixed metadata is CHECK AUGUR REP MIGRATION, MIGRATEREP, and zero decimals.
- Construction starts with zero issuance and requires one nonzero immutable authority and cap.
- Deployment alone grants no privilege.
- Recipient state moves only from NeverAlerted to Active to Burned.
- distribute(address[]) is the sole issuance path and is strictly atomic.
- Validation order is authority, finalized, empty, maximum batch, lifetime cap, then recipients.
- MAX_BATCH_SIZE is a compile-time public constant equal to 500.
- Operational batches should normally contain about 100–200 recipients.
- Every successful recipient receives exactly one unit and one ordered Transfer event.
- Zero, duplicate, active, and previously burned recipients are rejected.
- totalIssued counts unique addresses ever alerted and only increases.
- totalSupply counts active, unburned units.
- wasAlerted is permanent, including after burn.
- totalSupply <= totalIssued <= distributionCap.
- Burning never restores cap capacity or permits reissuance.
- Only an active holder can burn their own unit, before or after finalization.
- Only the immutable authority distributes or finalizes.
- Finalization is explicit, irreversible, and permanently closes issuance.
- Transfers and approvals always fail; allowance is always zero.

Any behavioral change requires specification, threat, acceptance-criteria, and test review.

## Prohibited functionality

Do not add:

- REP or migration-contract interaction, custody, claims, redemptions, or user minting;
- transferability, approvals, permit, operators, delegated burn, authority burn, or burnFrom;
- ownership, roles, authority transfer, successor nomination, recovery, or secondary administration;
- proxy, upgrade, delegatecall, diamond, governance, or generalized extension systems;
- payable, receive, fallback, withdrawal, token recovery, or arbitrary external-call paths;
- callbacks, hooks, bridges, oracles, multicalls, wallet-connect, or signature flows;
- pricing, liquidity, taxes, staking, yield, vesting, rebasing, or other economic behavior;
- dynamic metadata, token URI, or an on-chain migration URL;
- frontend or live-chain work before its documented gate.

Do not weaken tests, suppress findings, or silently change behavior.

## Solidity quality

- Keep the production contract standalone, explicit, and small.
- Use exact pragmas, SPDX identifiers, NatSpec, named constants, custom errors, and precise events.
- Prefer simple control flow, checks before effects, minimal storage, and calldata for arrays.
- Avoid unnecessary inheritance, assembly, low-level calls, magic values, unsafe casts, and dynamic dispatch.
- Do not use unchecked arithmetic without a documented proof, material benchmark, and focused tests.
- Do not add test-only production functions, dead code, commented alternatives, unresolved TODOs, or warning suppressions.
- Every public or external function and every state variable must have a necessary, documented purpose.
- Preserve atomic rollback, event order, binary balances, permanent history, and exact accounting.

## Toolchain

Canonical Solidity settings in foundry.toml are:

- Solidity 0.8.36;
- EVM Osaka;
- optimizer enabled with 200 runs;
- via IR disabled.

Use Foundry, forge-std, and Slither. CI pins Foundry 1.7.1, Slither 0.11.5, Bun 1.3.14, and uv 0.11.28. Do not add
Hardhat, Truffle, Brownie, or another Solidity framework without approval. Pin dependencies to tags or immutable
commits and isolate upgrades from behavioral changes.

## TypeScript operations

- Bun is the sole JavaScript package manager; Node.js is only a compatibility fallback.
- Never run repository installs with npm or pnpm.
- Do not create package-lock.json, pnpm-lock.yaml, or yarn.lock.
- Install reproducibly with bun install --frozen-lockfile.
- Bun may execute TypeScript, but tsc --noEmit is mandatory static type checking.
- Biome performs TypeScript formatting and linting.
- Use viem, Zod schemas, deterministic JSON and CSV, and cryptographic checksums.
- Use bigint for on-chain integers and balances; never use floating-point arithmetic.
- Keep Bun-specific runtime APIs to the minimum needed for portability.

## Default safety boundary

- Work locally unless the task explicitly authorizes another environment.
- Do not access an Ethereum RPC without explicit authorization.
- Do not request, inspect, create, import, or store a production private key, seed phrase, keystore, or secret.
- Do not create or operate the production authority wallet.
- Do not put secrets in environment files, commands, logs, documentation, or Git.
- Do not deploy to mainnet.
- Do not sign, submit, or broadcast transactions.
- Sepolia work requires explicit instruction and a separate test-only key controlled by a human.
- Agents may prepare unsigned artifacts and local simulations only when the task authorizes them.

## Recipient data

- Do not invent REP sources, universes, migration semantics, snapshot blocks, thresholds, exclusions, or addresses.
- Record chain ID, block number/hash/timestamp, source contracts, discovery method, rules, script commit, timestamp,
  and output checksum.
- Validate every address, reject malformed and zero addresses, normalize comparisons, checksum human-facing output,
  deduplicate deterministically, and sort canonically.
- Use raw integer balances and bigint; fail closed when historical state is unavailable.
- Give every inclusion or exclusion a stable reason code and affected-address report.
- Generate JSON, reviewable CSV, summaries, checksums, batch manifests, and reconciliation reports.
- Never manually edit generated production manifests.
- The final unique manifest count must exactly equal distributionCap.

## Required validation

Run proportionate checks after changes and the full suite for a candidate:

~~~bash
forge fmt --check
forge build
forge build --sizes
forge test
forge test -vvv
forge test --gas-report
FOUNDRY_SNAPSHOTS=/tmp/rep-alert-snapshot-values \
  forge snapshot --snap /tmp/rep-alert-gas.snapshot
forge coverage
slither .
(cd ops && bun install --frozen-lockfile)
(cd ops && bun run check)
make check
git diff --check
~~~

Inspect ABI, method identifiers, storage layout, events, and errors for contract changes. Classify every compiler or
Slither finding; do not suppress it without a documented reason. Coverage and passing tests are diagnostics, not a
security guarantee.

## Git discipline

- Before editing, inspect git status, git diff, and recent commits.
- Preserve unrelated work and never reformat unrelated files.
- Keep changes small, reviewable, and covered by tests.
- Use Conventional Commits and do not combine dependency upgrades with behavior changes.
- Review the full diff and git diff --check before staging.
- Do not blindly stage all files, rewrite shared history, force-push, or commit secrets.
- Contract and recipient-data changes require separate human review.

After changes, report behavior, security implications, tests, commands, unresolved risks, and deployment-artifact
impact. Use evidence-limited language such as “No issue was observed in the tested paths”; never call the work an
audit or claim vulnerabilities are absent.
