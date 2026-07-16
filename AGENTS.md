# AGENTS.md

## 1. Purpose

This repository contains the smart-contract and operational tooling for an Augur REP migration-awareness experiment.

The project may distribute a non-economic on-chain notice to selected REP holders so that supported wallet interfaces may surface a migration reminder. The notice is not migrated REP, replacement REP, a claim token, a reward, a governance asset, or a tradable instrument.

This is a security-sensitive Ethereum project. Treat every contract change, recipient-data transformation, deployment script, and transaction artifact as production infrastructure.

This file defines the standing instructions for Codex and any other coding agent working in this repository.

---

## 2. Instruction priority

When instructions conflict, follow this order:

1. Explicit instructions from the human maintainer in the current task.
2. `docs/product/SPEC.md`, once approved and committed.
3. `docs/security/THREAT_MODEL.md`.
4. `docs/operations/DEPLOYMENT_RUNBOOK.md`.
5. This `AGENTS.md`.
6. Existing tests and code comments.
7. General conventions or agent preferences.

Do not reinterpret an approved product requirement merely to simplify the implementation.

When a requested change conflicts with a security invariant in this file, stop and clearly identify the conflict before changing code.

---

## 3. Project status and default operating mode

Assume the project is experimental until the maintainers explicitly mark a release as production-ready.

`docs/product/SPEC.md` is approved for implementation planning as of 2026-07-16. Its product and contract behavior must not be reinterpreted for implementation convenience. Any behavioral change requires an explicit specification revision, threat-model review, and corresponding acceptance-test updates.

Default operating mode:

- Work locally.
- Do not broadcast transactions.
- Do not handle production secrets.
- Do not modify mainnet recipient data without an explicit request.
- Do not deploy to mainnet.
- Do not submit Safe transactions.
- Do not weaken tests to make a change pass.
- Do not silently change contract behavior.

A passing build is not evidence that the system is safe, correct, useful, or ready for deployment.

---

## 4. Product objective

The system should enable Augur to test whether an unsolicited, clearly labeled, non-economic token notice can help eligible REP holders discover official migration information.

The system must optimize for:

- holder safety;
- clarity;
- minimal attack surface;
- reproducibility;
- verifiable recipient selection;
- low operational complexity;
- irreversible shutdown of distribution authority;
- accurate gas measurement;
- wallet-display testing;
- transparent public verification.

The system must not optimize for:

- token trading;
- token price discovery;
- speculative interest;
- liquidity;
- composability;
- governance;
- yield;
- upgradeability;
- arbitrary extensibility;
- promotional novelty.

---

## 5. Approved product architecture

Use these approved constraints:

- The notice token is an informational artifact only.
- It has no economic value.
- It grants no migration rights.
- It grants no claim rights.
- It grants no governance rights.
- It must never require a holder to approve, sign, transfer, swap, burn, bridge, or deposit anything.
- The canonical migration process exists independently from the notice token.
- Users must verify migration information through Augur's official surfaces.
- The token name and symbol are not identity guarantees.
- The deployed contract address is the canonical identifier.
- The fixed name is `Augur REP Migration Notice`.
- The fixed symbol is `REPNOTICE`.
- Every eligible recipient receives exactly one whole notice unit.
- Token decimals are `0`.
- Initial supply is `0`.
- One array-based `distribute(address[] recipients)` path serves canaries and batches.
- Distribution is strictly atomic: any invalid recipient reverts the complete call.
- The constructor receives one nonzero immutable authority and one nonzero immutable distribution cap.
- The exact distribution cap equals the unique-address count in the final approved recipient manifest.
- Authority transfer, recovery, successor nomination, and secondary administrators are absent.
- Ordinary transfers are disabled.
- `transferFrom` is disabled.
- Approvals are disabled.
- Allowance always returns zero.
- Operator approvals or permits are not supported.
- Burning is not supported.
- Minting or distribution becomes permanently impossible after finalization.
- Finalization is irreversible.
- Repeated finalization reverts.
- No upgrade mechanism exists.
- The contract does not custody REP.
- The contract does not custody ETH.
- The contract does not call the REP token.
- The contract does not call migration contracts.
- The contract does not execute arbitrary external calls.
- The contract does not contain payable functions.
- The contract does not expose withdrawal or recovery functions.
- The contract is a standalone minimal implementation and must not inherit OpenZeppelin token, ownership, access-control, pausing, proxy, upgrade, or generalized framework contracts.
- Mainnet authority is a dedicated 2-of-3 Safe with independent human signers. Agents may never operate it, sign for it, submit its transactions, or broadcast.

Any change to these assumptions requires an explicit update to `docs/product/SPEC.md` and corresponding tests.

---

## 6. Non-goals

Do not add any of the following unless a maintainer explicitly changes the written specification:

