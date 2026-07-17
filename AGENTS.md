# AGENTS.md

## Purpose

This repository contains `MigrateRepV2Token` (MIGRATE REPV2 / `MREP2`), a conventional, transferable, fixed-supply ERC-20 notice token, plus its deployment script and operational tooling. MREP2 is not REP, REPv2, migrated REP, a migration claim, migration eligibility, a redemption right, a reward, a governance asset, or a project-supported investment asset.

Treat contract changes, recipient transformations, deployment preparation, and transaction artifacts as security-sensitive production infrastructure. A passing build is not evidence of an audit, safety, usefulness, or deployment readiness.

## Source of authority

When instructions conflict, follow, in order: explicit human instructions for the current task; [docs/SPEC.md](docs/SPEC.md); [docs/OPERATIONS.md](docs/OPERATIONS.md); [docs/VALIDATION.md](docs/VALIDATION.md); this file; then existing tests and code comments. Stop before changing code when a request conflicts with a security invariant or approved behavior.

## Design principles

MREP2 must behave like an ordinary ERC-20 at all times and earn trust through conventional behavior, transparent code, verified metadata, and accurate communication — never by manipulating wallet, explorer, or reputation systems, or by fabricating liquidity, volume, or price.

- Inherit only OpenZeppelin `ERC20`. Do not override ERC-20 externals or internals (`_update`, `_transfer`, `_approve`, `_spendAllowance`) absent a demonstrated compatibility defect.
- The whole supply is minted to `address(this)` once in the constructor. No function may increase `totalSupply()` afterward.
- The initial allocation leaves the contract only through distributor-only `distribute`. There is no reserve recovery, rescue, or arbitrary transfer-from-contract path.
- `wasInitialRecipient` only changes false to true and is distribution history, not a balance or eligibility claim.
- `finalizeDistribution` is irreversible and closes distribution only; it never freezes standard token behavior.
- The token contract is neither a valid recipient nor a valid distributor. Every other address, including contracts, is valid for both: never filter recipients on `code.length`.
- Keep **remaining initial allocation** `(recipientCap - totalInitialRecipients) * 1e18` and **token contract balance** `balanceOf(address(this))` strictly distinct. Holders may transfer MREP2 back to the contract, so the balance is the allocation plus returned tokens and is not predictable off-chain.

## Current contract invariants

- Metadata is fixed: `MIGRATE REPV2`, `MREP2`, 18 decimals (inherited, not overridden). `TOKEN_PER_RECIPIENT == 1e18`, `MAX_BATCH_SIZE == 200`.
- Construction sets nonzero immutable `distributor` and `recipientCap`, computes `maximumSupply = recipientCap * 1e18` (overflow-checked), and mints it to the token contract. Deployer and distributor start at zero.
- Constructor precedence: zero distributor, token-contract distributor, zero cap, then overflow.
- `totalSupply() == maximumSupply` forever; `totalInitialRecipients <= recipientCap`.
- `distribute(address[])` is the sole allocation-exit path, distributor-only, atomic, one token per recipient, one standard `Transfer` per recipient in calldata order.
- Distribution precedence: authorization, finalized, empty, maximum batch, recipient cap, then per-recipient (zero, token contract, then already-distributed which also catches in-batch duplicates).
- `finalizeDistribution()` is distributor-only, irreversible, and emits `DistributionFinalized`; transfers/approvals/`transferFrom` continue afterward.
- Standard ERC-20 transfer, approve, allowance, and transferFrom are unrestricted, including zero-value transfers and the OpenZeppelin infinite-allowance rule.

Any behavioral change requires specification, threat, acceptance-criteria, and test review.

## Prohibited functionality

Do not add: holder or delegated burn (`ERC20Burnable`, `burn`, `burnFrom`); ownership, roles, authority transfer, successor, or recovery; proxy, upgrade, `delegatecall`, or `selfdestruct`; post-deployment, public, signature, or claim mint; permit, pause, or allowance-mutation helpers; taxes, fees, reflection, rebasing, liquidity, DEX/router detection, blacklist, allowlist, cooldowns, wallet/transaction limits, or trading switches; callbacks, hooks, bridges, oracles, arbitrary external calls, `transferAndCall`, `approveAndCall`, payable paths, `receive`, `fallback`, withdrawal, or token recovery; REP or migration-contract interaction; mutable metadata, token URI, or migration URL in storage.

Do not weaken tests, suppress findings, or silently change behavior. Do not fabricate liquidity, volume, pricing, or market-cap data.

## Solidity quality

- Keep the production contract small, explicit, and conventional; inherit OpenZeppelin rather than reimplementing ERC-20.
- Use exact pragmas, SPDX identifiers, NatSpec, named constants, custom errors, and precise events. Do not wrap OpenZeppelin errors.
- Prefer calldata arrays, cached lengths and counters, a single post-loop counter update, checks before effects, and minimal storage.
- Avoid assembly, low-level calls, magic values, unsafe casts, and dynamic dispatch. Do not use unchecked arithmetic without a documented proof, benchmark, and focused tests.
- No test-only production functions, dead code, commented alternatives, unresolved TODOs, or warning suppressions. Preserve atomic rollback, event order, permanent history, and exact accounting.

