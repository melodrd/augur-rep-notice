# Contract Validation

Status: current local evidence as of 2026-07-17.

This document records reproducible evidence for `MigrateRepV2Token`. It is not an audit, does not prove that vulnerabilities are absent, and does not establish recipient, operational, or deployment readiness. All figures come from the checked-in configuration and the local toolchain; no RPC, wallet, key, or live chain was involved.

## Candidate

| Item | Value |
| --- | --- |
| Contract | `src/MigrateRepV2Token.sol` |
| Inheritance | `ERC20` (OpenZeppelin v5.6.1) only |
| Solidity | `0.8.36` |
| EVM target | `osaka` |
| Optimizer | enabled, 200 runs |
| Via IR | disabled |
| Forge | `1.7.1` |
| OpenZeppelin Contracts | `v5.6.1` at `5fd1781b1454fd1ef8e722282f86f9293cacf256` |
| forge-std | `v1.16.2` at `bf647bd6046f2f7da30d0c2bf435e5c76a780c1b` |
| Slither | `0.11.5` |
| Bun | `1.3.14` |

The checked-in `foundry.toml` is the canonical build configuration. Compilation completed without Solidity diagnostics, and `forge lint src script` reported no findings.

## Metadata and construction

`name() == "MIGRATE REPV2"`, `symbol() == "MREP2"`, `decimals() == 18` (inherited, not overridden), `TOKEN_PER_RECIPIENT() == 1e18`, `MAX_BATCH_SIZE() == 200`. At construction the whole `recipientCap * 1e18` supply is minted to `address(this)`; the deployer and distributor hold zero, `totalInitialRecipients` is zero, and `distributionFinalized` is false. There is no callable function that increases `totalSupply()`.

## Distribution validation order

```text
authorization -> finalized -> empty -> maximum batch -> recipient cap -> recipient validation
```

Focused adjacent double-fault tests lock authorization > finalized, finalized > empty, maximum batch > recipient cap, and recipient cap > recipient validation. Recipient validation rejects the zero address and any prior initial recipient, including a duplicate earlier in the same batch, and every failure reverts the whole call atomically.

## Test evidence

| Suite | Campaign | Result |
| --- | ---: | --- |
| Unit (`test/MigrateRepV2Token.t.sol`) | 67 tests | passed |
| Fuzz (`test/fuzz/`) | 7 properties x 128 runs | passed |
| Invariant (`test/invariant/`) | 6 invariants x 16 runs x 64 depth = 1,024 calls each | passed |
| Deploy script (`test/script/`) | 8 tests | passed |
| Gas (`test/gas/`) | 14 tests | passed |
| Total | 102 tests | passed |

The invariant handler drives distribution, transfers, approvals, `transferFrom`, and finalization over a fixed actor pool with zero reverts and zero discards, reconciling total supply, the recipient cap, the full balance set, permanent history, reserve accounting, and post-finalization distribution rejection.

Approximate durations (local):

| Target | Duration |
| --- | ---: |
| `make test-unit` | ~0.003s Forge / ~0.1s wall |
| `make test-fuzz` | ~0.5s |
| `make test-invariant` | ~1.2s |
| `make test` (ordinary, 88 tests) | ~1.8s |
| `make gas` | ~0.04s |
| `make check` | ~10s |
| `make coverage` | ~4.4s |
| `make check-deep` | ~5.7s |

`make check-deep` runs the deep profile once (fuzz 256 runs; invariant 32 runs x 128 depth = 4,096 calls each).

## Production coverage

| Metric | Production result |
| --- | ---: |
| Lines | 100.00% (41/41) |
| Statements | 100.00% (40/40) |
| Branches | 100.00% (12/12) |
| Functions | 100.00% (3/3) |

Coverage is reported for `src/` only (`--no-match-coverage '(test\|script)/'`) and excludes the gas suite. OpenZeppelin dependency code is not treated as project-owned coverage. The three counted functions are the constructor, `distribute`, and `finalizeDistribution`; inherited ERC-20 functions and auto-generated getters are OpenZeppelin's.

## Size and optimizer selection

| Optimizer runs | Deployment (create-frame) | distribute/100 (Osaka) | transfer (Osaka) | Runtime bytes | Initcode bytes |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 727,761 | 4,826,466 | 46,795 | 3,008 | 4,275 |
| 200 | 741,397 | 4,826,399 | 46,642 | 3,076 | 4,344 |
| 1,000 | 805,508 | 4,826,377 | 46,620 | 3,396 | 4,664 |

