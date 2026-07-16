# CHECK AUGUR REP MIGRATION V2 Contract Validation Report

Status: Core V2 candidate validated locally; maximum batch enforcement unresolved

Validation date: 2026-07-16

This report records local implementation review, behavioral testing, gas measurement, static analysis, ABI inspection,
storage-layout inspection, and coverage for the V2 `CHECK AUGUR REP MIGRATION` Solidity candidate.

The preserved
[V1 contract validation report](CONTRACT_VALIDATION_REPORT.md)
documents the superseded `REP MIGRATION ALERT` / `CHECKREP` / no-burn candidate. Its test counts, gas values, ABI,
storage, metadata, and conclusions remain historical evidence and are not rewritten as V2 results.

## Candidate

| Item | Value |
| --- | --- |
| Contract | `RepMigrationAlert` |
| Path | `src/RepMigrationAlert.sol` |
| Production source commit | `628698c96eb71009b9da93dab0cb4da5961da6d0` |
| Validated tree and test commit | `7a8de7b625eb83bd8b5a4f507a2d77fb2b968a16` |
| Name | `CHECK AUGUR REP MIGRATION` |
| Symbol | `MIGRATEREP` |
| Decimals | `0` |
| Solidity | `0.8.36` |
| Optimizer | Enabled, 200 runs |
| Via IR | Disabled |
| Effective EVM version | Osaka |
| EVM pin observation | `foundry.toml` does not explicitly set `evm_version`; Forge 1.7.1 resolves it to Osaka |
| Runtime size | 2,389 bytes |
| Initcode size | 2,654 bytes |
| Runtime size margin | 22,187 bytes |
| Initcode size margin | 46,498 bytes |
| Source line count | 206 |

The effective tool versions were Forge 1.7.1, forge-std v1.16.1, Slither 0.11.5, and Bun 1.3.14.

The runtime and initcode remain below the applicable 24,576-byte runtime and 49,152-byte initcode limits. Compared with
V1, each increased by 468 bytes.

## Review summary

The production source was reviewed line by line against `AGENTS.md`, `docs/product/SPEC.md`,
`docs/security/THREAT_MODEL.md`, and the approved V2 task.

The review covered:

- exact fixed V2 metadata and zero initial issuance;
- explicit nonzero immutable authority and distribution cap;
- deployer and authority separation;
- the private `NeverAlerted`, `Active`, and `Burned` status model;
- authorized atomic distribution;
- zero, duplicate, active-prior-recipient, burned-prior-recipient, empty, and cap rejection;
- permanent `totalIssued` and active `totalSupply` accounting;
- permanent `wasAlerted` history;
- holder-only self-burn before and after finalization;
- burn rejection for never-alerted and already-burned callers;
- prevention of burn-based reissuance or restored cap capacity;
- disabled transfer, transfer-from, approval, allowance, permit, and delegated destruction behavior;
- one-way irreversible issuance finalization;
- finalization event reporting final lifetime issuance;
- event fields, count, and ordering;
- absence of inheritance, external calls, payable paths, recovery, roles, ownership, proxies, upgrades, assembly,
  `delegatecall`, `selfdestruct`, and `tx.origin`;
- ETH-balance-independent behavior.

No production-code defect was observed in the reviewed and tested paths.

The only source-level specification gap is the intentionally deferred compile-time maximum batch size. The V2 candidate
has no maximum constant, getter, custom error, or array-length check. That gap is release-blocking but must not be
resolved until an approved target-chain block gas limit exists and the selected bound receives independent review.

Distribution validation order is:

```text
authority -> finalized -> empty -> cap -> zero/status recipient checks
```

The specification defines the failure conditions but does not freeze their relative precedence. Tests isolate the
intended condition rather than standardizing mixed-invalid precedence.

## V2 accounting and state semantics

The three observable recipient states are:

| State | `balanceOf` | `wasAlerted` | Eligible for distribution | Eligible for self-burn |
| --- | ---: | --- | --- | --- |
| Never alerted | `0` | `false` | Yes | No |
| Active | `1` | `true` | No | Yes |
| Burned | `0` | `true` | No | No |

The only recipient-state transition is:

```text
NeverAlerted -> Active -> Burned
```

The counters have distinct meanings:

```text
totalIssued:
All unique addresses ever successfully alerted.
It increases on distribution and never decreases.

totalSupply:
Currently active, unburned alert units.
It increases on distribution and decreases on valid self-burn.

wasAlerted:
Permanent receipt history.
It remains true after burn.
```

The tested accounting relationship is:

```text
totalSupply <= totalIssued <= distributionCap
```

The cap is enforced against `totalIssued`, not `totalSupply`. Burning therefore cannot create issuance headroom, and a
burned address can never be distributed to again.

A valid `burn()` call:

1. is callable only by the active holder;
2. changes only the caller from `Active` to `Burned`;
3. changes the caller's balance from one to zero;
4. preserves `wasAlerted == true`;
5. decreases `totalSupply` by one;
6. leaves `totalIssued` unchanged;
7. emits `Transfer(holder, address(0), 1)`.

Finalization permanently closes authority-controlled issuance and freezes `totalIssued`. It does not disable valid
holder self-burn, so `totalSupply` may continue to decrease after finalization. The finalization event reports
`totalIssued`, not active supply.

## Test summary

| Suite | Count or campaign | Result |
| --- | ---: | --- |
| Unit behavior tests | 68 | Passed |
| Targeted gas tests | 29 | Passed |
| Fuzz properties | 16 properties × 256 runs = 4,096 cases | Passed |
| Stateful invariant property | 256 runs × 500 calls = 128,000 calls | Passed |
| Total Forge test functions/properties | 114 | Passed |

The unit suite covers construction, metadata, exact errors, deployer-authority separation, successful distribution,
contract recipients, event ordering, cap boundaries, strict rollback, both supply counters, permanent alerted history,
holder and contract-recipient burn, cap behavior after burn, movement and approval rejection, finalization, unknown
administrative selectors, direct ETH rejection, and forced-ETH independence.

The fuzz suite covers:

- unique bounded recipient arrays and disjoint successful batches;
- exact increases to `totalIssued` and `totalSupply`;
- adjacent and non-adjacent duplicates;
- zero-address placement;
- active and burned prior-recipient placement;
- arbitrary unauthorized callers;
- valid current-supply and remaining-lifetime-cap sequences;
- cap overflow before and after burns;
- arbitrary active-holder burn exactly once;
- arbitrary never-alerted burn rejection;
- monotonic `wasAlerted`;
- burn without reissuance or restored headroom;
- finalization freezing `totalIssued` while allowing holder burn;
- arbitrary transfer, transfer-from, and approval rejection.

The stateful invariant handler targets 27 reviewed selectors. Across 128,000 calls, Foundry reported zero handler
reverts and zero discards. The campaign exercises:

- valid, unauthorized, and deployer distribution;
- empty, zero, adjacent-duplicate, non-adjacent-duplicate, active-prior-recipient, and burned-prior-recipient batches;
- cap-boundary and cap-overflow distribution;
- authorized, unauthorized, deployer, repeated, and post-finalization actions;
- valid burn before and after finalization;
- burn by the authority, deployer, never-alerted caller, and already-burned caller;
- attempted reissuance to burned recipients;
- transfer, transfer-from, approval, and forced-ETH actions.

The invariant campaign continuously establishes:

- each tracked balance is zero or one;
- the zero address is never alerted and remains at zero balance;
- `wasAlerted` never changes from true to false;
- active and burned statuses match the reference model;
- burned addresses never become active again;
- only an active holder can burn its own unit;
- `totalIssued` equals the unique addresses ever alerted;
- `totalSupply` equals currently active alert units;
- `totalSupply <= totalIssued <= distributionCap`;
- burn never changes `totalIssued` or restores cap capacity;
- failed actions change neither counter or recipient state;
- finalization changes at most once and permanently freezes `totalIssued`;
- after finalization, `totalSupply` can decrease only through valid self-burn;
- no transfer, transfer-from, or approval succeeds;
- sampled allowances remain zero.

