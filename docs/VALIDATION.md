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

## Construction validation order

```text
zero distributor -> token contract distributor -> zero recipient cap -> supply overflow
```

A focused test uses `vm.computeCreateAddress` with the deployer's next nonce to prove that deploying with the predicted token address as its own distributor reverts with `TokenContractDistributor`; a companion test pins the prediction itself against a real deployment. Double-fault tests lock the token-contract check ahead of both the zero-cap and overflow checks, and the zero distributor ahead of the zero cap. EOA distributors and contract distributors (including one that then distributes successfully) both still work.

## Distribution validation order

```text
authorization -> finalized -> empty -> maximum batch -> recipient cap -> recipient validation
```

Recipient validation itself is ordered:

```text
zero address -> token contract -> previously distributed
```

Focused adjacent double-fault tests lock authorization > finalized, finalized > empty, maximum batch > recipient cap, and recipient cap > recipient validation — the outer order is unchanged. Within recipient validation, tests lock zero > token contract, and token contract > already-distributed (including a batch repeating `address(token)`, where the token-contract error wins over the duplicate error). Recipient validation rejects the zero address, the token contract, and any prior initial recipient including a duplicate earlier in the same batch; every failure reverts the whole call atomically.

Ordinary contract recipients are unaffected: tests distribute successfully to a second deployed contract and to the test contract. `recipient.code.length` is not consulted anywhere in the production source.

## Test evidence

| Suite | Campaign | Result |
| --- | ---: | --- |
| Unit (`test/MigrateRepV2Token.t.sol`) | 82 tests | passed |
| Fuzz (`test/fuzz/`) | 8 properties x 128 runs | passed |
| Invariant (`test/invariant/`) | 9 invariants x 16 runs x 64 depth = 1,024 calls each | passed |
| Deploy script (`test/script/`) | 8 tests | passed |
| Gas (`test/gas/`) | 15 tests | passed |
| Forge total | 122 tests | passed |
| TypeScript (`ops/`) | 58 tests across 4 files | passed |

The invariant handler drives distribution, transfers, approvals, `transferFrom`, and finalization over a fixed 8-actor pool at cap 20, with zero reverts and zero discards. Transfers and approved `transferFrom` operations may target `address(token)`, modelling holders returning MREP2 to the contract — permitted ERC-20 behavior the previous handler could not reach. Returned tokens are tracked in an independent ghost value, and the invariants reconcile:

```text
token contract balance = maximumSupply
                       - totalInitialRecipients * TOKEN_PER_RECIPIENT
                       + tokens returned to the contract

actor balance sum      = totalInitialRecipients * TOKEN_PER_RECIPIENT
                       - tokens returned to the contract
```

The nine invariants cover: fixed total supply; the recipient cap; the full balance set summing to total supply; the ghost recipient count and distinct flagged actors matching `totalInitialRecipients` (so no address is initially distributed to twice); history only changing false to true; the returned-token balance model above; the remaining initial allocation never exceeding the contract balance; the token contract never becoming an initial recipient (re-attempted live at every step); and distribution always failing after finalization. The returned-token path is genuinely exercised, not vacuous: a probe asserting zero returns fails within two runs.

Approximate durations (local):

| Target | Duration |
| --- | ---: |
| `make test` (ordinary, 107 tests) | ~1.6s |
| `make gas` | ~0.3s |
| `make check` | ~14.6s |
| `make coverage` | ~2.4s |
| `make check-deep` | ~2.9s |

`make check` remains the fast default gate and carries no gas, coverage, or deep profile. `make check-deep` runs the deep profile once (fuzz 256 runs; invariant 32 runs x 128 depth = 4,096 calls each), and all nine invariants pass there with zero reverts.

## Offline recipient tooling

The Bun/TypeScript suite (58 tests) covers three offline modules. Everything is pure and deterministic: no test or module opens a network connection, signs, or reads a key.

