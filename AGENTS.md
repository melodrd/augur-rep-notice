# AGENTS.md

## 1. Purpose

This repository contains smart-contract and operational tooling for an experimental Augur REP migration-awareness campaign.

The project may distribute one non-economic on-chain alert to selected addresses. The alert is not REP, migrated REP, replacement REP, a claim, a reward, a governance asset, or a tradable instrument.

This is a security-sensitive Ethereum project. Treat contract changes, recipient-data transformations, deployment preparation, and transaction artifacts as production infrastructure.

## 2. Instruction priority

When instructions conflict, follow:

1. Explicit human instructions in the current task.
2. [`docs/product/SPEC.md`](docs/product/SPEC.md).
3. [`docs/security/THREAT_MODEL.md`](docs/security/THREAT_MODEL.md).
4. [`docs/operations/DEPLOYMENT_RUNBOOK.md`](docs/operations/DEPLOYMENT_RUNBOOK.md).
5. This file.
6. Existing tests and code comments.
7. General conventions.

Stop before changing code when a request conflicts with a security invariant or approved contract behavior.

## 3. Current status and default mode

Status:

- Foundation: complete.
- Product specification: complete.
- Threat model and acceptance criteria: complete.
- Minimal contract implementation: next.

Default mode:

- Work locally.
- Do not access an Ethereum RPC unless the current task explicitly authorizes it.
- Do not handle production secrets.
- Do not create or inspect a private key or wallet unless a human explicitly requests a permitted test-only operation.
- Do not modify mainnet recipient data without an explicit request.
- Do not deploy to mainnet.
- Do not sign, submit, or broadcast transactions.
- Do not weaken tests or silently change contract behavior.

A passing build is not evidence that the system is safe, audited, useful, or ready for deployment.

## 4. Approved architecture summary

The product specification is authoritative. Keep these high-level constraints aligned with it:

- Fixed name: `REP MIGRATION ALERT`.
- Fixed symbol: `CHECKREP`.
- Decimals: `0`.
- Unit per successful recipient: `1`.
- Initial supply: `0`.
- Metadata is compiled into the contract, not supplied to the constructor.
- The checksummed deployed contract address published through official Augur sources is the canonical identity.
- One `distribute(address[] recipients)` path serves canaries and batches.
- Distribution is strictly atomic.
- The constructor receives one nonzero immutable authority and one nonzero immutable cap.
- The cap equals the final approved manifest’s unique-address count.
- The approved production authority is one dedicated EOA controlled by the project owner.
- The same EOA is expected to deploy and be supplied explicitly as authority.
- Deployment alone grants no privilege.
- Authority transfer, recovery, successor nomination, ownership, and secondary roles are absent.
- Transfers, transfer-from, approvals, permits, allowance helpers, operator approvals, and burns are disabled or absent.
- Finalization is explicit, irreversible, and permanently closes issuance.
- No proxy, upgrade, external call, REP interaction, migration-contract interaction, payable path, withdrawal, or recovery helper exists.
- The production contract is standalone and does not inherit generalized token or administration frameworks.

Any behavioral change requires a specification revision, threat-model review, and acceptance-criteria update.

## 5. Non-goals

Do not add:

- DEX, liquidity, pricing, taxation, rebasing, staking, vesting, or yield behavior;
- claims, redemptions, user minting, wallet-connect, or interaction-based migration flows;
- bridges, cross-chain messaging, oracles, callbacks, hooks, or arbitrary multicalls;
- permit, meta-transaction, ERC-1363, ERC-777, ERC-4626, NFT, URI, or dynamic metadata behavior;
- proxies, upgrades, delegatecall modules, diamonds, governance, or unrelated timelocks;
- token recovery, ETH withdrawal, or arbitrary external-call helpers;
- authority transfer, recovery, secondary administration, or hidden deployer powers;
- frontend work before the contract and operational specification are stable.

Do not use the legacy Solidity `0.7.x` generator contract as the production base.

## 6. Technology and version policy

### Solidity

Use:

- Solidity;
- Foundry, Forge, Anvil, and Cast;
- `forge-std`;
- Slither.

The production contract must not inherit OpenZeppelin `ERC20`, `Ownable`, `Ownable2Step`, `AccessControl`, `Pausable`, proxy, upgradeable, or generalized token contracts.

Do not add Hardhat, Truffle, Brownie, or a second Solidity framework without approval.

### TypeScript operations

Use:

- TypeScript;
- Bun for package management, runtime, and tests;
- `tsc --noEmit`;
- Biome;
- viem;
- Zod or equivalent schema validation;
- deterministic JSON and CSV;
- cryptographic checksums.

Do not:

