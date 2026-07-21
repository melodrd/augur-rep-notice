# CHECK AUGUR MIGRATION (CHECKAUGUR)

CHECK AUGUR MIGRATION (CHECKAUGUR) is a fixed-supply ERC-20 notice token. One token is distributed to each selected address. CHECKAUGUR does not perform REP migration or grant any claim, redemption, governance, or financial right.

Receiving CHECKAUGUR requires no action — no wallet connection, approval, swap, bridge, claim, or payment. It is a conventional ERC-20 with no owner, roles, taxes, blacklist, pause, upgradeability, holder burn, or post-deployment minting. The authoritative behavioral contract is [docs/SPEC.md](docs/SPEC.md).

## Contract model

- **One token per initial recipient.** The distributor sends exactly `1e18` base units (`TOKEN_PER_RECIPIENT`) to each selected address.
- **Fixed supply.** `maximumSupply = recipientCap * 1e18` is minted once, in the constructor, to the token contract itself. No function increases total supply afterward.
- **Reserve held by the contract.** The allocation leaves `address(this)` only through the distributor-only `distribute`. Anything left after finalization is permanently locked — never burned or swept.
- **Immutable distributor.** One `distributor`, fixed at construction, is the only address that may distribute or finalize. It may be neither the zero address nor the token contract itself.
- **Batched distribution.** `distribute(address[])` sends one token per new recipient in atomic batches of at most `MAX_BATCH_SIZE = 200`, rejecting the zero address, the token contract, and duplicates, until the cap is reached or distribution is finalized.
- **Irreversible finalization.** `finalizeDistribution` permanently closes distribution; ordinary `transfer`, `approve`, and `transferFrom` continue unchanged.

Because CHECKAUGUR is freely transferable, holders may send tokens back to the contract. Its live balance is therefore the remaining initial allocation *plus* any returned tokens; only the former is predictable off-chain, and no path recovers returned tokens.

| Property | Value |
| --- | --- |
| Name / symbol / decimals | `CHECK AUGUR MIGRATION` / `CHECKAUGUR` / `18` |
| Token per recipient | `1e18` base units (one token) |
| Maximum supply | `recipientCap * 1e18`, fixed at construction |

## Readiness

Passing tests make the code ready, not the release. These are distinct:

| Stage | Status |
| --- | --- |
| **Code readiness** — contract and tooling satisfy the specification and validation gates | Met at `3ae5d82` |
| **Recipient-policy readiness** — approved eligibility policy, frozen source data, approved manifest, exact derived cap | Not started |
| **Operational readiness** — selected production distributor and a successful rehearsal | Not started |
| **Mainnet readiness** — all of the above plus approved deployment parameters | Not met |

At `3ae5d82`, on the pinned toolchain, 122 Forge tests and 70 TypeScript tests pass, production coverage is 100% of lines, statements, branches, and functions, the deep fuzz/invariant profile passes with zero reverts, and Slither reports no findings. This is evidence about tested behavior, not an audit. No production deployment exists, and no task in this repository authorizes RPC access, key handling, signing, verification, or broadcast. Details are in [docs/VALIDATION.md](docs/VALIDATION.md).

## Documents

| Document | Contents |
| --- | --- |
| [docs/RUNBOOK.md](docs/RUNBOOK.md) | Mainnet operator runbook: copy-paste commands from approved list to finalization |
| [docs/SPEC.md](docs/SPEC.md) | Authoritative contract behavior |
| [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md) | Release procedure and post-deployment verification |
| [docs/OPERATIONS.md](docs/OPERATIONS.md) | Recipient policy, distribution, reconciliation, finalization |
| [docs/VALIDATION.md](docs/VALIDATION.md) | Reproducible local evidence |
| [docs/TESTS.md](docs/TESTS.md) | Test categories and what each protects |
| [docs/COMMUNICATIONS.md](docs/COMMUNICATIONS.md) | Explorer/wallet metadata and user messaging |

## Repository map

| Path | Contents |
| --- | --- |
| `src/MigrateRepV2Token.sol` | The production ERC-20 contract |
| `script/DeployMigrateRepV2Token.s.sol` | Deployment script (embeds no account, key, RPC, or network) |
| `test/` | Unit, fuzz, invariant, gas, and deploy-script suites |
| `ops/` | Offline recipient tooling: manifest and distribution-plan CLI |

## Commands

```bash
git submodule update --init --recursive
cd ops && bun install --frozen-lockfile && bun run check && cd ..

make check        # fmt-check, lint, build+sizes, ordinary tests, ops-check, Slither, consistency
make check-deep   # deep fuzz/invariant profile, once
make coverage     # production coverage
make gas          # isolated gas measurements
```

The canonical build uses Solidity 0.8.36, EVM Osaka, optimizer enabled at 200 runs, via-IR disabled, and pinned OpenZeppelin Contracts v5.6.1. Deployment and distribution procedures live in [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md) and [docs/OPERATIONS.md](docs/OPERATIONS.md); this README does not duplicate them. Operators running a mainnet release start at [docs/RUNBOOK.md](docs/RUNBOOK.md), the condensed copy-paste path that ties those two documents together.