`ops/src/manifest.ts` (schema version 2) derives `recipientCap` from the final normalized unique recipient list — the build API accepts no cap, so discretionary headroom is unreachable rather than merely discouraged. Tests prove: an empty recipient list fails; 250 unique recipients produce `recipientCap == 250` and `maximumSupply == 250 * TOKEN_PER_RECIPIENT`; the final batch ends with zero remaining initial allocation across several batch sizes; a smuggled runtime `recipientCap` is ignored; duplicates are rejected rather than inflating the cap; and inputs are not mutated. Provenance is mandatory and validated (positive chain ID, canonical positive block number, 32-byte block hash, at least one valid non-zero non-duplicate source contract, well-formed SHA-256 checksums, non-empty ruleset ID) but never invented — tests use explicit fixtures that are not proposed REP values.

`ops/src/distribution-plan.ts` binds an approved manifest to a deployed candidate offline. Tests prove: deterministic output; calldata that decodes back to the exact recipient array; rejection of the zero and malformed token addresses; rejection when the deployed token address appears anywhere in the recipient list (checked case-insensitively against a real mid-list recipient); rejection of a chain mismatch against the manifest snapshot; manifest-checksum propagation; correct cumulative recipient and remaining-allocation accounting; absence of any nonce, fee, gas, value, or signature field; and no mutation of the input manifest.

`ops/src/cli.ts` (`bun run manifest`) builds a manifest from explicit JSON files and writes JSON and CSV. Tests prove it refuses to overwrite existing output without `--force` and leaves the original file untouched when it refuses, fails on an empty recipient list, fails on missing provenance rather than defaulting it, and reports missing files and usage errors.

## Production coverage

| Metric | Production result |
| --- | ---: |
| Lines | 100.00% (45/45) |
| Statements | 100.00% (44/44) |
| Branches | 100.00% (14/14) |
| Functions | 100.00% (3/3) |

Coverage is reported for `src/` only (`--no-match-coverage '(test\|script)/'`) and excludes the gas suite. OpenZeppelin dependency code is not treated as project-owned coverage. The three counted functions are the constructor, `distribute`, and `finalizeDistribution`; inherited ERC-20 functions and auto-generated getters are OpenZeppelin's.

## Size and optimizer selection

| Optimizer runs | Deployment (CREATE-frame) | distribute/100 (Osaka) | transfer (Osaka) | Runtime bytes | Initcode bytes |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 736,781 | 4,830,466 | 46,795 | 3,052 | 4,360 |
| 200 | 750,414 | 4,830,399 | 46,642 | 3,120 | 4,429 |
| 1,000 | 819,565 | 4,830,377 | 46,620 | 3,465 | 4,774 |

Distribution — the dominant campaign cost — is essentially optimizer-insensitive (about 1 gas per recipient across the whole range) because it is dominated by cold storage writes. Runs=200 captures the transfer-path savings (153 gas per transfer versus runs=1) at a small deployment cost, while runs=1,000 adds about 69k deployment gas and 345 runtime bytes for only 22 additional gas per transfer. **Optimizer runs = 200 is selected**, unchanged by this revision. Final runtime is 3,120 bytes (21,456 below the 24,576 limit); initcode is 4,429 bytes (44,723 below the 49,152 limit).

## Batch-size selection

The contract performs a cold recipient-balance write plus a cold history write per recipient, so per-recipient cost is dominated by cold storage. Worst-case successful calls (all-nonzero address bytes, cold recipients) measured as Osaka transaction gas `21000 + max(calldata + execution, 10 * tokens)`:

| Recipients | Calldata gas | Execution gas | Osaka tx gas | % of 16,777,216 cap |
| ---: | ---: | ---: | ---: | ---: |
| 1 | 712 | 72,428 | 94,140 | 0.6% |
| 10 | 4,024 | 499,685 | 524,709 | 3.1% |
| 25 | 9,544 | 1,211,780 | 1,242,324 | 7.4% |
| 50 | 18,744 | 2,398,605 | 2,438,349 | 14.5% |
| 100 | 37,144 | 4,772,255 | 4,830,399 | 28.8% |
| 150 | 55,544 | 7,145,905 | 7,222,449 | 43.1% |
| **200** | **73,944** | **9,519,555** | **9,614,499** | **57.3%** |

**`MAX_BATCH_SIZE = 200` is retained.** Its worst-case successful call is 9,614,499 gas — 57.31% of the 16,777,216 Osaka transaction gas cap, under the documented 70% target (11,744,051) with 2,129,552 gas of margin against that target and 7,162,717 below the cap itself. The new token-contract recipient check cost 8,000 Osaka gas at the 200 maximum (9,606,499 → 9,614,499, +0.08%), which does not approach the target.

