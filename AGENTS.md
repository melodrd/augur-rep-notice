# AGENTS.md

`MigrateRepV2Token` (CHECK AUGUR MIGRATION / `CHECKAUGUR`) is a conventional, transferable, fixed-supply ERC-20 **notice token**, plus its deployment script and offline recipient tooling. It is not REP, REPv2, a migration claim, migration eligibility, a redemption right, a reward, a governance asset, or an investment asset. Treat contract changes, recipient transformations, and deployment artifacts as security-sensitive production infrastructure: a passing build is not an audit, safety, or deployment readiness.

**Authoritative behavior is [docs/SPEC.md](docs/SPEC.md); deploy/operate steps are [docs/OPERATIONS.md](docs/OPERATIONS.md).** When instructions conflict, follow, in order: explicit human instructions for the current task, SPEC, OPERATIONS, then existing tests and code comments. Stop before changing code when a request conflicts with a security invariant.

## Invariants that must not change

Any behavioral change requires specification, threat, acceptance-criteria, and test review. See SPEC for the full contract; the load-bearing rules:

- Inherit only OpenZeppelin `ERC20` (v5.6.1). Do not override its externals or internals (`_update`, `_transfer`, `_approve`, `_spendAllowance`) absent a demonstrated compatibility defect.
- The whole supply is minted to `address(this)` once in the constructor; no function increases `totalSupply()` afterward, and `distribute` is the sole allocation-exit path (no reserve recovery, rescue, or arbitrary transfer-from-contract).
- `distribute` is distributor-only, atomic, one token per recipient. Precedence: authorization, finalized, empty, max batch, cap, then per-recipient (zero, token contract, already-distributed — which also catches in-batch duplicates).
- `wasInitialRecipient` only changes false→true; it is distribution history, not a balance or eligibility claim.
- `finalizeDistribution` is distributor-only and irreversible, and closes distribution only — transfers/approvals/`transferFrom` continue.
- The token contract is neither a valid recipient nor a valid distributor; every other address (including contracts) is valid for both — never filter on `code.length`.
- Keep **remaining initial allocation** `(recipientCap - totalInitialRecipients) * 1e18` and **token contract balance** `balanceOf(address(this))` strictly distinct: holders may transfer CHECKAUGUR back to the contract, so the balance is the allocation plus returned tokens and is not predictable off-chain.

## Prohibited functionality

Do not add: holder or delegated burn; ownership, roles, authority transfer, or recovery; proxy, upgrade, `delegatecall`, or `selfdestruct`; post-deployment, public, signature, or claim mint; permit or pause; taxes, fees, reflection, rebasing, blacklist, allowlist, cooldowns, wallet/transaction limits, or trading switches; callbacks, hooks, bridges, oracles, arbitrary external calls, payable paths, `receive`/`fallback`, withdrawal, or token recovery; REP or migration-contract interaction; mutable metadata, token URI, or migration URL in storage. Do not weaken tests, suppress findings, silently change behavior, or fabricate liquidity/volume/price data.

## Code quality

- **Solidity:** keep the production contract small and conventional. Exact pragmas, SPDX, NatSpec, named constants, custom errors, precise events; do not wrap OpenZeppelin errors. Prefer calldata arrays, cached lengths, a single post-loop counter update, and checks before effects. Avoid assembly, low-level calls, and unchecked arithmetic without a documented proof and focused tests. No test-only production functions, dead code, or unresolved TODOs. `MAX_BATCH_SIZE` is measurement-derived; do not raise it without new gas measurements.
- **TypeScript (`ops/`):** Bun only — never npm/pnpm or their lockfiles; install `--frozen-lockfile`. `tsc --noEmit` and Biome are mandatory. Use viem for address/ABI handling and `bigint` for on-chain integers — never floating point. The manifest and plan are **lean**: store only authoritative inputs and derive the rest (cap, supply, batch split) on demand. The recipient cap is **derived** from the unique list and must never become a caller-supplied option. Provenance is validated for shape, never invented or verified. `ops/` is offline only: it must never gain an RPC call, signer, key access, or authoritative nonce/fee/gas.

## Safety boundary

- Work locally. Do not access an Ethereum RPC without explicit authorization.
- Do not request, inspect, create, import, or store a private key, seed phrase, keystore, or secret, and do not operate the production distributor wallet. Keep secrets out of env files, commands, logs, docs, and Git.
- Do not deploy, verify on-chain, sign, submit, or broadcast. Agents may prepare unsigned artifacts and local simulations only when the task authorizes them.

## Validation

Run proportionate checks after changes, and the full gate for a candidate:

```bash
make check         # fmt-check, lint, build+sizes, ordinary tests, ops-check, Slither, consistency
make coverage      # production coverage (100% of src)
make gas           # isolated gas measurements
make check-deep    # deep fuzz/invariant profile, once
git diff --check
```

Inspect ABI, method identifiers, storage layout, events, and errors for contract changes; classify every compiler or Slither finding rather than suppressing it. Use Conventional Commits, keep changes small and test-covered, stage explicit files, and never push, force-push, or commit secrets. Report behavior, tests, and unresolved risks with evidence-limited language — never call the work an audit.
