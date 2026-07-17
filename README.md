# MIGRATE REPV2 (MREP2)

MIGRATE REPV2 (`MREP2`) is a transferable, fixed-supply ERC-20 notice token distributed to selected addresses. Each initial recipient receives one MREP2 token. MREP2 does **not** perform REP migration and is **not** REP, REPv2, a migration claim, migration eligibility proof, redemption right, governance right, reward, or a project-supported investment asset.

The token behaves like an ordinary ERC-20 at all times: unrestricted `transfer`, `approve`, `allowance`, and `transferFrom`, standard `Transfer`/`Approval` events, and standard OpenZeppelin errors. It has no owner or roles, no transfer restrictions, no taxes, no blacklist, no pause, no upgradeability, no holder burn, and no post-deployment minting.

## Naming-risk note

`MIGRATE REPV2` and `MREP2` could be read by users as an actual REPv2 asset or an instruction to migrate. They are neither. MREP2 is a notice token; receiving, transferring, or approving it performs no REP migration and grants no right or value. This is stated in the code, docs, and intended explorer metadata.

## Design

- **18 decimals.** One token equals `1e18` base units (`TOKEN_PER_RECIPIENT = 1 ether`).
- **Fixed supply.** The entire `recipientCap * 1e18` supply is minted once in the constructor and held by the token contract itself; there is no mint function afterward.
- **Allocation held by the contract.** The initial allocation leaves `address(this)` only through the distributor-only `distribute`. Anything left after finalization is permanently locked — never burned or swept.
- **Distributor-only distribution.** An immutable `distributor` sends exactly one token to each selected address, in atomic batches of at most `MAX_BATCH_SIZE = 200`. The distributor may be neither the zero address nor the token contract itself.
- **The token contract is not a recipient.** `distribute` rejects `address(this)`, which would otherwise self-transfer, consume cap, and record the contract as an initial recipient. Ordinary contract recipients — multisignatures, custody addresses, smart wallets — are fully supported; there is no bytecode filter.
- **Permanent history.** `wasInitialRecipient(address)` records that an address received a token directly from the contract. It never clears and is not a balance, current-holder, or eligibility claim.
- **Irreversible finalization.** `finalizeDistribution` permanently closes distribution; standard transfers, approvals, and `transferFrom` continue unchanged.

Because MREP2 is freely transferable, holders may send tokens back to `address(token)`. The token contract's live balance is therefore the **remaining initial allocation** `(recipientCap - totalInitialRecipients) * 1e18` **plus any returned tokens** — the two are distinct quantities and only the former is predictable off-chain. No path recovers returned tokens.

## Fixed metadata

| Property | Value |
| --- | --- |
| Name | `MIGRATE REPV2` |
| Symbol | `MREP2` |
| Decimals | `18` |
| Token per recipient | `1e18` base units (one token) |
| Maximum supply | `recipientCap * 1e18`, fixed at construction |

Only the checksummed deployed address published through official Augur sources can identify a canonical deployment. Matching metadata, source, price, or branding is not authentication.

## What it is not

MREP2 has no REP custody, approval, transfer, migration, claim, redemption, reward, or governance right; no holder or delegated burn; no owner, role, authority transfer, recovery, proxy, or upgrade; no payable path, withdrawal, token recovery, callback, hook, bridge, oracle, or arbitrary call; and no pricing, liquidity, tax, staking, yield, rebasing, or other economic behavior. Third parties can independently create markets; any such price does not imply project endorsement. Transferring or approving MREP2 does not migrate REP, and automatic wallet display is not guaranteed.

## Public interface

Standard ERC-20 surface: `name`, `symbol`, `decimals`, `totalSupply`, `balanceOf`, `transfer`, `allowance`, `approve`, `transferFrom`, with standard `Transfer`/`Approval` events and OpenZeppelin errors.

Project-specific surface:

| Member | Purpose |
| --- | --- |
| `TOKEN_PER_RECIPIENT()` | `1e18` — one token per initial recipient |
| `MAX_BATCH_SIZE()` | `200` — hard per-call recipient ceiling |
| `distributor()` | immutable address allowed to distribute and finalize |
| `recipientCap()` | immutable maximum number of unique initial recipients |
| `maximumSupply()` | immutable `recipientCap * 1e18` |
| `totalInitialRecipients()` | permanent count of initial recipients |
| `distributionFinalized()` | whether distribution is permanently closed |
| `wasInitialRecipient(address)` | permanent per-address distribution history |
| `distribute(address[])` | distributor-only atomic batch distribution |
| `finalizeDistribution()` | distributor-only irreversible close |

Distribution flow: deploy (whole supply minted to the contract) → distributor calls `distribute` in batches of ≤200, one token per new recipient → distributor calls `finalizeDistribution` once, permanently closing distribution while ordinary transfers continue.

## Repository layout

```text
src/MigrateRepV2Token.sol            production ERC-20
script/DeployMigrateRepV2Token.s.sol deployment script (embeds no account, key, RPC, or network)
test/                                unit, fuzz, invariant, gas, and deploy-script tests
ops/src/manifest.ts                  deterministic recipient manifest (derived cap, provenance)
ops/src/distribution-plan.ts         offline manifest-to-deployment binding and batch calldata
ops/src/cli.ts                       offline manifest command (bun run manifest)
ops/src/plan-cli.ts                  offline distribution-plan command (bun run plan)
docs/SPEC.md                         authoritative contract behavior
docs/OPERATIONS.md                   deployment, recipient, and communications controls
docs/VALIDATION.md                   current local evidence
```

The deployment script embeds no account, key, RPC, or network and does not broadcast unless a human explicitly invokes Forge with broadcasting enabled (it contains `vm.startBroadcast()`, which activates under `--broadcast`).

## Local commands

```bash
make check        # fmt-check, lint, build+sizes, ordinary tests, ops-check, Slither, consistency
make test         # ordinary Forge tests (excludes the isolated gas suite)
make gas          # isolated gas measurements
make coverage     # production coverage
make check-deep   # deep fuzz/invariant profile, once
```

The canonical build uses Solidity 0.8.36, EVM Osaka, optimizer enabled with 200 runs, via IR disabled, and pinned OpenZeppelin Contracts v5.6.1. The `MAX_BATCH_SIZE` of 200 is measurement-derived: its worst-case successful call uses about 9.61M gas, 57% of the Osaka transaction cap. See [docs/VALIDATION.md](docs/VALIDATION.md) for gas, coverage, and diagnostics.

## Recipient selection

Recipient eligibility is a human policy decision belonging to the project owner, not to this repository or its tooling. Taking every address from an explorer holder list is not an approved methodology. The source chains and contracts, snapshot block, dust threshold, and treatment of exchanges, custodians, bridges, contracts, smart wallets, and burn addresses are all unresolved and must be approved in writing. This repository validates, checksums, and packages an approved list; it never invents one. See [docs/OPERATIONS.md](docs/OPERATIONS.md).

Every manifest derives `recipientCap` from the final unique recipient list — the tooling accepts no cap, so a manifest cannot carry undisclosed headroom — and requires explicit snapshot and ruleset provenance.

## Status

The contract is implemented and locally validated. No production deployment exists, and recipient selection, the numeric `recipientCap`, the production distributor, and any live-chain rehearsal remain separate, human-approved stages. Local validation is evidence for tested paths; it is not an audit and does not prove that vulnerabilities are absent. The candidate is not approved for mainnet until an independent Solidity reviewer has inspected it. No task in this repository authorizes RPC access, key handling, signing, deployment, verification, or broadcast.