Distribution — the dominant campaign cost — is essentially optimizer-insensitive (about 1 gas per recipient across the whole range) because it is dominated by cold storage writes. Runs=200 captures the transfer-path savings (about 153 gas per transfer versus runs=1) at a small deployment cost, while runs=1,000 adds about 64k deployment gas and 320 runtime bytes for only about 22 additional gas per transfer. **Optimizer runs = 200 is selected.** Final runtime is 3,076 bytes (21,500 below the 24,576 limit); initcode is 4,344 bytes (44,808 below the 49,152 limit).

## Batch-size selection

The rewritten ERC-20 performs a cold recipient-balance write plus a cold history write per recipient, so per-recipient cost is far above the previous non-transferable contract. Worst-case successful calls (all-nonzero address bytes, cold recipients) measured as Osaka transaction gas `21000 + max(calldata + execution, 10 * tokens)`:

| Recipients | Calldata gas | Execution gas | Osaka tx gas | % of 16,777,216 cap |
| ---: | ---: | ---: | ---: | ---: |
| 1 | 712 | 72,388 | 94,100 | 0.6% |
| 10 | 4,024 | 499,285 | 524,309 | 3.1% |
| 25 | 9,544 | 1,210,780 | 1,241,324 | 7.4% |
| 50 | 18,744 | 2,396,605 | 2,436,349 | 14.5% |
| 100 | 37,144 | 4,768,255 | 4,826,399 | 28.8% |
| 150 | 55,544 | 7,139,905 | 7,216,449 | 43.0% |
| **200** | **73,944** | **9,511,555** | **9,606,499** | **57.3%** |
| 250 | 92,344 | 11,883,205 | 11,996,549 | 71.5% |
| 300 | 110,756 | 14,254,855 | 14,386,611 | 85.7% |

`MAX_BATCH_SIZE = 200`. Its worst-case successful call is 9,606,499 gas — 57.3% of the 16,777,216 Osaka transaction gas cap and comfortably under the 70% target (11,744,051), with about 2.1M gas of headroom. 250 already exceeds the 70% target. The incremental cost is about 47,801 Osaka gas per recipient (47,433 execution, 368 calldata). Operations should normally use batches of about 100 and no more than 150; 200 is the hard ceiling, not the recommended size.

## Gas figures with illustrative USDC

Illustrative only: assumes ETH = $2,000 and shows 0.1 / 1 / 3 gwei. `USDC = gas * gwei * 1e-9 * 2000`. These are assumptions, not live prices.

| Scenario | Osaka tx gas | @0.1 gwei | @1 gwei | @3 gwei |
| --- | ---: | ---: | ---: | ---: |
| Deployment (create-frame) | 741,397 | $0.148 | $1.483 | $4.448 |
| distribute 1 | 94,100 | $0.019 | $0.188 | $0.565 |
| distribute 100 | 4,826,399 | $0.965 | $9.653 | $28.958 |
| distribute 150 | 7,216,449 | $1.443 | $14.433 | $43.299 |
| distribute 200 (max) | 9,606,499 | $1.921 | $19.213 | $57.639 |
| transfer (cold recipient) | 46,642 | $0.009 | $0.093 | $0.280 |
| transfer (zero value) | 28,670 | $0.006 | $0.057 | $0.172 |
| approve | 46,195 | $0.009 | $0.092 | $0.277 |
| transferFrom (finite allowance) | 47,593 | $0.010 | $0.095 | $0.286 |
| transferFrom (max allowance) | 47,156 | $0.009 | $0.094 | $0.283 |
| finalizeDistribution | 47,575 | $0.010 | $0.095 | $0.286 |
| unauthorized distribution (revert) | 22,780 | $0.005 | $0.046 | $0.137 |
| empty batch (revert) | 24,042 | $0.005 | $0.048 | $0.144 |
| 201 oversized (revert) | 206,780 | $0.041 | $0.414 | $1.241 |
| cap overflow, 101 vs cap 100 (revert) | 114,780 | $0.023 | $0.230 | $0.689 |
| duplicate at final index of 200 (revert) | 9,539,609 | $1.908 | $19.079 | $57.238 |
| zero at final index of 200 (revert) | 9,539,142 | $1.908 | $19.078 | $57.235 |