- DEX integration;
- liquidity pools;
- transfer taxes;
- rebasing;
- staking;
- vesting;
- pausing and unpausing normal token transfers;
- permit signatures;
- meta-transactions;
- ERC-1363 callbacks;
- ERC-777 hooks;
- ERC-4626 behavior;
- NFT functionality;
- URI or dynamic metadata systems;
- proxy contracts;
- upgradeable contracts;
- delegatecall-based modules;
- diamond patterns;
- governance modules;
- timelocks unrelated to an approved administrative design;
- bridges;
- cross-chain messaging;
- price oracles;
- token recovery helpers;
- arbitrary multicalls;
- arbitrary external-call executors;
- user claim flows;
- wallet-connect flows;
- frontend code before the contract and operational specification are stable.

Do not reuse the legacy generator-produced Solidity `0.7.x` contract as the production base. It may be retained only as historical reference.

---

## 7. Required technology stack

### 7.1 Smart-contract stack

Use:

- Solidity;
- Foundry;
- Forge;
- Anvil;
- Cast;
- `forge-std`;
- OpenZeppelin Contracts only if an explicit approved need outside the production notice contract is demonstrated;
- Slither for static analysis.

The approved notice contract must be standalone and must not inherit from OpenZeppelin `ERC20`, `Ownable`, `Ownable2Step`, `AccessControl`, `Pausable`, proxy, or upgradeable contracts. If implementation imports no OpenZeppelin code, remove the unused dependency later in a separate reviewed `chore(deps)` change.

Do not introduce Hardhat, Truffle, Brownie, or a second Solidity framework unless the maintainers explicitly approve the additional complexity.

### 7.2 Off-chain operations stack

Use:

- TypeScript;
- Bun as the repository package manager, TypeScript runtime, and TypeScript test runner;
- Node.js as a compatibility fallback only;
- TypeScript with `tsc --noEmit` for static type checking;
- Biome for TypeScript formatting and linting;
- viem for Ethereum RPC access;
- Zod or an equivalent schema validator for external data;
- deterministic JSON and CSV outputs;
- cryptographic checksums for final artifacts.

Use direct Bun execution for TypeScript entrypoints. Do not add `tsx`.

Do not run npm or pnpm repository installs.

Do not introduce `pnpm-lock.yaml`, `package-lock.json`, or `yarn.lock`.

Use Bun only for JavaScript and TypeScript dependencies. Use Foundry's native Git-based workflow for Solidity dependencies.

Keep Bun-specific runtime APIs to a minimum so operational code remains portable and easy to review.

Do not add a Python project unless Python becomes concretely necessary.

Use `uv tool` for pinned Python CLI tools. Do not install repository Python tooling with system `pip`.

Do not use floating-point arithmetic for token balances.

Use `bigint` for all on-chain integer values.

### 7.3 Version policy

- Pin the Solidity compiler exactly in `foundry.toml`.
- Initial target: Solidity `0.8.36`, unless the maintainers approve another exact version.
- Pin OpenZeppelin and `forge-std` to explicit tagged releases or immutable commit hashes.
- Commit dependency lockfiles and Foundry dependency metadata.
- Do not use floating tags such as `latest`, `master`, or `main`.
- Do not run dependency upgrades as part of unrelated work.
- Do not change compiler, optimizer, EVM-version, or IR settings without explicit approval.
- Put dependency upgrades in isolated, reviewable changes with a written rationale.

The repository configuration is the source of truth for versions after initialization.

---

## 8. Expected repository structure

Preserve this structure unless there is a documented reason to change it:

```text
.
├── AGENTS.md
├── README.md
├── docs/
│   ├── README.md
│   ├── product/
│   │   └── SPEC.md
│   ├── security/
│   │   └── THREAT_MODEL.md
│   ├── planning/
│   │   └── ROADMAP.md
│   ├── operations/
│   │   └── DEPLOYMENT_RUNBOOK.md
│   └── reports/
│       ├── TOOLCHAIN_SETUP_REPORT.md
│       └── FOUNDATION_SETUP_REPORT.md
├── foundry.toml
├── remappings.txt
├── Makefile
├── .env.example
├── .gitignore
│
├── src/
│   └── RepMigrationNotice.sol
│
├── test/
│   ├── unit/
│   ├── fuzz/
│   ├── invariant/
│   └── fork/
│
├── script/
│   ├── Deploy.s.sol
│   ├── Distribute.s.sol
│   ├── Finalize.s.sol
│   └── VerifyDeployment.s.sol
│
├── ops/
│   ├── package.json
│   ├── bun.lock
│   ├── tsconfig.json
│   └── src/
│       ├── build-snapshot.ts
│       ├── filter-recipients.ts
│       ├── validate-recipients.ts
│       ├── create-batches.ts
│       └── reconcile-distribution.ts
│
├── data/
│   ├── snapshots/
│   ├── exclusions/
│   ├── batches/
│   └── reports/
│
├── deployments/
│   ├── local/
│   ├── sepolia/
│   └── mainnet/
│
└── .github/
    └── workflows/
        └── contracts.yml
```

Generated build artifacts belong in ignored directories such as `out/`, `cache/`, and local temporary folders.

