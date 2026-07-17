# Tests

How the suites are organized and what each one protects. Counts, campaign sizes, and results are in [VALIDATION.md](VALIDATION.md); the behavior under test is defined in [SPEC.md](SPEC.md).

## Categories

| Category | Location | Main behavior it protects |
| --- | --- | --- |
| Unit | `test/MigrateRepV2Token.t.sol` | Exact construction, metadata, and initial state; both validation precedences (constructor and per-recipient) with atomic rollback; rejection of the token contract as recipient and as distributor while ordinary contracts remain valid; cap-boundary and maximum-batch behavior; permanent binary history and duplicate prevention; unrestricted ERC-20 before and after finalization; the returned-token balance model; irreversible finalization. |
| Fuzz | `test/fuzz/` | Project-specific properties over random inputs — supply and accounting identities and per-recipient validation, and their interaction with the inherited ERC-20. OpenZeppelin's own internals are not re-fuzzed. |
| Invariant | `test/invariant/` | Stateful reconciliation over arbitrary sequences of distribute / transfer / approve / transferFrom / finalize: the full balance set, permanent history, distribution accounting, and post-finalization behavior hold, including holders returning tokens to the contract. Runs with `fail_on_revert = true`. |
| Deployment-script | `test/script/` | The deployment script sets exactly the intended constructor values, mints the whole supply to the token contract, leaves the deployer and distributor with no balance, exposes no administrative selector, and rejects a zero distributor or zero cap. |
| Gas | `test/gas/` | Worst-case call costs stay under the Osaka transaction gas cap, confirming `MAX_BATCH_SIZE` is measurement-derived. Kept isolated so its measurements never perturb the ordinary suite or coverage. |
| Operations-tooling | `ops/test/` | The offline recipient tooling: address validation and EIP-55 normalization, rejection of zero/duplicate/unsorted lists, the derived (never supplied) cap, provenance shape validation, independent source and target chains, exact `distribute(address[])` calldata encoding with round-trip decoding, refusal to place the token in its own recipient list, detached checksums, and no-clobber output. Pure and deterministic — no network, signing, or key access. |

## Running

```bash
make check        # normal gate: fmt-check, lint, build+sizes, ordinary tests (unit/fuzz/invariant/script), ops-check, Slither, consistency
make check-deep   # deep fuzz/invariant profile, once
make coverage     # production coverage (excludes the gas suite)
make gas          # isolated gas measurements
```

The normal and deep profiles differ only in campaign size (`foundry.toml`): the deep profile raises fuzz runs and invariant depth for release review. The operations-tooling suite also runs standalone with `cd ops && bun run check`.
