# Foundation Setup Report

> Historical record: this report reflects the repository and toolchain at the time it was generated. Current policy is defined by `AGENTS.md` and current project configuration.

## Overall status

**PASS WITH WARNINGS**

The repository foundation is initialized and reproducible. Foundry, Bun, documentation, CI, dependency pins, the empty production directory structure, and the offline TypeScript foundation test are present. All required final verification commands exited successfully.

No production contract, token, recipient-selection logic, migration logic, RPC client, wallet, key, keystore, deployment, or transaction was created or executed.

## Initial repository state

The initial repository contained:

```text
.agents/
.codex/
.git/
AGENTS.md
TOOLCHAIN_SETUP_REPORT.md
```

Initial Git commands reported that the directory was not a valid work tree. Inspection showed no Git objects, refs, configuration, remotes, or files under `.git/`.

## Invalid `.git/` resolution

The apparent `.git/` was a read-only synthetic `tmpfs` mount provided by the execution sandbox. The real filesystem view contained no `.git/` directory, so there was no metadata or history to move or recover.

The first authorized move attempt failed with:

```text
mv: cannot stat '.git': No such file or directory
```

`findmnt -T .git` then confirmed the sandbox-only read-only mount. To preserve the required audit trail, an empty timestamped backup directory representing that confirmed-empty placeholder was created at:

```text
/home/goddard/repos/augur-rep-notice.git-placeholder-backup-20260716T120538-0300
```

The backup was not deleted. A real Git repository was then initialized on branch `main` with `git init -b main`. No nested Git repository was created.

## Bun installation

- Resolved stable release: `1.3.14`
- Release tag: `bun-v1.3.14`
- Release commit: `0d9b296af33f2b851fcbf4df3e9ec89751734ba4`
- Draft: No
- Prerelease: No
- Official installer: `https://bun.com/install`
- Installer SHA-256 at execution: `bab8acfb046aac8c72407bdcce903957665d655d7acaa3e11c7c4616beae68dd`
- Installation command form: inspected official script with the exact `bun-v1.3.14` argument
- Installation location: `~/.bun/bin/bun`
- Verified version: `1.3.14`
- Verified revision: `1.3.14+0d9b296af`
- Repository pin: `.bun-version` and `ops/package.json` both pin `1.3.14`

The operating system already had `/usr/bin/bun` at version `1.3.14`, but the official pinned installation was still completed as required. Final verification put `~/.bun/bin` first on `PATH`.

### Foundation closeout identity check

The apparent Bun version mismatch came from two different binaries built from the same release commit:

- `/usr/bin/bun` was a distribution-provided build reporting `1.3.14-canary.1+0d9b296af`.
- `~/.bun/bin/bun` was the official stable build reporting `1.3.14+0d9b296af`.

The official `bun-v1.3.14` release is commit `0d9b296af33f2b851fcbf4df3e9ec89751734ba4`. The stable binary was already installed, so no version or dependency pin changed. Fish PATH precedence was corrected to select `~/.bun/bin/bun`.

## Disposable Bun smoke test

The disposable project verified:

- `bun init`
- exact dependency installation
- text-based `bun.lock`
- `bun install --frozen-lockfile`
- direct TypeScript execution
- `tsc --noEmit`
- `bun test`
- viem import
- Zod import
- `@types/bun`
- Biome formatting and linting
- filesystem write/read/delete
- explicit decimal-string conversion before JSON serialization of a `bigint`
- Ethereum address validation
- deterministic address sorting
- zero untrusted dependency lifecycle scripts
- no RPC or other network request during test execution

Exact smoke-test dependencies:

| Dependency | Version |
|---|---:|
| TypeScript | `7.0.2` |
| viem | `2.55.2` |
| Zod | `4.4.3` |
| `@types/bun` | `1.3.14` |
| `@biomejs/biome` | `2.5.4` |

The disposable directory and all temporary smoke-test files were removed.

## Repository tree