Do not commit secrets, RPC credentials, private recipient notes, or personal data.

---

## 9. Source-code design rules

### 9.1 General design

Prefer the smallest implementation that satisfies the approved specification.

Every externally callable function must have a clear reason to exist.

Avoid:

- inheritance depth;
- redundant roles;
- generic extension points;
- low-level calls;
- assembly;
- delegatecall;
- selfdestruct;
- fallback functions;
- receive functions;
- dynamic dispatch;
- unbounded storage iteration;
- hidden state transitions;
- owner-only convenience functions not required by the specification.

Use custom errors where they materially improve clarity and gas usage.

Use events for meaningful state transitions, including:

- successful distribution;
- permanent finalization.

Do not emit misleading events for failed or skipped recipients.

### 9.2 Administrative design

Use exactly one nonzero constructor-supplied immutable authority.

- The deployer receives no implicit privilege.
- The authority can distribute before finalization and can finalize.
- No authority transfer, acceptance, renunciation, successor nomination, recovery administrator, or secondary role exists.
- No `Ownable`, `Ownable2Step`, or role-based access-control system is permitted.
- No post-deployment authority handoff exists.
- If the authority is wrong, compromised beyond recovery, or unavailable, abandon or redeploy the candidate.

Mainnet authority policy:

- one dedicated Safe address is the immutable contract authority;
- exactly three independently controlled human signer addresses;
- threshold two;
- no enabled modules;
- no custom guard;
- a reviewed fallback handler appropriate to the frozen Safe version;
- no personal hot wallet, shared custody, delegated signing, or unrelated DeFi activity;
- agents may prepare unsigned review material only and may never operate the Safe.

Exact Safe address, signer identities, Safe version, and configuration evidence remain deferred gates. Do not invent them or claim organizational control without reviewed evidence.

### 9.3 Distribution behavior

The distribution mechanism must:

- expose one array-based distribution path for both one-address canaries and batches;
- reject an empty array;
- reject the zero address;
- prevent duplicate notices;
- revert the complete call for a duplicate within the array or a previously notified recipient;
- prevent a recipient from receiving more than one notice;
- preserve deterministic behavior;
- emit one `Transfer(address(0), recipient, 1)` event per successful recipient;
- reject distribution after finalization;
- enforce `totalSupply + recipients.length <= distributionCap`;
- avoid external calls;
- avoid unbounded loops over stored recipient sets;
- support operationally safe batches;
- expose read methods needed for verification.

Do not hardcode a maximum batch size until gas tests justify it.

When setting a batch maximum:

- measure entirely new recipients and include calldata cost;
- cover one-address, typical, maximum, duplicate, cap-boundary, and revert scenarios;
- use a pinned target-chain block gas limit;
- choose a compile-time maximum whose worst-case successful call uses no more than 50% of that limit;
- use a lower bound when calldata, tooling, execution, or Safe simulation is stricter;
- document the benchmark, block conditions, constant, and margin;
- obtain independent review before freezing the number.

### 9.4 Non-transferability

Ordinary token movement must remain impossible.

Tests must demonstrate that all applicable transfer paths fail, including:

- `transfer`;
- zero-value `transfer`;
- `transferFrom`;
- allowance-based movement;
- any mint path not authorized by the specification;
- any burn path.

Do not rely only on frontend restrictions.

Enforce non-transferability in explicit standalone contract logic. Do not create inherited movement or allowance paths.

### 9.5 Finalization

Finalization must:

- be explicitly authorized;
- be irreversible;
- permanently disable every distribution or mint path;
- emit a finalization event;
- preserve existing balances;
- not enable transfers;
- not transfer ownership automatically unless explicitly specified;
- be covered by unit, fuzz, and invariant tests.

No emergency unfinalize function is permitted.

No upgrade mechanism may bypass finalization.

### 9.6 Token metadata

Token metadata must be defined in the approved specification.

The contract metadata is fixed:

- name: `Augur REP Migration Notice`;
- symbol: `REPNOTICE`;
- decimals: `0`.

Hardcode or compile these values into the candidate. Do not accept constructor-configurable metadata. Do not place a migration URL in token metadata or contract storage.

Remember:

- Wallets may truncate token names.
- Wallets may hide unsolicited assets.
- Anyone can copy a token name and symbol.
- Metadata does not authenticate a contract.
- ERC-20 metadata is not a secure communication channel.

Do not encode a URL in a way that implies the user should trust an arbitrary clickable link presented by a wallet.

---

## 10. Security invariants

The following properties are mandatory unless `docs/product/SPEC.md` explicitly changes them.

### 10.1 Balance invariants

- No address has a balance greater than `1`.
- The zero address never has a balance.
- A distributed recipient's balance cannot move to another address.
- Distribution to an already-notified address cannot increase supply.
- Total supply equals the number of unique successfully notified addresses.
- Failed distribution attempts do not change balances or supply.

### 10.2 Authority invariants

