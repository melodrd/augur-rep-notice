# CHECK AUGUR MIGRATION (CHECKAUGUR)

CHECK AUGUR MIGRATION (CHECKAUGUR) is a fixed-supply ERC-20 **notice token**. One token is distributed to each selected address. CHECKAUGUR does **not** perform REP migration or grant any claim, redemption, governance, or financial right. It is not REP, REPv2, a migration claim, migration eligibility, or a project-supported investment asset.

It is a conventional ERC-20 with no owner, roles, taxes, blacklist, pause, upgradeability, holder burn, or post-deployment minting. The authoritative behavioral contract is [docs/SPEC.md](docs/SPEC.md).

## If you received CHECKAUGUR

Receiving it **requires no action** — no wallet connection, approval, swap, bridge, claim, or payment. Do not approve, transfer, swap, bridge, claim, deposit, sign, or connect a wallet because of it. Reach any website by navigating there yourself, never by following a link from a token, message, or search result. Any market price is third-party and implies no project endorsement.

A specific deployment is identified only by its verified, checksummed contract address and that address's on-chain source verification — never by matching name, symbol, logo, or price.

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

## Repository map

| Path | Contents |
| --- | --- |
| `src/MigrateRepV2Token.sol` | The production ERC-20 contract |
| `script/DeployMigrateRepV2Token.s.sol` | Deployment script (embeds no account, key, RPC, or network) |
| `test/` | Unit, fuzz, invariant, gas, and deploy-script suites |
| `ops/` | Offline recipient tooling: manifest and distribution-plan CLI |
| [docs/SPEC.md](docs/SPEC.md) | Authoritative contract behavior |
| [docs/OPERATIONS.md](docs/OPERATIONS.md) | Mainnet operator guide: deploy, distribute, finalize |

## Build and test

```bash
git submodule update --init --recursive
cd ops && bun install --frozen-lockfile && bun run check && cd ..

make check        # fmt-check, lint, build+sizes, ordinary tests, ops-check, Slither, consistency
make check-deep   # deep fuzz/invariant profile, once
make coverage     # production coverage
make gas          # isolated gas measurements
```

The canonical build uses Solidity 0.8.36, EVM Osaka, optimizer enabled at 200 runs, via-IR disabled, and pinned OpenZeppelin Contracts v5.6.1.

Passing tests make the code ready, not the release. On the pinned toolchain the suites pass with 100% production-code coverage, the deep fuzz/invariant profile reverts zero times, and Slither reports no findings. **This is evidence about tested behavior, not an audit.** No production deployment exists, and no task in this repository authorizes RPC access, key handling, signing, verification, or broadcast. The mainnet release is gated on an independent review of the final source, dependency pin, and recipient manifest — see [docs/OPERATIONS.md](docs/OPERATIONS.md).