```text
.
├── .bun-version
├── .env.example
├── .github/
│   └── workflows/
│       └── contracts.yml
├── .gitignore
├── .gitmodules
├── AGENTS.md
├── DEPLOYMENT_RUNBOOK.md
├── FOUNDATION_SETUP_REPORT.md
├── Makefile
├── README.md
├── ROADMAP.md
├── SPEC.md
├── THREAT_MODEL.md
├── TOOLCHAIN_SETUP_REPORT.md
├── data/
│   ├── batches/.gitkeep
│   ├── exclusions/.gitkeep
│   ├── reports/.gitkeep
│   └── snapshots/.gitkeep
├── deployments/
│   ├── local/.gitkeep
│   ├── mainnet/.gitkeep
│   └── sepolia/.gitkeep
├── foundry.lock
├── foundry.toml
├── lib/
│   ├── forge-std/
│   └── openzeppelin-contracts/
├── ops/
│   ├── README.md
│   ├── biome.json
│   ├── bun.lock
│   ├── package.json
│   ├── src/.gitkeep
│   ├── test/foundation.test.ts
│   └── tsconfig.json
├── remappings.txt
├── script/.gitkeep
├── src/.gitkeep
└── test/
    ├── fork/.gitkeep
    ├── fuzz/.gitkeep
    ├── invariant/.gitkeep
    └── unit/.gitkeep
```

## Files created

- Git and toolchain configuration: `.gitignore`, `.gitmodules`, `.bun-version`, `.env.example`, `foundry.toml`, `foundry.lock`, `remappings.txt`
- Solidity dependency submodules: `lib/forge-std`, `lib/openzeppelin-contracts`
- Project commands: `Makefile`
- Documentation: `README.md`, `SPEC.md`, `THREAT_MODEL.md`, `ROADMAP.md`, `DEPLOYMENT_RUNBOOK.md`, `ops/README.md`, this report
- Bun package: `ops/package.json`, `ops/bun.lock`, `ops/tsconfig.json`, `ops/biome.json`
- Foundation test: `ops/test/foundation.test.ts`
- CI: `.github/workflows/contracts.yml`
- Empty-directory markers under `src/`, `script/`, `test/`, `ops/src/`, `data/`, and `deployments/`

## Files modified

- `AGENTS.md`: tooling-only changes adopting Bun, Biome, direct Bun TypeScript execution, `tsc --noEmit`, and uv-managed Python CLI tools

All product invariants, key restrictions, broadcast prohibitions, deployment controls, release gates, and product non-goals were preserved.

## Exact `AGENTS.md` diff

```diff
--- a/AGENTS.md
+++ b/AGENTS.md
@@ -179,2 +179,4 @@
-- Node.js;
-- pnpm;
+- Bun as the repository package manager, TypeScript runtime, and TypeScript test runner;
+- Node.js as a compatibility fallback only;
+- TypeScript with `tsc --noEmit` for static type checking;
+- Biome for TypeScript formatting and linting;
@@ -185,0 +188,14 @@
+Use direct Bun execution for TypeScript entrypoints. Do not add `tsx`.
+
+Do not run npm or pnpm repository installs.
+
+Do not introduce `pnpm-lock.yaml`, `package-lock.json`, or `yarn.lock`.
+
+Use Bun only for JavaScript and TypeScript dependencies. Use Foundry's native Git-based workflow for Solidity dependencies.
+
+Keep Bun-specific runtime APIs to a minimum so operational code remains portable and easy to review.
+
+Do not add a Python project unless Python becomes concretely necessary.
+
+Use `uv tool` for pinned Python CLI tools. Do not install repository Python tooling with system `pip`.
+
@@ -239 +255 @@
-│   ├── pnpm-lock.yaml
+│   ├── bun.lock
@@ -803 +819 @@
-Use repository-defined pnpm scripts, expected to include equivalents of:
+Use repository-defined Bun scripts, expected to include equivalents of:
@@ -806,8 +822,8 @@
-pnpm install --frozen-lockfile
-pnpm typecheck
-pnpm lint
-pnpm test
-pnpm snapshot:build
-pnpm snapshot:validate
-pnpm batches:create
-pnpm distribution:reconcile
+bun install --frozen-lockfile
+bun run typecheck
+bun run lint
+bun test
+bun run snapshot:build
+bun run snapshot:validate
+bun run batches:create
+bun run distribution:reconcile
@@ -814,0 +831,14 @@
+
+Run TypeScript entrypoints directly with Bun rather than `tsx`.
+
+Always run `tsc --noEmit`; successful Bun transpilation is not evidence that type checking passed.
+
+### 14.5 Python CLI tooling
+
+Use pinned, isolated `uv tool` installations for Python command-line tools:
+
+```bash
+uv tool install <tool>==<version>
+```
+
+Do not create Python project files until a concrete repository requirement justifies them.
```