## Gas discipline

Gas efficiency is a first-class requirement, subordinate only to correct standard ERC-20 behavior, security, auditability, and accurate accounting. Optimizations must be measured before and after, material across the expected campaign, behavior-preserving, conventional, test-proven, and documented. Do not create a performance commit for trivial or test-only savings. `MAX_BATCH_SIZE` is measurement-derived so the worst-case successful call stays well under the Osaka transaction gas cap (16,777,216); do not raise it without new measurements.

## Toolchain

Canonical settings in `foundry.toml`: Solidity 0.8.36, EVM Osaka, optimizer enabled with 200 runs, via IR disabled, pinned OpenZeppelin Contracts v5.6.1. Use Foundry, forge-std, and Slither. CI pins Foundry 1.7.1, Slither 0.11.5, Bun 1.3.14, and uv 0.11.28. Do not add another Solidity framework without approval. Pin dependencies to tags or immutable commits and isolate dependency upgrades from behavioral changes. Build-time linting is disabled because it scans test code; production Solidity is linted with `forge lint src script`.

## TypeScript operations

Bun is the sole JavaScript package manager; never use npm or pnpm, and never create their lockfiles. Install with `bun install --frozen-lockfile`. `tsc --noEmit` is mandatory type checking; Biome handles formatting and linting. Use viem for address and ABI handling, deterministic JSON/CSV, cryptographic checksums, and `bigint` for on-chain integers — never floating point. Keep dependencies minimal and prefer plain explicit parsers to a schema library unless one materially improves boundary validation. The recipient tooling must validate and normalize addresses, reject the zero address and case-insensitive duplicates, sort canonically, batch within the operational size, store no personal data, and never repair an address, sign, or broadcast.

- The manifest and plan are **lean**: store only authoritative inputs and derive everything else (cap, maximum supply, batch split, counts) on demand. Do not reintroduce stored derived fields, per-batch or embedded self-checksums, or cross-field validation of duplicated values.
- The recipient cap is **derived** from the final unique recipient list and must never become a caller-supplied option again: that is what makes undisclosed headroom impossible. Empty recipient lists are rejected.
- Provenance is mandatory and never invented, defaulted, or derived. Validate its shape; do not fill it in. It is recorded and validated structurally, never independently verified.
- `provenance.sourceChainId` (where the snapshot was read) and the plan's `targetChainId` (where MREP2 is deployed) are intentionally separate and must never be required to match: a mainnet snapshot must be able to drive a Sepolia plan.
- Integrity is a detached hash, not a self-checksum: emit `manifest.json.sha256` and `plan.json.sha256` over the exact emitted bytes. Detached hashes detect accidental change; they do not prove approval or authenticity.
- `ops/src/distribution-plan.ts` is offline only. It must never gain an RPC call, a signer, or an authoritative nonce, fee, or gas figure, and must not grow into a general transaction framework. It re-validates the manifest and decodes its own calldata before emitting a plan.
- The manifest format is version 1 with no migration path: there is no production manifest requiring backward compatibility, so change the format cleanly rather than adding schema-version machinery.

## Safety boundary

- Work locally unless the task explicitly authorizes another environment.
- Do not access an Ethereum RPC without explicit authorization.
- Do not request, inspect, create, import, or store a private key, seed phrase, keystore, or secret, and do not operate the production distributor wallet.
- Do not put secrets in environment files, commands, logs, documentation, or Git.
- Do not deploy, verify on-chain, sign, submit, or broadcast. Sepolia work requires explicit instruction and a separate human-controlled test-only key.
- Agents may prepare unsigned artifacts and local simulations only when the task authorizes them.

## Required validation

Run proportionate checks after changes and the full gate for a candidate:

```bash
make check         # fmt-check, lint, build+sizes, ordinary tests, ops-check, Slither, consistency
make coverage      # production coverage
make gas           # isolated gas measurements
make check-deep    # deep fuzz/invariant profile, once
git diff --check
```

Inspect ABI, method identifiers, storage layout, events, and errors for contract changes. Classify every compiler or Slither finding; do not suppress it without a documented reason. Coverage and passing tests are diagnostics, not a security guarantee.

## Git discipline

Inspect status, diff, and recent commits before editing. Preserve unrelated work; never reformat unrelated files. Keep changes small, reviewable, and covered by tests. Use Conventional Commits and do not combine dependency upgrades with behavior changes. Review the full diff and `git diff --check`, and stage explicit files rather than `git add .`. Do not rewrite shared history, force-push, push, or commit secrets. Contract and recipient-data changes require separate human review. Report behavior, security implications, tests, commands, and unresolved risks with evidence-limited language; never call the work an audit or claim vulnerabilities are absent.