Foundry's `recordLogs` inspector records attempted `LOG` operations from reverted frames. It is therefore not used to
claim that a late-invalid call produced persistent logs. Exact revert data, complete state rollback, and EVM revert
semantics establish atomicity; successful calls separately prove exact persistent event count and calldata order.

## Gas results

### Method

The authoritative V2 gas evidence below comes from the dedicated JSON values written under:

```text
/tmp/rep-alert-v2-snapshot-values/
```

These are the isolated optimized measurement-test values produced during:

```text
FOUNDRY_SNAPSHOTS=/tmp/rep-alert-v2-snapshot-values \
forge snapshot --snap /tmp/rep-alert-v2-gas.snapshot
```

The tables do not reuse the gas columns emitted by `forge test --gas-report`, whose instrumentation can contaminate
measurement helpers.

Every successful distribution measurement used a fresh contract and entirely new recipient addresses. All 20
recipient-address bytes were nonzero so calldata pricing was not artificially reduced. The target account and slots
were marked cold before the measured call.

The measurement tests record:

- callee execution gas under the normal optimized Forge mode;
- exact ABI-encoded calldata bytes;
- standard zero/nonzero calldata gas;
- the Osaka/[EIP-7623](https://eips.ethereum.org/EIPS/eip-7623) calldata floor;
- estimated total transaction gas as `21,000 + max(calldata gas + execution gas, Osaka floor data gas)`.

No RPC or live chain was used.

Deployment gas was 511,565.

### Successful distribution batches

| Recipients | Calldata bytes | Calldata gas | Execution gas | Osaka total gas | Increment from prior point |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 100 | 712 | 71,707 | 93,419 | n/a |
| 10 | 388 | 4,024 | 292,828 | 317,852 | 24,937 per recipient |
| 25 | 868 | 9,544 | 661,363 | 691,907 | 24,937 per recipient |
| 50 | 1,668 | 18,744 | 1,275,588 | 1,315,332 | 24,937 per recipient |
| 100 | 3,268 | 37,144 | 2,504,038 | 2,562,182 | 24,937 per recipient |
| 200 | 6,468 | 73,944 | 4,960,938 | 5,055,882 | 24,937 per recipient |
| 500 | 16,068 | 184,356 | 12,331,638 | 12,536,994 | approximately 24,937 per recipient |

The measured execution increment is approximately 24,569 gas per recipient. Each additional ABI address word adds 368
calldata gas, producing an approximately 24,937 total-gas increment per added recipient over the measured range.

### V1 versus V2 distribution

The V1 values below are copied exactly from the preserved historical V1 report. Calldata is unchanged because the
distribution function signature and recipient encoding are unchanged.

| Recipients | V1 Osaka total | V2 Osaka total | Exact delta | Increase |
| ---: | ---: | ---: | ---: | ---: |
| 1 | 71,058 | 93,419 | 22,361 | 31.4687% |
| 10 | 294,141 | 317,852 | 23,711 | 8.0611% |
| 25 | 665,946 | 691,907 | 25,961 | 3.8984% |
| 50 | 1,285,621 | 1,315,332 | 29,711 | 2.3110% |
| 100 | 2,524,971 | 2,562,182 | 37,211 | 1.4737% |
| 200 | 5,003,671 | 5,055,882 | 52,211 | 1.0435% |
| 500 | 12,439,783 | 12,536,994 | 97,211 | 0.7815% |

At every measured point, the exact V2 distribution delta is:

```text
22,211 fixed gas per call + 150 gas per recipient
```

The fixed component is consistent with maintaining the added lifetime `totalIssued` counter. The small linear
per-recipient component is consistent with the revised status checks and enum accounting. The selected model still
writes only one recipient status mapping slot. It avoids a second zero-to-nonzero per-recipient write that a separate
balance mapping plus permanent `wasAlerted` mapping would require.

V1's measured incremental total was approximately 24,787 gas per additional recipient. V2's is approximately 24,937,
an incremental difference of 150 gas per recipient.

### Burn, reissuance, cap-after-burn, and finalization paths

| Scenario | Calldata bytes | Calldata gas | Execution gas | Osaka total gas | Result |
| --- | ---: | ---: | ---: | ---: | --- |
| First burn | 4 | 64 | 12,424 | 33,488 | Succeeded |
| Burn after multiple issuances | 4 | 64 | 12,424 | 33,488 | Succeeded |
| Burn before finalization | 4 | 64 | 12,424 | 33,488 | Succeeded |
| Burn after finalization | 4 | 64 | 12,424 | 33,488 | Succeeded |
| Burn by never-alerted caller | 4 | 64 | 2,469 | 23,533 | Reverted |
| Repeated burn | 4 | 64 | 2,469 | 23,533 | Reverted |
| Reissue burned recipient | 100 | 712 | 7,497 | 29,209 | Reverted |
| Exact cap boundary after burns | 100 | 712 | 54,607 | 76,319 | Succeeded |
| Cap overflow after burns | 100 | 712 | 4,983 | 26,695 | Reverted |
| Finalization after burns | 4 | 64 | 26,073 | 47,137 | Succeeded |

The identical successful burn measurements confirm that burn cost is independent of finalization state and of the
number of other issued recipients in these measured paths. The reissuance and cap-after-burn cases confirm that active
supply reduction does not change permanent issuance eligibility or lifetime capacity.

### Other failure paths

The large-array cases below use 500-entry calldata except where noted.

| Scenario | Calldata bytes | Execution gas | Osaka total gas | Result |
| --- | ---: | ---: | ---: | --- |
| Empty array | 68 | 2,710 | 24,042 | Reverted |
| Duplicate at start | 16,068 | 30,066 | 481,890 | Reverted |
| Duplicate in middle | 16,068 | 6,147,747 | 6,353,103 | Reverted |
| Duplicate at end | 16,068 | 12,265,428 | 12,470,784 | Reverted |
| Previously alerted at end | 16,068 | 12,267,428 | 12,472,784 | Reverted |
| Zero recipient at end | 16,068 | 12,265,175 | 12,470,291 | Reverted |
| Exact cap boundary | 16,068 | 12,331,638 | 12,536,994 | Succeeded |
| Cap overflow | 16,068 | 4,983 | 481,890 | Reverted |
| Unauthorized caller | 16,068 | 585 | 481,890 | Reverted |
| Finalization | 4 | 26,073 | 47,137 | Succeeded |
| Repeated finalization | 4 | 2,417 | 23,481 | Reverted |

The Osaka calldata floor dominates large-calldata calls that revert before meaningful execution, including unauthorized,
cap-overflow, and early-duplicate calls.

### Maximum-batch decision

Case B continues to apply. No approved numeric target-chain block gas limit exists in the repository. The local Forge
defaults are test-runner settings and are not an approved chain pin.

No `MAX_BATCH_SIZE` constant, getter, custom error, or enforcement was added.

Evidence-supported candidates for later review are:

| Candidate | Measured successful gas | Minimum approved block gas limit required by the 50% rule |
| ---: | ---: | ---: |
| 100 | 2,562,182 | 5,124,364 |
| 200 | 5,055,882 | 10,111,764 |
| 500 | 12,536,994 | 25,073,988 |

The future review must select the lower of the gas-supported bound and any stricter calldata, transaction-tooling, or
manual-signing constraint. No value above 500 should be inferred without an additional measured point. The
implementation remains in progress until the approved target input exists and the chosen constant receives independent
review.

## Static analysis and compiler diagnostics

`slither .` analyzed one production contract with 101 detectors and returned zero results.

| Finding class | Count | Resolution |
| --- | ---: | --- |
| Confirmed issue | 0 | None |
| False positive | 0 | None |
| Expected approved behavior | 0 | None reported by Slither |
| Needs investigation | 0 | None reported by Slither |

The Solidity compiler produced no diagnostics when run with warnings denied.

Forge emitted an environment warning because its global signature cache is read-only:

```text
failed to flush signature cache ... Read-only file system
```

This warning did not affect compilation, tests, snapshots, or measurements.

Forge coverage disabled optimizer and via IR for instrumentation and emitted source-anchor mapping warnings. Coverage
still produced a complete production map. These warnings are classified as coverage-tooling limitations, not compiler
or contract findings.

The Slither and compiler results are not an audit and do not prove absence of vulnerabilities.

## ABI and storage

The ABI contains one constructor, 17 callable functions, two events, and 12 custom errors. The maximum-batch getter is
absent because the evidence gate remains unresolved.

### Constructor

```solidity
constructor(address authority_, uint256 distributionCap_)
```

The constructor is nonpayable, rejects a zero authority and zero cap, performs no issuance, and derives no privilege
from the deployer.

### Complete callable ABI and method identifiers

| Function | Mutability and return | Identifier |
| --- | --- | --- |
| `allowance(address,address)` | `pure returns (uint256)` | `0xdd62ed3e` |
| `approve(address,uint256)` | `pure returns (bool)` | `0x095ea7b3` |
| `authority()` | `view returns (address)` | `0xbf7e214f` |
| `balanceOf(address)` | `view returns (uint256)` | `0x70a08231` |
| `burn()` | `nonpayable` | `0x44df8e70` |
| `decimals()` | `pure returns (uint8)` | `0x313ce567` |
| `distribute(address[])` | `nonpayable` | `0x6138889b` |
| `distributionCap()` | `view returns (uint256)` | `0xcd63d930` |
| `finalize()` | `nonpayable` | `0x4bb278f3` |
| `finalized()` | `view returns (bool)` | `0xb3f05b97` |
| `name()` | `pure returns (string)` | `0x06fdde03` |
| `symbol()` | `pure returns (string)` | `0x95d89b41` |
| `totalIssued()` | `view returns (uint256)` | `0xf5be3193` |
| `totalSupply()` | `view returns (uint256)` | `0x18160ddd` |
| `transfer(address,uint256)` | `pure returns (bool)` | `0xa9059cbb` |
| `transferFrom(address,address,uint256)` | `pure returns (bool)` | `0x23b872dd` |
| `wasAlerted(address)` | `view returns (bool)` | `0xb5bf3dfd` |

`transfer`, `transferFrom`, and `approve` are `pure` because they unconditionally revert without reading state.

`burn()` is the sole destruction path. There is no `burn(uint256)`, `burnFrom`, authority burn, operator burn,
signature burn, batch burn, callback burn, recovery burn, or burn-and-reissue selector.

The following forbidden or unintended surfaces are absent:

```text
owner()
transferOwnership()
renounceOwnership()
grantRole()
revokeRole()
mint()
permit()
pause()
unpause()
recover()
burn(uint256)
burnFrom(address,uint256)
```

There is also no fallback, receive, payable, arbitrary execution, REP interaction, migration-contract interaction,
withdrawal, proxy, upgrade, or delegatecall surface.

### Events

| Event | Topic |
| --- | --- |
| `DistributionFinalized(address,uint256)` | `0x6ca016e3777bb1c99ef31901de108920115bbf788621fc22673f61f7a39b211a` |
| `Transfer(address,address,uint256)` | `0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef` |

`Transfer(address(0), recipient, 1)` records issuance. `Transfer(holder, address(0), 1)` records valid self-burn.
`DistributionFinalized(authority, totalIssued)` records the final lifetime issued count. The parameter-name change to
`finalIssued` does not change the event topic from V1.

### Errors

| Error | Selector |
| --- | --- |
| `ApprovalDisabled()` | `0x64e57b7d` |
| `DistributionAlreadyClosed()` | `0xa5fedcaa` |
| `DistributionCapExceeded(uint256,uint256)` | `0xff9e1b22` |
| `EmptyRecipientArray()` | `0xa0c4681b` |
| `FinalizationAlreadyCompleted()` | `0x4b3f1374` |
| `NoAlertBalance(address)` | `0x9c2f50f3` |
| `RecipientAlreadyNotified(address)` | `0xf2639115` |
| `TransferDisabled()` | `0xa24e573d` |
| `UnauthorizedCaller(address)` | `0xd86ad9cf` |
| `ZeroAuthority()` | `0x5ccfa562` |
| `ZeroDistributionCap()` | `0xff29fa62` |
| `ZeroRecipient(uint256)` | `0xef28bd44` |

`DistributionCapExceeded` now names its first ABI parameter `attemptedIssued`, matching lifetime-cap semantics.
`NoAlertBalance` is the only new V2 custom error.

### Storage layout

| Slot | Offset | Bytes | Variable | Type |
| ---: | ---: | ---: | --- | --- |
| 0 | 0 | 32 | `totalIssued` | `uint256` |
| 1 | 0 | 32 | `totalSupply` | `uint256` |
| 2 | 0 | 1 | `finalized` | `bool` |
| 3 | 0 | 32 | `_status` | `mapping(address => AlertStatus)` |

`authority` and `distributionCap` are immutables embedded in runtime code and do not occupy mutable storage slots.
Metadata and unit constants also occupy no storage.

The single status mapping avoids separate per-recipient balance and permanent-history mappings. There is no allowance,
ownership, role, recovery, finalization-time, upgrade, or generalized mutable-status storage.

## Coverage

Production coverage from `forge coverage`:

| Metric | Production result | Aggregate repository result |
| --- | ---: | ---: |
| Lines | 100.00% (59/59) | 84.45% (277/328) |
| Statements | 100.00% (49/49) | 91.41% (330/361) |
| Branches | 100.00% (11/11) | 58.62% (34/58) |
| Functions | 100.00% (13/13) | 96.36% (53/55) |

No approved production branch or error path remained uncovered. The lower aggregate percentages reflect test-handler and
supporting-test branches rather than uncovered production behavior.

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
FOUNDRY_SNAPSHOTS=/tmp/rep-alert-v2-snapshot-values forge snapshot --snap /tmp/rep-alert-v2-gas.snapshot
forge coverage
slither .
make check
git diff --check
```

The dedicated snapshot run completed 114 tests with zero failures or skips. The invariant campaign completed 256 runs,
128,000 calls, zero handler reverts, and zero discards.

`make check` also passed Biome formatting and linting, `tsc --noEmit`, and Bun tests.

## Known limitations and remaining work

- No approved target-chain block gas limit exists.
- No `MAX_BATCH_SIZE` constant or enforcement is frozen.
- The effective Osaka EVM version is not explicitly pinned in `foundry.toml`.
- No formal audit has occurred.
- Independent human review of source, configuration, ABI, tests, gas evidence, bytecode, storage, and static analysis
  remains required.
- Recipient sources, migration semantics, snapshot, thresholds, exclusions, final manifest, and numeric cap remain
  separately release-gated.
- Recipient tooling, pinned-fork simulation, Sepolia rehearsal, candidate freeze, mainnet preparation, and Etherscan work
  remain incomplete.
- Third-party wallet or explorer display remains unguaranteed.

The V2 implementation and local validation do not establish recipient correctness, operational readiness, key safety,
deployment correctness, independent review completion, or mainnet readiness.

No deployment artifact changed in this validation. No RPC was accessed. No wallet, private key, seed phrase, keystore,
or secret was created, requested, or accessed. No transaction was signed, submitted, or broadcast. Nothing was pushed.

> This validation is not a formal audit and does not establish production readiness.