The reconstructed pre-change file matched the initial SHA-256:

```text
0f838281cc1b37b7575781a302142b52b3edfb90f8c9ee986d61e7cc7d2eb39a
```

## Foundry configuration

```text
source directory: src
test directory: test
script directory: script
output directory: out
library directory: lib
cache directory: cache
Solidity compiler: 0.8.36
optimizer: enabled
optimizer runs: 200
via IR: false
verbosity: 2
filesystem permissions: none
```

No RPC endpoint, API key, explorer configuration, wallet configuration, or filesystem write permission is present.

## Solidity dependencies

| Dependency | Exact tag | Commit |
|---|---|---|
| forge-std | `v1.16.1` | `620536fa5277db4e3fd46772d5cbc1ea0696fb43` |
| OpenZeppelin Contracts | `v5.6.1` | `5fd1781b1454fd1ef8e722282f86f9293cacf256` |

Both exact-tag checks passed. Foundry's initializer initially selected forge-std `v1.16.2`; the submodule and `foundry.lock` were corrected to the required `v1.16.1` before verification.

OpenZeppelin's pinned upstream submodule contains its own development lockfiles and nested test dependencies. Those are upstream contents, not repository package-manager artifacts. The project root and `ops/` contain no npm, pnpm, or Yarn lockfile.

## Bun package configuration

| Category | Package | Exact version |
|---|---|---:|
| Runtime | viem | `2.55.2` |
| Runtime | Zod | `4.4.3` |
| Development | TypeScript | `7.0.2` |
| Development | `@types/bun` | `1.3.14` |
| Development | `@biomejs/biome` | `2.5.4` |

`trustedDependencies` is empty. `bun pm untrusted` reported zero untrusted dependencies with lifecycle scripts.

## CI configuration

- Workflow: `.github/workflows/contracts.yml`
- Events: pull requests and pushes to `main`
- Runner: Ubuntu
- Bun: exact repository pin
- Foundry: exact local-compatible stable release `v1.7.1`
- uv: `0.11.28`
- Slither: `0.11.5`, installed through `uv tool`
- Secrets: none configured
- RPC: none configured
- Broadcast: no transaction commands
- Slither: conditional on production `.sol` source existing

Pinned action commits:

| Action | Release | Commit |
|---|---|---|
| `actions/checkout` | `v7.0.0` | `9c091bb21b7c1c1d1991bb908d89e4e9dddfe3e0` |
| `oven-sh/setup-bun` | `v2.2.0` | `0c5077e51419868618aeaa5fe8019c62421857d6` |
| `foundry-rs/foundry-toolchain` | `v1.9.0` | `b00af27efadbc7b4ca8b82abbd903b17cc874d2a` |
| `astral-sh/setup-uv` | `v8.3.2` | `11f9893b081a58869d3b5fccaea48c9e9e46f990` |

Bun's YAML parser successfully parsed the workflow and confirmed 15 steps.

## Full verification results