- add `tsx`;
- run npm or pnpm repository installs;
- create `package-lock.json`, `pnpm-lock.yaml`, or `yarn.lock`;
- use JavaScript `number` or floating-point arithmetic for on-chain balances;
- create a Python project without a concrete requirement.

Use `bigint` for on-chain integers. Use `uv tool` for pinned Python CLI tools.

### Pins

- Pin the Solidity compiler exactly in `foundry.toml`.
- Initial compiler target is Solidity `0.8.36` unless explicitly revised.
- Pin Foundry dependencies to tags or immutable commits.
- Commit lockfiles and dependency metadata.
- Do not use floating tags.
- Do not change compiler, optimizer, EVM, IR, or dependency versions in an unrelated change.
- Put dependency upgrades in isolated reviewed commits.

Repository configuration is the source of truth after initialization.

## 7. Repository structure

Preserve the documented structure unless a reviewed change justifies another layout.

```text
.
├── AGENTS.md
├── README.md
├── docs/
│   ├── README.md
│   ├── product/
│   │   ├── SPEC.md
│   │   └── DECISIONS.md
│   ├── security/
│   │   └── THREAT_MODEL.md
│   ├── operations/
│   │   ├── DEPLOYMENT_RUNBOOK.md
│   │   └── ETHERSCAN_RUNBOOK.md
│   ├── communications/
│   │   └── MESSAGING.md
│   ├── planning/
│   │   └── ROADMAP.md
│   └── reports/
├── src/
├── test/
├── script/
├── ops/
├── data/
├── deployments/
└── .github/
```

Generated build artifacts belong in ignored directories such as `out/`, `cache/`, and local temporary folders.

Never commit secrets, RPC credentials, private recipient notes, or personal data.

## 8. Solidity design rules

Prefer the smallest implementation that satisfies the specification.

Use:

- exact pragma and SPDX identifier;
- NatSpec on external and public functions;
- descriptive custom errors and events;
- checks before effects;
- named constants instead of magic numbers;
- explicit standalone logic.

Avoid:

- unnecessary inheritance;
- generic extension points;
- low-level calls;
- assembly;
- `delegatecall`;
- `selfdestruct`;
- fallback or receive functions;
- dynamic dispatch;
- unbounded iteration over stored recipient sets;
- `tx.origin`;
- timestamp dependencies, randomness, or unsafe casts;
- `unchecked` blocks without proof, tests, and comments;
- test-only public functions;
- commented-out production code;
- unresolved TODOs or suppressed compiler warnings.

Every externally callable function needs a documented purpose.

### Authority

Use one nonzero constructor-supplied immutable authority.

- The deployer has no implicit privilege.
- Production policy intentionally uses the same dedicated EOA as deployer and authority.
- Contract logic must not derive authority from `msg.sender` during construction or require deployer/authority equality.
- An unrelated deployer must receive no privilege when another address is supplied as authority.
- No transfer, acceptance, renunciation, successor, recovery, ownership, or role system exists.

### Dedicated production EOA

The EOA:

- is controlled by the project owner;
- is dedicated to the campaign;
- is not an everyday wallet;
- has no intentional unrelated token, protocol, or DeFi activity;
- holds only reasonably required operational ETH;
- should use hardware-backed signing;
- uses a mainnet key that is not reused on Sepolia;
- requires manual review of chain, target, value, calldata, nonce, expected state change, and simulation.

Never request or record its private key, seed phrase, recovery phrase, raw keystore, or secret environment values. Agents may prepare unsigned artifacts only and may never sign, submit, or broadcast.

### Distribution

The distribution path must:

- reject empty arrays;
- reject the zero address;
- reject duplicates within a call and prior recipients;
- revert the complete call for any invalid condition;
- prevent balances above one;
- reject unauthorized and post-finalization calls;
- enforce the immutable cap;
- emit one `Transfer(address(0), recipient, 1)` per success;
- avoid external calls and stored-set iteration.

Do not freeze a maximum batch size until measured gas and calldata evidence supports it. Use a compile-time maximum whose worst-case successful call consumes no more than 50% of the pinned target block gas limit, or a lower reviewed operational bound.

### Finalization and movement

- Transfer and transfer-from always revert, including zero-value transfer.
- Approval always reverts and allowance is always zero.
- Permit, allowance helpers, operator approvals, callbacks, and burns are absent.
- Finalization is authorized, explicit, irreversible, and repeated calls revert.
- No path can restore issuance after finalization.

## 9. Security invariants

Tests and reviews must establish:

- no address balance exceeds one;
- zero address balance remains zero;
- balances cannot move or burn;
- total supply equals unique successful recipients;
- failed calls do not change state;
- total supply never exceeds the cap;
- only the immutable authority distributes or finalizes;
- no deployer, owner, role, recovery, or secondary privilege exists;
- authority loss creates no replacement administrator;
- authority compromise cannot bypass the cap;
- finalization cannot be reversed;
- no REP, ETH-send, arbitrary-call, upgrade, proxy, or delegatecall capability exists;
- deterministic artifacts, canonical ordering, explicit exclusion reasons, and checksums are used off-chain.

Invariant tests must exercise sequences of authorized and unauthorized actions rather than isolated calls only.

## 10. Recipient-data rules

Recipient selection is security- and reputation-sensitive business logic.

### Required snapshot metadata

Record:

- chain ID;
- RPC source category without secrets;
- block number, hash, and timestamp;
- REP and migration contract addresses queried;
- holder-discovery method;
- balance threshold;
- included versions or universes;
- exclusion rules;
- script commit hash;
- generation timestamp;
- output checksum.

### Address handling

- Validate every address.
- Preserve checksum format in human-facing outputs.
- Compare normalized addresses case-insensitively.
- Reject malformed and zero addresses.
- Deduplicate deterministically.
- Sort canonically.
- Never guess, autocomplete, or infer addresses from prose.
- Do not classify an address as EOA, contract, exchange, or protocol without evidence.
- Do not exclude contracts merely because bytecode exists.

### Balances

- Use raw integer balances and `bigint`.
- Apply decimals explicitly.
- Define the exact queried block.
- Fail closed when required historical state is unavailable.

### Filtering

Every rule needs:

- a stable identifier;
- a plain-language description;
- deterministic implementation;
- tests;
- affected-address count and report;
- explicit inclusion or exclusion reason.

Do not silently drop records.

### Outputs

Produce machine-readable JSON, reviewable CSV, summary reports, checksums, batch manifests, and reconciliation reports.

Final batch manifests record batch number, recipient count, first and last canonical address, input checksum, batch checksum, expected cumulative recipient count, and expected cumulative supply.

Never edit generated production manifests manually.

## 11. Testing and standard commands

Every behavior change requires tests. Do not weaken or delete tests to obtain a passing result.

Required contract checks, when relevant:

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

Required TypeScript checks use repository Bun scripts and include:

```bash
bun install --frozen-lockfile
bun run typecheck
bun run lint
bun test
```

Always run `tsc --noEmit`; Bun transpilation alone is not type checking.

Unit, fuzz, invariant, fork, gas, and TypeScript coverage must follow the specification and threat model. Fork tests use a pinned block and never broadcast.

Static-analysis findings are classified as confirmed issue, false positive, accepted behavior, or needing investigation. Do not suppress detectors without a documented reason.

Coverage is a diagnostic, not a security guarantee.

## 12. Deployment and key safety

Local Anvil work is allowed with ephemeral test accounts when the task authorizes implementation or simulation.

Sepolia deployment requires explicit human instruction.

Mainnet agents may only prepare unsigned artifacts, constructor arguments, calldata, simulations, bytecode comparisons, verification commands, and checklists.

Agents must not:

- access or import production keys;
- request seed phrases or private keys;
- create a production wallet;
- store secrets in `.env`;
- sign, submit, or broadcast;
- operate the production authority EOA;
- run `forge script --broadcast`, `cast send`, wallet import, publishing, hardware-wallet signing, or equivalent commands without an explicitly permitted human-controlled task.

Human operators alone review, sign, submit, broadcast, monitor, reconcile, and finalize.

## 13. Verification records

For each deployment environment, record:

- network and chain ID;
- contract address and deployment transaction;
- deployer and immutable authority;
- immutable cap;
- source commit;
- compiler and optimizer settings;
- constructor arguments;
- creation and runtime bytecode hashes;
- source-verification status;
- deployment block and timestamp;
- metadata reads;
- finalization state;
- relevant transaction hashes.

Post-deployment checks compare chain, bytecode, metadata, supply, authority, cap, disabled movement, authorization, and finalization state. Transaction success alone is not sufficient evidence.

## 14. Threat categories

Consider at least:

- unauthorized issuance, cap bypass, accidental transferability, approvals, duplicates, supply errors, finalization bypass, external calls, and upgrade paths;
- EOA key loss, compromise, malware, wrong-chain signing, bad calldata, nonce errors, excessive funding, unrelated activity, unsafe backup, and unrecoverable authority;
- wrong source contracts, snapshot, discovery, migration classification, exclusions, ordering, checksums, or manifest count;
- wrong network, constructor values, bytecode, batch, nonce, replacement, reconciliation, or finalization timing;
- user confusion, fake metadata, fake price or liquidity, malicious links, incorrect official address publication, and unguaranteed third-party display.

Update the threat model when implementation or operations introduce a new risk.

