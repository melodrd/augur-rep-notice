# Contract Validation

Status: current local evidence as of 2026-07-16

This document records reproducible evidence for the current `RepMigrationAlert` candidate. It is not an audit, does not prove that vulnerabilities are absent, and does not establish recipient, operational, or deployment readiness.

## Candidate

| Item | Value |
| --- | --- |
| Production source commit | `c073983edf3ef838c465734c1083ca8e8fc795b3` |
| Contract | `src/RepMigrationAlert.sol` |
| Solidity | `0.8.36` |
| EVM target | `osaka` |
| Optimizer | enabled, 200 runs |
| Via IR | disabled |
| Forge | `1.7.1` |
| forge-std | `v1.16.1` at `620536fa5277db4e3fd46772d5cbc1ea0696fb43` |
| Slither | `0.11.5` |
| Bun | `1.3.14` |

The checked-in `foundry.toml` is the canonical build configuration. Compilation completed without Solidity diagnostics.

## Review findings

The production source was reviewed line by line for construction, metadata, recipient states, accounting, authorization, validation precedence, atomicity, burn, finalization, events, disabled movement, and forbidden surfaces.

| Severity | Open findings |
| --- | ---: |
| Critical | 0 |
| High | 0 |
| Medium | 0 |
| Low | 0 |

The review observed no defect in the tested paths. The hard batch ceiling and explicit EVM pin resolved the two prior release-blocking source/configuration gaps.

Distribution validation order is:

```text
authority -> finalized -> empty -> maximum batch -> lifetime cap -> recipient validation
```

## Test evidence

| Suite | Campaign | Result |
| --- | ---: | --- |
| Unit behavior tests | 77 | passed |
| Isolated gas tests | 30 | passed |
| Fuzz properties | 16 × 256 = 4,096 cases | passed |
| Stateful invariant | 256 × 500 = 128,000 calls | passed |
| Total Forge tests/properties | 124 | passed |

The invariant handler targets 27 reviewed selectors. Foundry reported 128,000 calls, zero handler reverts, and zero discards. The reference model independently tracks permanent issuance, active supply, burned count, finalization, permissions, movement failures, and recipient lifecycle.

Focused ceiling tests prove:

- `MAX_BATCH_SIZE()` is 500;
- exactly 500 unique recipients succeed;
- 501 recipients revert with exact `BatchSizeExceeded(501, 500)` data;
- oversized failure is atomic;
- authorization and finalization take precedence over size;
- size takes precedence over lifetime cap;
- empty input retains its dedicated error; and
- the measured 500-recipient transaction stays below the local regression ceiling.

Three additional double-fault tests lock the remaining adjacent precedence boundaries: authority before finalized, finalized before empty, and lifetime cap before recipient validation.

## Production coverage

| Metric | Production result | Repository result |
| --- | ---: | ---: |
| Lines | 100.00% (61/61) | 84.55% (279/330) |
| Statements | 100.00% (51/51) | 91.46% (332/363) |
| Branches | 100.00% (12/12) | 59.32% (35/59) |
| Functions | 100.00% (13/13) | 96.36% (53/55) |

Coverage disables optimizer and via IR and emits source-anchor warnings for compiler-generated or optimized constructs. Those warnings are classified as instrumentation limitations; isolated optimized snapshots remain the gas authority.

## Size and deployment gas

| Measure | Before | Ceiling-only build | Final | Final change |
| --- | ---: | ---: | ---: | ---: |
| Deployment gas | 511,565 | 524,795 | 499,345 | -12,220 |
| Runtime bytecode | 2,389 bytes | 2,455 bytes | 2,328 bytes | -61 bytes |
| Initcode | 2,654 bytes | 2,720 bytes | 2,593 bytes | -61 bytes |

The final runtime is 22,248 bytes below the 24,576-byte limit. Final initcode is 46,559 bytes below the 49,152-byte limit.

## Gas method

The dedicated suite in `test/gas/RepMigrationAlertGas.t.sol` measures optimized calls in isolation. Successful distributions use fresh contracts, cold target state, entirely new recipients, and addresses whose 20 address bytes are nonzero. It records execution gas, exact calldata bytes and gas, the Osaka calldata floor, and:

```text
Osaka transaction gas =
21,000 + max(calldata gas + execution gas, 10 × (calldata gas / 4))
```

`forge test --gas-report` remains diagnostic only because its instrumentation changes helper measurements. Authoritative final values come from:

```bash
FOUNDRY_SNAPSHOTS=/tmp/rep-alert-final-snapshot-values \
  forge snapshot --snap /tmp/rep-alert-final-gas.snapshot
```

## Successful distribution gas

| Recipients | Calldata bytes | Calldata gas | Execution gas | Final Osaka total | Before | Change |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 100 | 712 | 71,583 | 93,295 | 93,419 | -124 |
| 10 | 388 | 4,024 | 291,354 | 316,378 | 317,852 | -1,474 |
| 25 | 868 | 9,544 | 657,639 | 688,183 | 691,907 | -3,724 |
| 50 | 1,668 | 18,744 | 1,268,114 | 1,307,858 | 1,315,332 | -7,474 |
| 100 | 3,268 | 37,144 | 2,489,064 | 2,547,208 | 2,562,182 | -14,974 |
| 200 | 6,468 | 73,944 | 4,930,964 | 5,025,908 | 5,055,882 | -29,974 |
| 500 | 16,068 | 184,356 | 12,256,664 | 12,462,020 | 12,536,994 | -74,974 |

