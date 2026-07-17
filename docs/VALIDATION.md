# Validation

Reproducible local evidence for `MigrateRepV2Token`, current as of 2026-07-17.

This is not an audit. Passing tests, full coverage, and a clean Slither run are diagnostics about tested behavior; they do not prove that vulnerabilities are absent. All figures come from the checked-in configuration and local toolchain; no RPC, wallet, key, or live chain was involved.

## Candidate

| Item | Value |
| --- | --- |
| Production-code commit | `3ae5d82325e1b08e991fbdccd439cb3736efca01` |
| Contract | `src/MigrateRepV2Token.sol` |
| Inheritance | OpenZeppelin `ERC20` only |
| Solidity / EVM | `0.8.36` / `osaka` |
| Optimizer / via-IR | enabled, 200 runs / disabled |
| OpenZeppelin Contracts | `v5.6.1` @ `5fd1781b1454fd1ef8e722282f86f9293cacf256` |
| forge-std | `v1.16.2` @ `bf647bd6046f2f7da30d0c2bf435e5c76a780c1b` |
| Forge / Slither / Bun | `1.7.1` / `0.11.5` / `1.3.14` |

The **production-code commit** above is the frozen source and tooling; the ABI, bytecode, and every figure in this document derive from it. Documentation, including this validation refresh, is committed separately on top of it and changes no Solidity, `ops/` code, ABI, or bytecode — so the source commit is the correct reference for what was tested, not the later documentation commit.

Compilation produced no Solidity diagnostics; `forge lint src script` reported no findings. The test catalogue is in [TESTS.md](TESTS.md).

## Build artifacts

| Artifact | SHA-256 |
| --- | --- |
| Creation bytecode | `41cae5bf9379de815b39c63671df5adee92151f5ab2ccb919c1e0e9078b43c31` |
| Runtime bytecode (immutables zeroed) | `78aa335e2c29dcf88bf1fe8d8ff2ba8ad960746b1400f744c9f19a3fa847ea39` |

Each hash is computed over the **raw decoded bytecode bytes**, not the printed hex string: `forge inspect <artifact> | cut -c3- | xxd -r -p | sha256sum`. Hashing the hex text instead yields a different, non-comparable digest. The runtime hash is over `forge inspect deployedBytecode`, which zeroes the three immutables; on-chain runtime code differs. The creation hash is constant and independent of constructor arguments.

## Tests

| Suite | Campaign | Result |
| --- | ---: | --- |
| Unit (`test/MigrateRepV2Token.t.sol`) | 82 tests | pass |
| Fuzz (`test/fuzz/`) | 8 properties × 128 runs | pass |
| Invariant (`test/invariant/`) | 9 invariants × 16 × 64 = 1,024 calls each | pass |
| Deploy script (`test/script/`) | 8 tests | pass |
| Gas (`test/gas/`) | 15 tests | pass |
| TypeScript (`ops/`) | 70 tests across 3 files | pass |

The ordinary Forge run is 4 suites, 107 tests; the gas suite adds 15, for 122 Forge tests in total. The unit tests lock exact construction, metadata, and initial state; both validation precedences (constructor and per-recipient) with atomic rollback; rejection of the token contract as recipient and distributor with ordinary contracts still accepted; success at the 200-recipient maximum and rejection at 201; cap-boundary behavior; permanent binary history and duplicate prevention; unrestricted ERC-20 behavior before and after finalization; the returned-token balance model; and irreversible finalization.

The invariant handler drives distribution, transfers, approvals, `transferFrom`, and finalization over a fixed 8-actor pool plus the token contract at cap 20, with zero reverts. Transfers may return tokens to `address(token)`; the invariants reconcile the returned-token model:

```text
contract balance  = maximumSupply - totalInitialRecipients * 1e18 + tokens returned
actor balance sum = totalInitialRecipients * 1e18 - tokens returned
```

The returned-token path is exercised, not vacuous: a probe asserting zero returns fails within two runs. `make check-deep` re-runs the campaign at fuzz 256 and invariant 32 × 128 = 4,096 calls each, again with zero reverts.

The `ops/` suite covers three offline modules and their CLI. Everything is pure and deterministic: no test opens a network connection, signs, or reads a key. It proves the cap is derived from the unique recipient count (no cap can be supplied), addresses are normalized and canonically sorted, malformed/zero/duplicate/unsorted lists are rejected, provenance shape is validated, source and target chains may differ, calldata decodes back to the exact recipients, the token address cannot appear in its own recipient list, detached checksums match the emitted bytes, and outputs never clobber without `--force`.

## Coverage

| Metric | `src/` |
| --- | ---: |
| Lines | 100.00% (45/45) |
| Statements | 100.00% (44/44) |
| Branches | 100.00% (14/14) |
| Functions | 100.00% (3/3) |