## 15. Communications constraints

Documentation must consistently state:

- `REP MIGRATION ALERT` is an alert only;
- it is not REP, migrated REP, replacement REP, a claim, or an asset with value;
- receiving it performs no migration and grants no right;
- no recipient interaction is required;
- `CHECKREP` means to check official REP migration information independently;
- users should not approve, transfer, swap, burn, bridge, claim, sign, or connect a wallet because of it;
- the canonical contract address must be verified through official Augur sources;
- identical metadata and third-party prices do not prove authenticity or value;
- third-party display is not guaranteed.

Do not place a migration URL in contract metadata or storage.

Etherscan is the only third-party metadata surface currently in scope. Follow
[`docs/operations/ETHERSCAN_RUNBOOK.md`](docs/operations/ETHERSCAN_RUNBOOK.md)
for source verification, metadata, logo, evidence, and correction work.

Browser and mobile wallets, portfolio trackers, token lists, CoinGecko, CoinMarketCap, and other market-data or asset-listing services are deferred for a later specification and operations review. No wallet-product matrix or submission to those services is currently approved, and no release gate depends on their inclusion.

## 16. Git and change management

Before editing:

```bash
git status
git diff
git log -n 5 --oneline
```

Rules:

- Preserve unrelated user work.
- Keep changes small and reviewable.
- Do not reformat unrelated files.
- Do not combine dependency upgrades with behavior changes.
- Do not rewrite history or force-push.
- Do not commit secrets or local environment files.
- Require human review for production-contract changes.
- Require separate human review for recipient-data changes.
- Use Conventional Commits.

Commit subjects follow:

```text
<type>(<optional-scope>): <imperative summary>
```

After editing, review the full diff and report files changed, behavior, tests, commands, unresolved findings, and deployment impact.

## 17. Working method

For substantive tasks:

1. Read this file completely.
2. Read relevant project documents.
3. Inspect repository state, implementation, and tests.
4. State the intended change and security impact.
5. Make the smallest coherent diff.
6. Add or update tests for behavior changes.
7. Run proportionate required checks.
8. Review the diff.
9. Report results and unresolved risks.

Do not assume missing security, eligibility, authority, or deployment requirements. Ask or stop when an ambiguity would materially change those areas.

After code changes, report:

1. What changed.
2. Why.
3. Security implications.
4. Tests added or changed.
5. Commands and results.
6. Remaining assumptions or blockers.
7. Whether deployment artifacts changed.

Never describe the contract as secure or audited without a qualified audit. Use evidence-limited wording such as “No issue was observed in the tested paths.”

## 18. Prohibited agent behavior

Never:

- claim an audit or absence of vulnerabilities;
- invent addresses, snapshot blocks, eligibility rules, transaction hashes, gas results, or organizational control;
- expose or request secret material;
- print secret environment variables;
- commit `.env`;
- deploy to mainnet;
- sign, submit, or broadcast production transactions;
- relax invariants or suppress warnings without approval;
- add hidden authority, upgradeability, arbitrary calls, transferability, economic use, claims, approvals, or burns;
- infer wallet or explorer display without evidence.

## 19. Definition of done

A contract task is complete only when behavior matches the specification, the diff is minimal, required formatting/build/size/test/fuzz/invariant/fork/gas/coverage/static-analysis checks are reviewed, documentation is current, no secret or unauthorized deployment is introduced, and assumptions are explicit.

A data task is complete only when schemas, inputs, deterministic outputs, validation, `bigint` balance handling, reason-coded filtering, checksums, tests, reconciliation, and reproducibility are complete.

A deployment-preparation task is complete only when artifacts remain unsigned, target chain and contract are exact, constructor data and bytecode hashes are recorded, simulation succeeds, verification and post-deployment checks are prepared, no production key is accessed, and no transaction is broadcast.

## 20. Release gates and deferred values

Human maintainers alone approve release gates for:

1. specification;
2. contract implementation and review;
3. recipient data;
4. Sepolia rehearsal;
5. mainnet preparation;
6. human-controlled execution and finalization.

Do not call the project mainnet-ready until every applicable gate is approved.

Do not guess:

- REP contracts or universes;
- migration definition;
- snapshot block;
- threshold or exclusions;
- final recipient manifest or numeric cap;
- maximum batch size;
- exact dedicated production EOA;
- non-secret EOA storage and backup evidence;
- canary size or stop conditions;
- official canonical page URL;
- incident-response procedure;
- deployment commit or bytecode hashes.

## 21. Final principle

This is a holder-safety and communications system implemented with Ethereum contracts.

The correct design is the smallest verifiable mechanism that tests the communication hypothesis without creating unnecessary financial, administrative, or scam risk.