The incremental cost is 47,841 Osaka gas per recipient (47,473 execution, 368 calldata), linear across the measured range: the extrapolated 50-recipient remainder used in the campaign table below (2,438,349) equals the measured value exactly. By that extrapolation the 70% target would be reached at about 245 recipients; sizes above 200 are not measurable against this contract, because 201 is rejected. Operations should normally use batches of about 100 and no more than 150; 200 is the hard ceiling, not the recommended size.

## Deployment gas

Deployment is reported as three separate figures. The CREATE-frame measurement is not the full deployment-transaction gas, and none of these is a live-chain estimate — no RPC was consulted.

| Component | Gas | Source |
| --- | ---: | --- |
| Constructor / CREATE-frame | 750,414 | measured (initcode execution plus code deposit, as charged inside the CREATE opcode, which includes the 32,000 create cost) |
| Creation transaction intrinsic base | 21,000 | computed (the transaction base a CREATE frame never pays) |
| Initcode calldata gas | 67,856 | computed from the 4,493-byte initcode (4/zero byte, 16/nonzero byte) |
| **Full deployment transaction** | **839,270** | **local approximation only** |

The approximation applies the same Osaka floor formula to the measured CREATE frame and the initcode calldata. It uses the CREATE frame as a proxy for creation-transaction execution, which slightly overstates it because the frame also pays caller-side memory expansion. A real deployment estimate requires an RPC and is out of scope here; deployment preparation must obtain one under a separately authorized task.

## Gas figures with illustrative USDC

**All USDC figures below are illustrative**, not live prices: they assume ETH = $2,000 and show 0.1 / 1 / 3 gwei, with `USDC = gas * gwei * 1e-9 * 2000`.

| Scenario | Osaka tx gas | @0.1 gwei | @1 gwei | @3 gwei |
| --- | ---: | ---: | ---: | ---: |
| Deployment (CREATE-frame only, not a full tx) | 750,414 | $0.150 | $1.501 | $4.502 |
| Deployment (full tx, local approximation) | 839,270 | $0.168 | $1.679 | $5.036 |
| distribute 1 | 94,140 | $0.019 | $0.188 | $0.565 |
| distribute 100 | 4,830,399 | $0.966 | $9.661 | $28.982 |
| distribute 150 | 7,222,449 | $1.444 | $14.445 | $43.335 |
| distribute 200 (max) | 9,614,499 | $1.923 | $19.229 | $57.687 |
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
| duplicate at final index of 200 (revert) | 9,547,609 | $1.910 | $19.095 | $57.286 |
| token contract at final index of 200 (revert) | 9,547,382 | $1.909 | $19.095 | $57.284 |
| zero at final index of 200 (revert) | 9,547,102 | $1.909 | $19.094 | $57.283 |

The Osaka calldata floor dominates the oversized and cap-overflow rejections, which revert before iterating. The three late rejections cost almost as much as a full successful batch because they revert only at the final recipient, and they sit within 507 gas of each other — the token-contract check is the same cost class as the zero and duplicate checks it sits between.

Incremental cost per recipient: 47,841 Osaka gas ($0.0096 at 0.1 gwei, $0.096 at 1 gwei, $0.287 at 3 gwei).

Campaign totals, **distribution only — deployment is excluded** because no live deployment estimate exists (operational batch size 100):

| Recipients | Batches | Osaka gas | @0.1 gwei | @1 gwei | @3 gwei |
| ---: | --- | ---: | ---: | ---: | ---: |
| 100 | 1x100 | 4,830,399 | $0.97 | $9.66 | $28.98 |
| 250 | 100+100+50 | 12,099,147 | $2.42 | $24.20 | $72.59 |
| 500 | 5x100 | 24,151,995 | $4.83 | $48.30 | $144.91 |
| 1,000 | 10x100 | 48,303,990 | $9.66 | $96.61 | $289.82 |

Add deployment separately using the deployment table above, remembering that its full-transaction figure is a local approximation and not a live-chain estimate.

## Gas method