The Osaka calldata floor dominates the oversized and cap-overflow rejections, which revert before iterating. Late-duplicate and late-zero rejections cost almost as much as a full successful batch because they revert only at the final recipient.

Incremental cost per recipient: about 47,801 Osaka gas (about $0.0096 at 0.1 gwei, $0.096 at 1 gwei, $0.287 at 3 gwei).

Campaign totals (deployment plus distribution, operational batch size 100):

| Recipients | Batches | Osaka gas | @0.1 gwei | @1 gwei | @3 gwei |
| ---: | --- | ---: | ---: | ---: | ---: |
| 100 | 1x100 | 5,567,796 | $1.11 | $11.14 | $33.41 |
| 250 | 100+100+50 | 12,830,544 | $2.57 | $25.66 | $76.98 |
| 500 | 5x100 | 24,873,392 | $4.97 | $49.75 | $149.24 |
| 1,000 | 10x100 | 49,005,387 | $9.80 | $98.01 | $294.03 |

## Gas method

`test/gas/MigrateRepV2TokenGas.t.sol` measures optimized calls in isolation with fresh contracts and cold state. Execution gas is the call-frame gas from `vm.lastCallGas().gasTotalUsed`; calldata gas is computed from the encoded calldata (4 per zero byte, 16 per nonzero byte); the Osaka transaction gas applies the floor formula above. Deployment is the measured CREATE-frame gas (execution plus code deposit); a real creation transaction replaces the CREATE base with the 21,000 transaction base plus initcode calldata cost. `forge test --gas-report` remains diagnostic only. Reproduce with `make gas`.

## ABI, storage, and diagnostics

The callable surface is exactly the nine standard ERC-20 functions plus `TOKEN_PER_RECIPIENT`, `MAX_BATCH_SIZE`, `distributor`, `recipientCap`, `maximumSupply`, `totalInitialRecipients`, `distributionFinalized`, `wasInitialRecipient`, `distribute`, and `finalizeDistribution`. `make consistency` and manual inspection confirm no `mint`, `burn`, `owner`, `transferOwnership`, `grantRole`, `pause`, `blacklist`, `setFee`, `enableTrading`, `permit`, `delegate`, `claim`, `redeem`, `upgradeTo`, `withdraw`, `recoverToken`, `transferAndCall`, or `approveAndCall` selector.

Storage (slots 0-4 are OpenZeppelin ERC-20): `totalInitialRecipients` (slot 5), `distributionFinalized` (slot 6), `wasInitialRecipient` (slot 7). Immutables (`distributor`, `recipientCap`, `maximumSupply`) and constants occupy no mutable storage.

Events: standard `Transfer` and `Approval`, plus `DistributionFinalized(address,uint256,uint256)` whose third field is `contractBalanceAtFinalization` — the token contract's complete balance at finalization, not a mathematically exact undistributed allocation; parameter types, indexed fields, and the event topic are unchanged. Errors: ten project custom errors plus the six inherited `IERC20Errors`, none wrapped or duplicated.

Slither (`slither .`, filtered to project source) analyzed the compiled contract set with 101 detectors and reported **0 results**; no finding was suppressed. This is not an audit.

## Validation commands

```bash
make check         # fmt-check, lint, build+sizes, ordinary tests, ops-check, Slither, consistency
make coverage      # production coverage, excludes the gas suite
make gas           # isolated gas measurements
make check-deep    # deep fuzz/invariant profile, once
forge inspect MigrateRepV2Token abi
forge inspect MigrateRepV2Token methodIdentifiers
forge inspect MigrateRepV2Token storageLayout
forge inspect MigrateRepV2Token events
forge inspect MigrateRepV2Token errors
```

## Known limitations

- No formal audit or independent human release review has occurred.
- Gas figures are local measurements, not target-chain observations; deployment preparation must reconfirm execution, calldata, and transaction-tool behavior against approved chain conditions.
- Recipient sources, snapshot, migration semantics, filters, manifest, the numeric `recipientCap`, and the production distributor remain unapproved or out of scope.
- No fork, RPC, wallet, deployment, source-verification, or live-chain rehearsal was performed.
- Automatic wallet display and third-party reputation labels are not guaranteed.