Reported for `src/` only, excluding the gas suite. The three counted functions are the constructor, `distribute`, and `finalizeDistribution`; inherited ERC-20 functions and getters are OpenZeppelin's.

## Static analysis

`slither .` analyzed 8 contracts with 101 detectors and reported **0 results**; nothing was suppressed. This is not an audit.

## ABI, storage, and gas

The callable surface is exactly the nine standard ERC-20 functions plus `TOKEN_PER_RECIPIENT`, `MAX_BATCH_SIZE`, `distributor`, `recipientCap`, `maximumSupply`, `totalInitialRecipients`, `distributionFinalized`, `wasInitialRecipient`, `distribute`, and `finalizeDistribution`. `make consistency` confirms no `mint`, `burn`, `owner`, `pause`, `blacklist`, `permit`, `upgradeTo`, `withdraw`, `recoverToken`, or similar administrative selector.

Events: `Transfer`, `Approval`, and `DistributionFinalized(address,uint256,uint256)` whose third field is `contractBalanceAtFinalization` — the token contract's complete balance at finalization, not a mathematically exact undistributed allocation. Errors: twelve project custom errors plus the six inherited `IERC20Errors`, none wrapped.

Storage (slots 0–4 are OpenZeppelin ERC-20): `totalInitialRecipients` (slot 5), `distributionFinalized` (slot 6), `wasInitialRecipient` (slot 7). Immutables and constants occupy no mutable storage.

`MAX_BATCH_SIZE = 200` is measurement-derived. Worst-case successful calls (all-nonzero address bytes, cold recipients), as Osaka transaction gas `21000 + max(calldata + execution, 10 * tokens)`:

| Recipients | Osaka tx gas | % of 16,777,216 cap |
| ---: | ---: | ---: |
| 100 | 4,830,399 | 28.8% |
| 150 | 7,222,449 | 43.1% |
| **200** | **9,614,499** | **57.3%** |

The 200-recipient worst case is 57.3% of the Osaka transaction cap, under the 70% target with margin; incremental cost is ~47,841 gas per recipient. Optimizer runs = 200 captures the transfer-path savings at a small deployment cost. Full gas figures are produced by `make gas`; runtime is 3,120 bytes (well under the 24,576 limit).

## Known limitations

- **No audit or independent human release review has occurred.** The candidate is not approved for mainnet until an independent reviewer has inspected the final source, the OpenZeppelin pin, the supply and distribution model, ABI, storage layout, constructor arguments, and the final manifest and provenance.
- **No live-chain rehearsal exists for this exact frozen candidate and lean v1 workflow.** No fork, RPC, wallet, deployment, or Sepolia rehearsal was performed against the `3ae5d82` build and the current manifest/plan tooling. Every gas figure here is local, not a target-chain observation.
- **Recipient policy remains a human gate.** Source chains and contracts, snapshot block and hash, migrated-address treatment, dust threshold, exchange/custodian/bridge/contract/burn-address treatment, deduplication, manual review, and final inclusion are unresolved. The numeric `recipientCap` and production distributor follow from that policy and are likewise unresolved.
- **Provenance is validated, never verified**: the tooling checks shape, not that the values describe a real snapshot.
- **Integrity is structural plus a detached hash, not a signature.** `parseManifest` rejects malformed, zero, non-canonical, unsorted, or duplicate recipients, and the detached checksums detect accidental edits; both are public and unkeyed and cannot detect an adaptive tamperer who regenerates a matching hash. Authenticity rests on the separately authorized human approval process.
- **The invariant campaign reconciles a fixed 8-actor pool plus the token contract at cap 20.** It is evidence about that model, not a proof over all reachable states.
- Automatic wallet display and third-party labels are not guaranteed.

## Reproduce

```bash
git submodule update --init --recursive
cd ops && bun install --frozen-lockfile && bun run check && cd ..
make check          # fmt-check, lint, build+sizes, ordinary tests, ops-check, Slither, consistency
make check-deep     # deep fuzz/invariant profile, once
make coverage       # production coverage
make gas            # isolated gas measurements

# Artifact hashes, over raw decoded bytes (not the printed hex string):
forge inspect MigrateRepV2Token bytecode         | cut -c3- | xxd -r -p | sha256sum
forge inspect MigrateRepV2Token deployedBytecode | cut -c3- | xxd -r -p | sha256sum

forge inspect MigrateRepV2Token abi
forge inspect MigrateRepV2Token methodIdentifiers
forge inspect MigrateRepV2Token storageLayout
forge inspect MigrateRepV2Token events
forge inspect MigrateRepV2Token errors
```