`test/gas/MigrateRepV2TokenGas.t.sol` measures optimized calls in isolation with fresh contracts and cold state. Execution gas is the call-frame gas from `vm.lastCallGas().gasTotalUsed`; calldata gas is computed from the encoded calldata (4 per zero byte, 16 per nonzero byte); the Osaka transaction gas applies the floor formula above. Successful distribution recipients are generated with every address byte forced nonzero for the worst case, and the generator explicitly excludes `address(0)`, the token under measurement, and duplicates rather than relying on hash collisions being unlikely.

Deployment is reported as separate components (see above), never as one number: the CREATE-frame figure is measured, the intrinsic and initcode calldata gas are computed, and only their combination is presented — labelled as a local approximation. `forge test --gas-report` remains diagnostic only. Reproduce with `make gas`.

## ABI, storage, and diagnostics

The callable surface is exactly the nine standard ERC-20 functions plus `TOKEN_PER_RECIPIENT`, `MAX_BATCH_SIZE`, `distributor`, `recipientCap`, `maximumSupply`, `totalInitialRecipients`, `distributionFinalized`, `wasInitialRecipient`, `distribute`, and `finalizeDistribution`. `make consistency` and manual inspection confirm no `mint`, `burn`, `owner`, `transferOwnership`, `grantRole`, `pause`, `blacklist`, `setFee`, `enableTrading`, `permit`, `delegate`, `claim`, `redeem`, `upgradeTo`, `withdraw`, `recoverToken`, `transferAndCall`, or `approveAndCall` selector.

Storage (slots 0-4 are OpenZeppelin ERC-20): `totalInitialRecipients` (slot 5), `distributionFinalized` (slot 6), `wasInitialRecipient` (slot 7). Immutables (`distributor`, `recipientCap`, `maximumSupply`) and constants occupy no mutable storage.

Events: standard `Transfer` and `Approval`, plus `DistributionFinalized(address,uint256,uint256)` whose third field is `contractBalanceAtFinalization` — the token contract's complete balance at finalization, not a mathematically exact undistributed allocation; parameter types, indexed fields, and the event topic are unchanged. Errors: twelve project custom errors plus the six inherited `IERC20Errors`, none wrapped or duplicated.

Against the previous revision, the only ABI changes are the two added project-specific custom errors, `TokenContractDistributor()` and `TokenContractRecipient(uint256)`. No function was added, removed, or changed; method identifiers are unchanged; the storage layout is unchanged; and the events are unchanged.

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

- No formal audit or independent human release review has occurred. Passing tests and a clean Slither run are not an audit and do not prove that vulnerabilities are absent. The candidate is not approved for mainnet until an independent Solidity reviewer has inspected the final production source, the OpenZeppelin pin, the fixed-supply model, distributor authority, recipient-cap accounting, self-recipient and self-distributor rejection, returned-token accounting, finalization, the ABI, the storage layout, the deployment constructor arguments, and the final recipient manifest and provenance. No such review evidence exists.
- Gas figures are local measurements, not target-chain observations. No deployment figure here is a live-chain estimate: the full-transaction figure is a documented local approximation, and deployment preparation must obtain a real estimate and reconfirm execution, calldata, and transaction-tool behavior against approved chain conditions.
- Recipient eligibility policy remains an unresolved human gate: source chains and contracts, snapshot block and hash, migrated-address treatment, dust threshold, treatment of exchanges, custodians, bridges, escrow, wrappers, liquidity and protocol contracts, smart wallets, burn addresses, and project-controlled contracts, deduplication across sources, manual-review requirements, and final inclusion/exclusion approval are all unapproved. The numeric `recipientCap` and the production distributor follow from that policy and are likewise unapproved.
- Manifest provenance is validated, never verified: the tooling checks that a chain ID, snapshot block, block hash, source contracts, and ruleset checksums are present and well-formed. It cannot confirm they describe a real snapshot; only the human who produced them can.
- The invariant campaign reconciles a fixed 8-actor pool plus the token contract at cap 20. It is evidence about that model, not a proof over all reachable states.
- No fork, RPC, wallet, deployment, source-verification, or live-chain rehearsal was performed.
- Automatic wallet display and third-party reputation labels are not guaranteed.