- Only the approved authority can distribute.
- Only the approved authority can finalize.
- No unauthorized caller can modify balances.
- No deployer privilege exists unless the deployer is explicitly selected as authority.
- Finalization cannot be reversed.
- No code path can restore distribution authority after finalization.

### 10.3 Value-safety invariants

- The contract cannot transfer REP.
- The contract cannot approve REP.
- The contract cannot receive or retain ETH through intended interfaces.
- The contract cannot send ETH.
- The contract cannot execute arbitrary external calls.
- The contract cannot create allowances that permit notice movement.
- The contract cannot be upgraded.
- The contract cannot delegate execution to another implementation.

### 10.4 Operational invariants

- Every output batch is deterministic from its documented inputs.
- Recipient ordering is canonical.
- Duplicate recipient entries are detected before broadcast.
- Every excluded address has an explicit reason code.
- Snapshot artifacts identify chain ID and block number.
- Production artifacts are checksum-addressed or cryptographically hashed.
- Re-running the same snapshot pipeline against the same inputs produces the same output.

Invariant tests must exercise sequences of authorized and unauthorized actions rather than only isolated calls.

---

## 11. Solidity coding conventions

Use these conventions unless the existing repository establishes stricter ones:

- Exact pragma, not a range.
- SPDX identifier on every Solidity file.
- NatSpec on all external and public functions.
- Descriptive custom errors.
- Descriptive event names.
- Checks before effects.
- No external interactions unless approved.
- No magic numbers without named constants.
- No silent truncation or unsafe casting.
- No `tx.origin`.
- No block timestamp dependency unless explicitly required.
- No randomness.
- No inline assembly without explicit maintainer approval.
- No `unchecked` blocks without proof, tests, and comments.
- No storage variables that are never read.
- No public function merely for test convenience.
- No commented-out production code.
- No TODOs in release candidates.
- No disabling compiler warnings without explanation.

Keep contracts short and auditable.

Prefer one production contract over a generalized framework.

---

## 12. TypeScript and data-pipeline rules

Recipient selection is security- and reputation-sensitive business logic.

Do not treat it as routine ETL.

### 12.1 Required input metadata

Every snapshot must record:

- chain ID;
- RPC source category, without committing secrets;
- snapshot block number;
- snapshot block hash;
- snapshot timestamp;
- REP contract addresses queried;
- migration contract addresses queried;
- holder-discovery method;
- balance threshold;
- included REP versions or universes;
- exclusion rules;
- script commit hash;
- generation timestamp;
- output checksum.

### 12.2 Address handling

- Normalize and validate every Ethereum address.
- Preserve checksum formatting in human-facing outputs.
- Compare addresses case-insensitively through validated binary or normalized representations.
- Reject malformed addresses.
- Reject the zero address.
- Deduplicate deterministically.
- Sort outputs canonically.
- Do not guess or autocomplete addresses.
- Do not insert an address from prose unless it is independently validated.
- Do not silently classify an address as an EOA or contract.
- Do not automatically exclude contracts merely because bytecode exists.
- Record contract/exchange/protocol classifications as evidence-backed metadata.

### 12.3 Balance handling

- Use `bigint`.
- Record raw integer balances.
- Apply decimals explicitly.
- Never use JavaScript `number` for token balances.
- Never use floating-point threshold comparisons.
- Define snapshot semantics precisely: block number and state queried at that block.
- Fail closed when required historical state is unavailable.

### 12.4 Filtering

Every filtering rule must have:

- a stable identifier;
- a human-readable description;
- a deterministic implementation;
- tests;
- an output count;
- a report showing affected addresses;
- an explicit inclusion or exclusion reason.

Examples of reason codes:

```text
ALREADY_MIGRATED
BELOW_THRESHOLD
KNOWN_EXCHANGE
KNOWN_PROTOCOL_CONTRACT
BURN_ADDRESS
ZERO_ADDRESS
DUPLICATE
MANUAL_EXCLUSION_APPROVED
UNSUPPORTED_REP_VERSION
```

Do not silently drop records.

### 12.5 Outputs

Produce:

- machine-readable JSON;
- reviewable CSV;
- summary report;
- cryptographic checksum;
- batch manifests;
- reconciliation report.

A final batch manifest should include:

- batch number;
- recipient count;
- first and last canonical address;
- input artifact checksum;
- batch checksum;
- expected cumulative recipient count;
- expected cumulative total supply.

Do not edit generated production manifests manually.

Regenerate them from reviewed inputs.

---

## 13. Testing requirements

Every behavior change requires tests.

Do not mark a task complete until relevant tests pass.

### 13.1 Formatting and compilation

Run:

```bash
forge fmt --check
forge build
forge build --sizes
```

Treat compiler warnings as findings requiring review.

### 13.2 Unit tests

Unit tests must cover at least:

- constructor state;
- exact fixed name and symbol;
- zero decimals;
- initial total supply;
- initial authority;
- zero-authority rejection;
- initial immutable distribution cap;
- zero-cap rejection;
- deployer has no implicit privilege;
- successful one-recipient array distribution;
- successful multi-recipient array distribution;
- zero-address rejection;
- empty-array rejection;
- duplicate-address handling;
- duplicate entries within one batch;
- duplicates across separate batches;
- unauthorized distribution;
- unauthorized finalization;
- transfer rejection;
- `transferFrom` rejection;
- approval rejection;
- allowance always returning zero;
- absence of permit, allowance helpers, and burn functions;
- distribution before finalization;
- distribution after finalization;
- irreversible finalization;
- repeated-finalization rejection;
- supply accounting;
- immutable distribution-cap accounting;
- cap-boundary success and cap-overflow atomic failure;
- maximum-batch boundary after the constant is frozen;
- event contents;
- finalization below the cap;
- absence of authority-transfer, owner, secondary-role, recovery, external-call, payable, proxy, upgrade, delegatecall, fallback, and receive paths.

### 13.3 Fuzz tests

Fuzz tests must cover:

- arbitrary valid recipients;
- arbitrary unauthorized callers;
- arbitrary batch compositions;
- repeated recipients;
- zero-address placement;
- batch ordering;
- finalization timing;
- repeated finalization attempts;
- supply and balance properties.

Use assumptions sparingly.

Do not assume away the edge case being tested.

### 13.4 Invariant tests

At minimum, model:

- an authorized distributor;
- unauthorized callers;
- arbitrary recipients;
- distribution attempts;
- transfer attempts;
- approval attempts;
- finalization attempts.

Assert the security invariants defined in this file.

### 13.5 Fork tests

Mainnet-fork tests must:

- use a pinned block number;
- use documented contract addresses;
- query expected REP state;
- test snapshot assumptions;
- simulate deployment;
- simulate representative distribution batches;
- simulate finalization;
- measure gas;
- avoid broadcasts.

A fork test that depends on latest chain state is not reproducible.

### 13.6 Gas tests

Benchmark at least these batch sizes when feasible:

```text
1
10
25
50
100
200
500
```

Record:

- deployment gas;
- gas per batch;
- effective gas per recipient;
- calldata size;
- failure behavior;
- block gas safety margin.

Do not optimize gas by adding material complexity unless the savings are demonstrated and the security trade-off is accepted.

### 13.7 Coverage

Run:

```bash
forge coverage
```

Coverage is a diagnostic, not a security guarantee.

Do not add meaningless tests solely to increase a percentage.

### 13.8 Static analysis

Run:

```bash
slither .
```

Classify each result as:

- confirmed issue;
- false positive;
- accepted behavior;
- needs investigation.

Do not suppress or exclude a detector without a documented reason.

### 13.9 TypeScript tests

Test:

- schema validation;
- address normalization;
- duplicate detection;
- canonical sorting;
- balance parsing;
- threshold behavior;
- every exclusion rule;
- deterministic outputs;
- checksum generation;
- batch construction;
- reconciliation;
- malformed RPC responses;
- missing historical state;
- inconsistent block metadata.

Use fixtures with known expected outputs.

---

## 14. Standard command set

Prefer repository scripts or `make` targets that wrap these commands.

### 14.1 Solidity

```bash
forge fmt --check
forge build
forge build --sizes
forge test
forge test -vvv
forge test --gas-report
forge snapshot
forge coverage
slither .
```

### 14.2 Local chain

```bash
anvil
anvil --fork-url "$MAINNET_RPC_URL" --fork-block-number "$SNAPSHOT_BLOCK"
```

### 14.3 Fork tests

```bash
forge test \
  --match-path "test/fork/*.t.sol" \
  --fork-url "$MAINNET_RPC_URL" \
  --fork-block-number "$SNAPSHOT_BLOCK"
```

### 14.4 TypeScript

Use repository-defined Bun scripts, expected to include equivalents of:

```bash
bun install --frozen-lockfile
bun run typecheck
bun run lint
bun test
bun run snapshot:build
bun run snapshot:validate
bun run batches:create
bun run distribution:reconcile
```

Run TypeScript entrypoints directly with Bun rather than `tsx`.

Always run `tsc --noEmit`; successful Bun transpilation is not evidence that type checking passed.

### 14.5 Python CLI tooling

Use pinned, isolated `uv tool` installations for Python command-line tools:

```bash
uv tool install <tool>==<version>
```

Do not create Python project files until a concrete repository requirement justifies them.

Do not invent production commands when an existing script or runbook defines them.

---

## 15. Deployment safety policy

### 15.1 Broadcast prohibition

Codex must not broadcast any transaction unless the human maintainer explicitly requests that exact broadcast in the current task.

Even with such a request:

- mainnet broadcasts remain prohibited to the agent;
- production Safe submissions remain prohibited to the agent;
- private-key handling remains prohibited;
- the agent may prepare commands, calldata, manifests, and review material only.

Commands requiring special caution include:

```text
forge script --broadcast
cast send
cast wallet import
cast publish
safe transaction submission
hardware-wallet signing
keystore creation containing production keys
```

Do not run them autonomously.

