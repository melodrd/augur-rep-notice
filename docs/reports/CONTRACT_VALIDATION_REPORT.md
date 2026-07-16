# REP MIGRATION ALERT Contract Validation Report

Status: Core candidate validated locally; maximum batch enforcement unresolved

Validation date: 2026-07-16

This report records local implementation review, behavioral testing, gas measurement, static analysis, ABI inspection,
storage-layout inspection, and coverage for the first `REP MIGRATION ALERT` Solidity candidate.

## Candidate

| Item | Value |
| --- | --- |
| Contract | `RepMigrationAlert` |
| Path | `src/RepMigrationAlert.sol` |
| Source commit | `1f2638bd58d02006f4d09910ded7d19916007303` |
| Solidity | `0.8.36` |
| Optimizer | Enabled, 200 runs |
| Via IR | Disabled |
| Effective EVM version | Osaka |
| EVM pin observation | `foundry.toml` does not explicitly set `evm_version`; Forge 1.7.1 resolves it to Osaka |
| Runtime size | 1,921 bytes |
| Initcode size | 2,186 bytes |
| Runtime size margin | 22,655 bytes |
| Initcode size margin | 46,966 bytes |
| Source line count | 171 |

The effective tool versions used were Forge 1.7.1, forge-std v1.16.1, Slither 0.11.5, and Bun 1.3.14.

## Review summary

The candidate was reviewed line by line against `AGENTS.md`, `docs/product/SPEC.md`, and
`docs/security/THREAT_MODEL.md`.

The review covered:

- exact fixed metadata and zero initial supply;
- explicit nonzero immutable authority and cap;
- deployer and authority separation;
- authorized atomic distribution;
- zero, duplicate, prior-recipient, empty, and cap rejection;
- binary balances and exact supply accounting;
- disabled transfer, transfer-from, approval, allowance, permit, and burn behavior;
- one-way irreversible finalization;
- event fields, count, and ordering;
- absence of inheritance, external calls, payable paths, recovery, roles, ownership, proxies, upgrades, assembly,
  `delegatecall`, `selfdestruct`, and `tx.origin`;
- ETH-balance-independent behavior.

No production-code defect was observed in the reviewed and tested paths. `src/RepMigrationAlert.sol` was not changed.

The only source-level specification gap is the intentionally deferred compile-time maximum batch size. The candidate has
no maximum constant, getter, custom error, or array-length check. That gap is release-blocking but must not be patched
until the repository contains an approved pinned target-chain block gas limit and independent review of the selected
constant.

Validation order is:

```text
authority -> finalized -> empty -> cap -> zero/duplicate recipient checks
```

The specification defines the failure conditions but does not freeze their relative precedence. Tests isolate the
intended failure condition rather than silently standardizing mixed-invalid precedence.

## Test summary

| Suite | Count or campaign | Result |
| --- | ---: | --- |
| Unit behavior tests | 54 | Passed |
| Targeted gas tests | 18 | Passed |
| Fuzz properties | 12 properties × 256 runs | Passed |
| Stateful invariants | 256 runs × 500 calls = 128,000 calls | Passed |
| Total Forge test functions/properties | 85 | Passed |

The unit suite covers construction, metadata, exact errors, deployer-authority separation, successful distribution,
contract recipients, event ordering, cap boundaries, strict rollback, movement and approval rejection, finalization,
unknown administrative selectors, direct ETH rejection, and forced-ETH independence.

The fuzz suite covers:

- unique bounded recipient arrays;
- disjoint successful batches;
- arbitrary duplicate pairs;
- adjacent and non-adjacent duplicates;
- zero-address placement;
- prior-recipient placement;
- arbitrary unauthorized callers;
- valid current-supply and remaining-cap sequences;
- cap overflow;
- arbitrary transfer, transfer-from, approval, owner, spender, recipient, caller, and value inputs;
- finalization from arbitrary valid pre-finalization supply.

The invariant handler targets only 18 reviewed selectors. It exercises authorized and unauthorized distribution,
deployer calls, empty arrays, zero recipients, adjacent and non-adjacent duplicates, prior recipients, cap boundary and
overflow, authorized and unauthorized finalization, repeated finalization, post-finalization distribution, transfers,
transfer-from, approvals, and forced ETH balances.

The invariant campaign continuously establishes:

- each tracked balance is zero or one;
- the zero address balance remains zero;
- tracked balances match the reference model and never decrease, move, or burn;
- total supply equals the number of unique successful recipients;
- total supply never exceeds the immutable cap;
- authority and cap never change;
- invalid, unauthorized, and deployer-only actions never succeed;
- finalization changes at most once and permanently freezes supply;
- no transfer, transfer-from, or approval succeeds;
- sampled allowances and all tested allowance paths remain zero.