The final incremental Osaka cost is approximately 24,787 gas per additional recipient, including approximately 24,419 execution gas and 368 calldata gas.

The 500-recipient result is 2,537,980 gas below the test's 15,000,000 local ceiling. It uses 83.08% of that ceiling. Twice the measured transaction is 24,924,040 gas; deployment preparation must independently confirm target-chain conditions and stricter tooling constraints. The local ceiling is regression evidence, not a live-chain gas-limit observation.

## Other gas paths

| Scenario | Final Osaka total | Result |
| --- | ---: | --- |
| Successful burn | 33,341 | succeeded |
| Never-alerted or repeated burn | 23,501 | reverted |
| Successful finalization | 47,137 | succeeded |
| Repeated finalization | 23,481 | reverted |
| Empty batch | 24,042 | reverted |
| 501-recipient batch | 482,810 | reverted |
| 500-recipient cap overflow | 481,890 | reverted |
| Duplicate at final index of 500 | 12,395,928 | reverted |
| Reissue burned recipient | 29,203 | reverted |

The Osaka calldata floor dominates the large batches that reject before significant execution.

## Gas optimization review

Accepted: the private enum-backed status mapping was replaced with one `mapping(address => uint256)` and three named full-word constants for `NeverAlerted`, `Active`, and `Burned`. Only the values 1 and 2 are privately written; zero remains the mapping default. Observable states, ABI, events, storage slots, and transitions are unchanged. Existing unit, fuzz, invariant, and gas suites observed no behavioral difference in the tested paths.

Relative to the ceiling-only build, this saves:

- 25,450 deployment gas;
- 127 runtime and initcode bytes;
- exactly 150 gas per successful recipient, or 75,000 at 500; and
- 147 gas per successful burn.

Rejected after review:

- explicit unchecked loop increments: compiler output already removes useful increment-overflow work;
- unchecked counter or burn arithmetic: only small fixed savings at reduced defensive clarity;
- packed counters or status bits: less auditable and unnecessary;
- two-pass recipient validation: more reads and more complex control flow;
- extra mappings, removed counters, assembly, or ABI reduction: prohibited or behavior-changing; and
- immutable caching, `msg.sender` event substitution, or visibility changes: no meaningful optimized-output benefit.

## ABI and storage

The ABI contains one constructor, 18 callable functions, two events, and 13 custom errors. Relative to the prior public surface, it adds only:

```text
MAX_BATCH_SIZE()                              0xcfdbf254
BatchSizeExceeded(uint256,uint256)            0xf80a4845
```

All existing selectors and both event topics are unchanged. Inspection confirms no owner, role, mint, delegated burn, permit, pause, recovery, withdrawal, payable, fallback, receive, arbitrary-call, proxy, upgrade, REP, migration-contract, `delegatecall`, or `selfdestruct` surface.

| Slot | Variable | Type |
| ---: | --- | --- |
| 0 | `totalIssued` | `uint256` |
| 1 | `totalSupply` | `uint256` |
| 2 | `finalized` | `bool` |
| 3 | `_status` | `mapping(address => uint256)` |

Slot positions and count are unchanged. The accepted optimization changes only the private slot-3 value type from enum-backed status to full-word status. Immutables and constants occupy no mutable storage.

## Diagnostics and CI

Slither analyzed one production contract with 101 detectors and reported zero results. No finding was suppressed. This result is not an audit.

Routine CI continues to run Solidity formatting, TypeScript formatting/linting/type checking/tests, Solidity build/tests/sizes, and Slither. Coverage remains a required local candidate check rather than a duplicate CI step because it disables canonical optimization, repeats the 128,000-call campaign, and emits known source-anchor warnings.

## Validation commands

```bash
forge fmt
forge fmt --check
forge build
forge build --sizes
forge test
forge test -vvv
forge test --gas-report
FOUNDRY_SNAPSHOTS=/tmp/rep-alert-final-snapshot-values \
  forge snapshot --snap /tmp/rep-alert-final-gas.snapshot
forge coverage
slither .
make check
git diff --check
forge inspect RepMigrationAlert abi
forge inspect RepMigrationAlert methodIdentifiers
forge inspect RepMigrationAlert storageLayout
forge inspect RepMigrationAlert events
forge inspect RepMigrationAlert errors
```

## Known limitations and remaining work

- No formal audit or independent human release review has occurred.
- The local gas ceiling is not a target-chain observation. No approved target-chain block gas limit or evidence for the required 50% maximum-batch gate exists yet; deployment preparation and Sepolia must reconfirm execution, calldata, and transaction-tool behavior.
- Recipient sources, snapshot, migration semantics, filters, manifest, numeric deployment cap, and tooling remain unapproved or unimplemented.
- No fork, RPC, wallet, deployment, source-verification, transaction, or live-chain rehearsal was performed.
- Production EOA evidence, canonical official URL, canaries, incident ownership, deployment hashes, and unsigned artifacts remain release-gated.
- Third-party display remains unguaranteed.

The next stage is minimal deployment tooling and a controlled Sepolia rehearsal after explicit human authorization.