### 15.2 Local deployment

Local Anvil deployment is allowed.

Use ephemeral test accounts only.

### 15.3 Sepolia

Sepolia deployment requires an explicit human instruction.

Before preparing a Sepolia broadcast:

- all local tests pass;
- static analysis is reviewed;
- deployment parameters are documented;
- the target chain ID is verified;
- the deployer is a Sepolia-only account;
- no production secret is exposed;
- the non-broadcast simulation succeeds.

The agent may generate the exact command but should not request a raw private key.

### 15.4 Mainnet

For mainnet, the agent may only:

- generate unsigned deployment artifacts;
- generate constructor arguments;
- generate Safe-compatible calldata;
- simulate transactions;
- compare bytecode;
- prepare verification commands;
- prepare a deployment checklist;
- prepare post-deployment checks.

The agent must not:

- sign;
- submit;
- broadcast;
- import production keys;
- ask the user to paste a seed phrase or private key;
- store a key in `.env`;
- operate the production Safe.

---

## 16. Deployment workflow

Follow this sequence unless the runbook defines stricter requirements.

### Phase 1: Specification

- Approve `docs/product/SPEC.md`.
- Approve `docs/security/THREAT_MODEL.md`.
- Define token metadata.
- Define administrative model.
- Define recipient eligibility.
- Define snapshot block.
- Define finalization conditions.
- Define canary size.
- Define stop conditions.

### Phase 2: Local implementation

- Implement minimal contract.
- Write unit tests.
- Write fuzz tests.
- Write invariant tests.
- Run static analysis.
- Generate gas benchmarks.

### Phase 3: Local operational simulation

- Build sample snapshot.
- Validate recipients.
- Create batches.
- Deploy to Anvil.
- Execute all batches locally.
- Reconcile balances and events.
- Finalize.
- Confirm post-finalization behavior.

### Phase 4: Pinned mainnet fork

- Use the approved block number.
- Query actual REP state.
- Reproduce recipient data.
- Simulate deployment and distribution.
- Verify gas assumptions.
- Generate final reports.

### Phase 5: Sepolia

- Deploy exact candidate bytecode.
- Verify source.
- Verify immutable authority configuration.
- Test distribution.
- Test finalization.
- Test wallet presentation.
- Record all transaction hashes and observations.

### Phase 6: Review

- Independent code review.
- Independent recipient-data review.
- Independent deployment-artifact review.
- Resolve static-analysis findings.
- Freeze dependencies.
- Tag candidate commit.

### Phase 7: Mainnet preparation

- Reproduce bytecode on a second environment.
- Generate unsigned transaction data.
- Simulate through the intended Safe.
- Confirm target chain and target addresses.
- Confirm contract metadata.
- Confirm canary recipients.
- Produce rollback and stop procedures.

### Phase 8: Human-controlled execution

The human operators:

- sign;
- submit;
- broadcast;
- verify;
- monitor;
- approve each rollout stage;
- finalize only after reconciliation.

---

## 17. Verification requirements

For every deployed environment, record:

- network name;
- chain ID;
- contract address;
- deployment transaction hash;
- deployer address;
- immutable authority address;
- immutable distribution cap;
- source commit;
- compiler version;
- optimizer settings;
- constructor arguments;
- creation bytecode hash;
- runtime bytecode hash;
- source-verification status;
- deployment timestamp;
- deployment block;
- finalization status;
- relevant transaction hashes.

Post-deployment checks must confirm:

- correct chain;
- correct contract address;
- expected code exists;
- runtime bytecode matches the reviewed build;
- metadata is correct;
- decimals are correct;
- total supply is correct;
- authority is correct;
- distribution cap is correct and equals the approved manifest count;
- deployer has no unintended authority;
- transfers fail;
- approvals fail;
- distribution works only for the authorized party;
- finalization state is correct.

Never infer successful deployment solely from a transaction status.

---

## 18. Threat-model categories

Consider at least:

### Contract risks

- unauthorized minting;
- bypassing finalization;
- accidental transferability;
- inherited approval behavior;
- duplicate distribution;
- incorrect supply accounting;
- administrative misconfiguration;
- compromised deployer;
- compromised Safe signer;
- unexpected external calls;
- upgrade or delegatecall backdoors.

### Data risks

- incorrect REP contract address;
- incorrect snapshot block;
- incomplete holder discovery;
- duplicate recipients;
- migrated holders incorrectly included;
- eligible holders incorrectly excluded;
- exchange or protocol addresses misclassified;
- non-reproducible filtering;
- RPC inconsistency;
- archive-node failure;
- manual spreadsheet edits;
- checksum mismatch.

### Communications risks

- users mistake the notice for migrated REP;
- users believe the notice has value;
- users search for a fake migration site;
- scammers copy the name and symbol;
- wallets hide the token as spam;
- wallets truncate the message;
- third-party interfaces attach incorrect price data;
- fake liquidity pools appear;
- public communications omit the canonical contract address.

### Operational risks