| Check | Result |
|---|---|
| Valid Git work tree on `main` | PASS |
| Git submodule status | PASS |
| `bun --version` | PASS — `1.3.14` |
| `bun --revision` | PASS — `1.3.14+0d9b296af` |
| `forge fmt --check` | PASS — expected no-source warning |
| `forge build --sizes` | PASS — nothing to compile |
| `forge test` | PASS — nothing to compile |
| `forge test --gas-report` | PASS — nothing to compile |
| `forge coverage` | PASS — nothing to compile |
| `bun install --frozen-lockfile` | PASS — no changes |
| `bun run format:check` | PASS |
| `bun run lint` | PASS |
| `bun run typecheck` | PASS |
| `bun test` | PASS — 1 passed, 0 failed |
| `make check` | PASS |
| Slither target | PASS — explicitly skipped because no production Solidity exists |
| Root `package-lock.json` absent | PASS |
| Root `pnpm-lock.yaml` absent | PASS |
| Root `yarn.lock` absent | PASS |
| Root `.env` absent | PASS |
| Project-managed alternate JavaScript lockfiles absent | PASS |
| `ops/bun.lock` present and text based | PASS |
| `foundry.toml` resolves compiler `0.8.36` | PASS |
| forge-std exact tag and commit | PASS |
| OpenZeppelin exact tag and commit | PASS |
| CI YAML parse | PASS |
| Immutable CI action references | PASS |
| Production Solidity file search | PASS — no output |
| Python project file search | PASS — no output |

## Warnings, failures, and remediations

1. The initial restricted `bun init` could not access Bun's default temporary directory and returned `Unexpected accessing temporary directory`. Setting a disposable `BUN_TMPDIR` alone did not resolve the sandbox restriction. The smoke test was rerun with local-only permission and all temporary paths confined to `/tmp`; it passed.
2. One disposable `bun init` retry was accidentally started from `/tmp` rather than its intended child directory. The exact generated files were identified by timestamp and removed immediately before the clean retry.
3. The first disposable Biome check scanned the sandbox-only Bun cache because that cache was temporarily nested inside the smoke project. The cache was excluded from the disposable Biome scope, and the full clean command set then passed.
4. The invalid `.git/` was a synthetic read-only sandbox mount rather than real filesystem metadata. The required parent backup path was created as an empty representation, and the real repository was initialized without overwriting recoverable data.
5. The first combined Foundry verification used a command-scoped PATH assignment, so later chained commands could not find `forge`. It was rerun with absolute Foundry paths and passed.
6. A preliminary fresh Fish invocation emitted an fnm multishell permission warning under the restricted sandbox, although `make check` still passed. The final required verification was rerun with local-only runtime permission and completed without that warning.
7. Foundry emits expected warnings when formatting and coverage run with no Solidity source. All commands exit `0`; no warning was suppressed.
8. `git diff --cached --check` reports three trailing-space locations in the pre-existing `TOOLCHAIN_SETUP_REPORT.md`. They are intentional Markdown hard breaks on its date, operating-system, and architecture lines. That pre-existing report was preserved rather than reformatted as unrelated work.

No genuine Bun runtime or dependency incompatibility remained unresolved.

## Security and deployment impact

- Security invariants were not relaxed.
- No production behavior exists yet.
- No recipient data was created, queried, filtered, or modified.
- No public Ethereum RPC was accessed.
- No wallet, account, mnemonic, private key, keystore, or `.env` was created or inspected.
- No Anvil deployment or Forge deployment script was executed.
- No transaction was signed, submitted, sent, or broadcast.
- No Safe transaction was created or submitted.
- No deployment artifact changed because no deployment artifact exists.
- This work has not received an independent security audit.

## Git status

The repository is on branch `main` with no prior commits. At report generation, the intended foundation files and corrected submodule commits were pending final staging and review. The required policy is to create exactly one initial commit only after every check passes, with message:

```text
chore: initialize project foundation
```

No remote push is planned or authorized.

## Exact recommended next task

Complete and approve the product-specification milestone: resolve the final notice metadata, authority model, irreversible-finalization semantics, recipient eligibility and migration definitions, snapshot requirements, exclusions, canonical communications language, canary limits, and stop conditions in `SPEC.md` and `THREAT_MODEL.md`.

Do not implement the production contract or recipient tooling until those maintainer decisions are explicitly approved.