Foundry's `recordLogs` inspector records attempted `LOG` operations from reverted frames. It is therefore not used to
claim that a late-invalid call produced persistent receipt logs. Exact revert data, complete state rollback, and EVM
revert semantics establish atomicity; successful calls separately prove exact persistent event count and calldata order.

## Gas results

### Method

Every successful measurement used a fresh contract and entirely new recipient addresses. All 20 recipient-address bytes
were nonzero so calldata pricing was not artificially reduced. The target account and slots were marked cold before the
measured call.

The measurement tests record:

- callee execution gas under the normal optimized Forge test mode;
- exact ABI-encoded calldata bytes;
- standard zero/nonzero calldata gas;
- the Osaka/[EIP-7623](https://eips.ethereum.org/EIPS/eip-7623) calldata floor;
- estimated total transaction gas as `21,000 + max(calldata gas + execution gas, Osaka floor data gas)`.

No RPC or live chain was used.

### Successful batches

| Recipients | Calldata bytes | Calldata gas | Execution gas | Osaka total gas | Increment from prior point |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 100 | 712 | 49,346 | 71,058 | n/a |
| 10 | 388 | 4,024 | 269,117 | 294,141 | 24,787 per recipient |
| 25 | 868 | 9,544 | 635,402 | 665,946 | 24,787 per recipient |
| 50 | 1,668 | 18,744 | 1,245,877 | 1,285,621 | 24,787 per recipient |
| 100 | 3,268 | 37,144 | 2,466,827 | 2,524,971 | 24,787 per recipient |
| 200 | 6,468 | 73,944 | 4,908,727 | 5,003,671 | 24,787 per recipient |
| 500 | 16,068 | 184,356 | 12,234,427 | 12,439,783 | approximately 24,787 per recipient |

The measured execution increment is approximately 24,419 gas per recipient. Each additional ABI address word adds 368
calldata gas, producing an approximately 24,787 total-gas increment per recipient over the measured range.

### Failure and finalization paths

The duplicate, prior-recipient, zero-recipient, cap, and unauthorized measurements below use 500-entry calldata except
where noted.

| Scenario | Calldata bytes | Execution gas | Osaka total gas | Result |
| --- | ---: | ---: | ---: | --- |
| Empty array | 68 | 2,710 | 24,042 | Reverted |
| Duplicate at start | 16,068 | 29,884 | 481,890 | Reverted |
| Duplicate in middle | 16,068 | 6,110,215 | 6,315,571 | Reverted |
| Duplicate at end | 16,068 | 12,190,546 | 12,395,902 | Reverted |
| Previously notified at end | 16,068 | 12,192,546 | 12,397,902 | Reverted |
| Zero recipient at end | 16,068 | 12,190,325 | 12,395,441 | Reverted |
| Exact cap boundary | 16,068 | 12,234,427 | 12,439,783 | Succeeded |
| Cap overflow | 16,068 | 4,983 | 481,890 | Reverted |
| Unauthorized caller | 16,068 | 585 | 481,890 | Reverted |
| Finalization after 100 recipients | 4 | 26,058 | 47,122 | Succeeded |
| Repeated finalization | 4 | 2,417 | 23,481 | Reverted |

The Osaka calldata floor dominates large-calldata calls that revert before meaningful execution, including unauthorized,
cap-overflow, and early-duplicate calls.

### Maximum-batch decision

Case B applies. No approved numeric target-chain block gas limit exists in the repository. The local Forge defaults
(`gas_limit = 1,073,741,824`, `block_gas_limit = null`, and `chain_id = null`) are test-runner settings and are not an
approved chain pin.

No `MAX_BATCH_SIZE` constant was added.

Evidence-supported candidates for later review are:

| Candidate | Measured successful gas | Minimum approved block gas limit required by the 50% rule |
| ---: | ---: | ---: |
| 100 | 2,524,971 | 5,049,942 |
| 200 | 5,003,671 | 10,007,342 |
| 500 | 12,439,783 | 24,879,566 |

The future review must select the lower of the gas-supported bound and any stricter calldata, transaction-tooling, or
manual-signing constraint. No value above 500 should be inferred from these measurements without an additional measured
point. The implementation remains in progress until the approved target input exists and the chosen constant receives
independent review.

## Static analysis

`slither .` analyzed one production contract with 101 detectors and returned zero results.

| Finding class | Count | Resolution |
| --- | ---: | --- |
| Confirmed issue | 0 | None |
| False positive | 0 | None |
| Expected approved behavior | 0 | None reported by Slither |
| Needs investigation | 0 | None reported by Slither |

The Solidity compiler produced no warnings for the final source and tests. Forge emitted a local environment warning
because its global signature cache is read-only; this did not affect compilation or test results.

Forge coverage emitted instrumentation-anchor warnings while compiling without optimizer and IR, but still produced a
complete production coverage map. These warnings are classified as a coverage-tool limitation, not a compiler or
contract finding.

This Slither result is not an audit and does not prove absence of vulnerabilities.

## ABI and storage

The ABI contains the approved constructor, 14 callable functions, two events, and 11 custom errors. The maximum-batch
getter is absent because the evidence gate is unresolved.

### Method identifiers

| Function | Identifier |
| --- | --- |
| `name()` | `06fdde03` |
| `symbol()` | `95d89b41` |
| `decimals()` | `313ce567` |
| `totalSupply()` | `18160ddd` |
| `balanceOf(address)` | `70a08231` |
| `allowance(address,address)` | `dd62ed3e` |
| `authority()` | `bf7e214f` |
| `distributionCap()` | `cd63d930` |
| `finalized()` | `b3f05b97` |
| `distribute(address[])` | `6138889b` |
| `finalize()` | `4bb278f3` |
| `transfer(address,uint256)` | `a9059cbb` |
| `transferFrom(address,address,uint256)` | `23b872dd` |
| `approve(address,uint256)` | `095ea7b3` |

The ABI declares `transfer`, `transferFrom`, and `approve` as `pure` because they unconditionally revert without reading
state. Their selectors and approved behavior are unchanged.

No `owner`, ownership transfer, mint, burn, permit, pause, recovery, arbitrary execution, fallback, receive, proxy, or
upgrade selector is present. The gas report's `owner` row came from an intentional failed unknown-selector probe and is
not an ABI function.

### Events

| Event | Topic |
| --- | --- |
| `Transfer(address,address,uint256)` | `ddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef` |
| `DistributionFinalized(address,uint256)` | `6ca016e3777bb1c99ef31901de108920115bbf788621fc22673f61f7a39b211a` |

### Errors

| Error | Selector |
| --- | --- |
| `ApprovalDisabled()` | `64e57b7d` |
| `DistributionAlreadyClosed()` | `a5fedcaa` |
| `DistributionCapExceeded(uint256,uint256)` | `ff9e1b22` |
| `EmptyRecipientArray()` | `a0c4681b` |
| `FinalizationAlreadyCompleted()` | `4b3f1374` |
| `RecipientAlreadyNotified(address)` | `f2639115` |
| `TransferDisabled()` | `a24e573d` |
| `UnauthorizedCaller(address)` | `d86ad9cf` |
| `ZeroAuthority()` | `5ccfa562` |
| `ZeroDistributionCap()` | `ff29fa62` |
| `ZeroRecipient(uint256)` | `ef28bd44` |

### Storage layout

| Slot | Variable | Type |
| ---: | --- | --- |
| 0 | `totalSupply` | `uint256` |
| 1 | `finalized` | `bool` |
| 2 | `balanceOf` | `mapping(address => uint256)` |

`authority` and `distributionCap` are immutables embedded in runtime code and do not occupy mutable storage slots.
Metadata and unit constants also occupy no storage. There is no allowance, ownership, role, recovery, finalization-time,
or upgrade state.

## Coverage

Production coverage from `forge coverage`:

| Metric | Result |
| --- | ---: |
| Lines | 100.00% (48/48) |
| Statements | 100.00% (39/39) |
| Branches | 100.00% (10/10) |
| Functions | 100.00% (10/10) |

No approved production branch or error path remained uncovered. The lower aggregate repository percentage reflects
test-handler branches and is not production-contract coverage.

Coverage is a diagnostic and does not establish security or production readiness.

## Commands and results

The following completed successfully:

```text
forge fmt
forge fmt --check
forge build
forge build --sizes
forge test
forge test -vvv
forge test --gas-report
forge snapshot --snap /tmp/rep-alert-gas.snapshot
forge coverage
slither .
git diff --check
make check
```

`make check` also passed Biome formatting and linting, `tsc --noEmit`, and Bun tests.

## Remaining work

- Approve and record the exact target-chain block gas limit.
- Select and independently review the compile-time maximum batch size.
- Add the maximum constant, getter, custom error, pre-loop enforcement, and boundary tests.
- Decide whether to pin `evm_version` explicitly before candidate freeze.
- Obtain independent human review of source, configuration, ABI, tests, gas evidence, bytecode, and static analysis.
- Implement and independently review recipient tooling after its evidence-dependent inputs are approved.
- Complete deployment preparation, Sepolia rehearsal, candidate freeze, and Etherscan work under their separate gates.

No deployment artifact changed in this validation. No RPC was accessed. No wallet, private key, seed phrase, keystore, or
secret was created, requested, or accessed. No transaction was signed, submitted, or broadcast.

> This validation is not a formal audit and does not establish production readiness.