- wrong network;
- wrong authority or controller;
- wrong Safe owner or threshold, if a Safe is used;
- wrong constructor values;
- wrong batch file;
- repeated batch;
- skipped batch;
- gas spike;
- nonce conflict;
- transaction replacement;
- incomplete reconciliation;
- premature finalization;
- failure to finalize;
- source-verification mismatch.

Update `docs/security/THREAT_MODEL.md` when implementation or operations introduce a new category.

---

## 19. Communications and UX constraints

This repository is technical, but the system's purpose is communications.

Do not make technical decisions that contradict the notice's intended meaning.

The system and documentation must consistently communicate:

- This is a notice only.
- It is not REP.
- It is not migrated REP.
- It has no value.
- It does not need to be traded.
- It does not need to be approved.
- It does not need to be transferred.
- It does not need to be claimed.
- It does not need to be burned.
- Users should independently navigate to Augur's official surfaces.
- The official contract address must be verified.
- Matching names and symbols are not proof of authenticity.

Do not generate marketing copy that promises wallet visibility.

Wallet presentation is an empirical test result, not a guaranteed protocol behavior.

---

## 20. Git and change-management rules

- Keep changes small and reviewable.
- Do not modify unrelated files.
- Do not reformat the entire repository during a targeted change.
- Do not combine dependency upgrades with behavior changes.
- Do not commit generated secrets or local environment files.
- Do not rewrite Git history.
- Do not force-push.
- Do not delete tests because implementation changed.
- Update tests and specification together when behavior changes.
- Use descriptive commit messages.
- Put security-sensitive decisions in commit or pull-request descriptions.
- Require human review for every production-contract change.
- Require separate human review for recipient-data changes.

Use Conventional Commits for every commit subject:

```text
<type>(<optional-scope>): <imperative summary>
```

- Use a standard type such as `feat`, `fix`, `docs`, `test`, `refactor`, `perf`, `build`, `ci`, `chore`, or `revert`.
- Use `!` and a `BREAKING CHANGE:` footer only for an actual incompatible change.
- Keep each commit single-purpose, and explain security or deployment impact in the body when applicable.

Before editing, inspect:

```bash
git status
git diff
git log -n 5 --oneline
```

After editing, summarize:

- files changed;
- behavior changed;
- tests added;
- commands run;
- unresolved findings;
- deployment impact.

---

## 21. Codex working method

For every substantive task:

1. Read this file.
2. Read relevant project documentation.
3. Inspect the current implementation and tests.
4. State the intended change and security impact.
5. Make the smallest coherent diff.
6. Add or update tests.
7. Run the required checks.
8. Review the diff.
9. Report results and unresolved risks.

Do not begin by rewriting the architecture.

Do not assume missing requirements.

When ambiguity affects security, recipient eligibility, token semantics, administrative control, or deployment behavior, identify it explicitly.

For routine implementation details, use conservative defaults consistent with this file.

### Required response structure after code changes

Report:

1. What changed.
2. Why it changed.
3. Security implications.
4. Tests added or changed.
5. Commands run and results.
6. Remaining assumptions or blockers.
7. Whether deployment artifacts changed.

Never say a contract is secure or audited unless a qualified audit has actually occurred.

Use phrases such as:

- "No issue was observed in the tested paths."
- "The current tests cover..."
- "Static analysis reported..."
- "This has not received an independent security audit."

---

## 22. Prohibited agent behavior

Codex must never:

- claim an audit was completed when it was not;
- claim absence of vulnerabilities;
- invent contract addresses;
- invent snapshot blocks;
- invent holder eligibility rules;
- invent deployment transaction hashes;
- fabricate gas measurements;
- silently suppress warnings;
- delete failing tests to obtain a green build;
- relax invariants without approval;
- expose secrets;
- request seed phrases;
- request production private keys;
- print secret environment variables;
- commit `.env`;
- deploy to mainnet;
- broadcast production transactions;
- submit Safe transactions;
- add upgradeability by default;
- add arbitrary external calls;
- add hidden owner powers;
- introduce a second admin system without justification;
- make the token transferable;
- make the token economically useful;
- add a claim or approval flow;
- reuse the legacy Solidity `0.7.x` generator contract as the production implementation;
- infer that a wallet will display the token without empirical testing.

---

## 23. Definition of done

A contract task is complete only when:

- behavior matches the approved specification;
- the diff is minimal and reviewed;
- formatting passes;
- compilation passes;
- contract-size checks pass;
- unit tests pass;
- relevant fuzz tests pass;
- relevant invariant tests pass;
- relevant fork tests pass;
- gas impact is reported;
- Slither results are reviewed;
- documentation is updated;
- no secret was introduced;
- no unauthorized deployment occurred;
- unresolved assumptions are explicitly reported.

A data-pipeline task is complete only when:

- schemas are defined;
- inputs are documented;
- outputs are deterministic;
- addresses are validated;
- balances use `bigint`;
- duplicates are handled;
- filtering reasons are recorded;
- checksums are generated;
- tests pass;
- output counts reconcile;
- manual edits are unnecessary;
- the artifact can be reproduced from the committed code and documented inputs.

A deployment-preparation task is complete only when:

- all transactions remain unsigned;
- exact target chain is stated;
- exact target contract is stated;
- constructor arguments are stated;
- bytecode hashes are recorded;
- simulation succeeds;
- source verification steps are prepared;
- post-deployment checks are prepared;
- no production key was accessed;
- no transaction was broadcast.

---

## 24. Release gates

Do not describe the system as ready for a mainnet canary until all gates below are satisfied.

### Gate A: Specification

- Product objective approved.
- Non-goals approved.
- Token metadata approved.
- Recipient rules approved.
- Administrative model approved.
- Finalization semantics approved.
- Communications language approved.

### Gate B: Contract

- Minimal implementation complete.
- Frozen acceptance criteria implemented.
- Unit tests complete.
- Fuzz tests complete.
- Invariant tests complete.
- Static-analysis findings resolved or accepted.
- Gas report complete.
- Independent review complete.

### Gate C: Data

- Snapshot block approved.
- Holder-discovery method reviewed.
- Migration-detection logic reviewed.
- Exclusions reviewed.
- Recipient outputs checksummed.
- Batch manifests reviewed.
- Reproduction tested independently.

### Gate D: Testnet

- Sepolia deployment verified.
- Immutable authority configuration verified.
- Distribution tested.
- Finalization tested.
- Wallet-display observations documented.
- Scam and confusion risks reviewed again.

### Gate E: Mainnet preparation

- Exact commit tagged.
- Bytecode reproduced.
- Safe simulation complete.
- Canary list approved.
- Stop conditions approved.
- Public verification material prepared.
- Incident-response owner assigned.

Only human maintainers can approve release gates.

---

## 25. Initial implementation milestones

Unless the maintainers set another sequence, work in this order.

### Milestone 1: Repository foundation

Create:

- `foundry.toml`;
- dependency pins;
- folder structure;
- `docs/product/SPEC.md`;
- `docs/security/THREAT_MODEL.md`;
- `docs/operations/DEPLOYMENT_RUNBOOK.md`;
- CI;
- standard commands.

No deployment.

### Milestone 2: Minimal notice contract

Implement only:

- metadata;
- one-unit distribution;
- duplicate prevention;
- authorization;
- irreversible finalization;
- non-transferability;
- events;
- read methods required for verification.

No snapshot tooling yet.

### Milestone 3: Contract test suite

Add:

- unit tests;
- fuzz tests;
- invariant tests;
- gas benchmarks;
- Slither review.

### Milestone 4: Local operations

Add:

- local deployment script;
- local distribution script;
- local finalization script;
- reconciliation script;
- sample recipient fixtures.

### Milestone 5: Snapshot tooling

Add:

- holder discovery;
- migration-status evaluation;
- exclusion framework;
- deterministic recipient output;
- checksums;
- batch manifests.

Eligibility logic must be supplied or approved by maintainers.

### Milestone 6: Fork simulation

Use a pinned mainnet block and real contract state.

No broadcast.

### Milestone 7: Sepolia candidate

Prepare and execute only after explicit human approval.

### Milestone 8: Mainnet canary preparation

Generate unsigned artifacts only.

---

## 26. Suggested first task for Codex

When beginning from an empty repository, use this task:

> Initialize a Foundry-first repository for the REP Migration Notice project. Read `AGENTS.md` fully. Create the documented directory structure, pin the compiler and dependencies, add placeholder `docs/product/SPEC.md`, `docs/security/THREAT_MODEL.md`, and `docs/operations/DEPLOYMENT_RUNBOOK.md` files with decision sections, configure formatting/build/test commands, and create CI that runs formatting, compilation, tests, contract-size checks, and Slither. Do not implement the production contract, do not create deployment credentials, and do not broadcast any transaction. Show the complete diff and report every command run.

---

## 27. Maintainer decisions still required

The product and contract architecture are approved. Do not guess the remaining evidence-dependent values:

- REP contract addresses in scope;
- fork universe or REP versions in scope;
- definition of successfully migrated;
- snapshot block;
- minimum REP threshold;
- exchange and protocol exclusions;
- final approved recipient manifest;
- exact numeric distribution cap derived from that manifest;
- canary recipient count;
- maximum batch size;
- exact 2-of-3 Safe address;
- signer identities and custody evidence;
- Safe version and reviewed fallback handler;
- budget;
- exact official canonical page URL;
- exact wallet-product test matrix;
- incident-response procedure.
- deployment commit and bytecode hashes.

Every item must follow the owner, evidence, decision rule, phase, and release gate in the specification's deferred-with-gate register.

---

## 28. Final principle

This project is a holder-safety and communications system implemented with Ethereum contracts.

The correct design is not the most feature-rich token.

The correct design is the smallest verifiable mechanism that can test the communication hypothesis without creating unnecessary financial, administrative, or scam risk.
