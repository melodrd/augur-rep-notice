# Operator Guide

The full path from an approved recipient list to a finalized `MigrateRepV2Token` (CHECKAUGUR) distribution, as copy-paste commands. Contract behavior is defined in [SPEC.md](SPEC.md); this guide governs how it is deployed and operated.

**Two rules override everything here:**

1. **A human signs every transaction.** The repository tooling is offline — it never holds a key, reaches the network, or broadcasts.
2. **Immutable values are permanent.** A wrong `distributor`, `recipientCap`, chain, or token address cannot be edited — the only fix is to redeploy.

Before any **mainnet** deployment, an independent reviewer must inspect the final source, dependency pin, constructor arguments, and recipient manifest. Passing tests are not an audit. This guide assumes familiarity with Foundry, RPC endpoints, verification, and keystore/hardware-wallet signing.

## Before you sign anything

These are irreversible. Read them before the first transaction.

- **The supply is fixed at deploy and can never change.** `recipientCap × 1e18` is minted once, in the constructor, to the token contract itself. There is no mint, burn, owner, pause, or upgrade — nothing can alter the supply, the cap, or the rules afterward.
- **`distributor` and `recipientCap` are immutable.** Set in the constructor, never editable. A wrong value means you **discard the contract and redeploy** — there is no other fix.
- **Distribution is batched and one-way.** The distributor sends exactly one token to each address via `distribute(address[])`, in batches of at most 200 (use ~100). The on-chain recipient count accumulates across calls and stops at `recipientCap`. Tokens leave the contract only through `distribute`.
- **Finalizing is permanent.** `finalizeDistribution` closes distribution forever. Any tokens not yet sent are **locked permanently** — no recovery exists. **Send every batch first; finalize last.**

## How it works

- The whole supply is minted to the contract at deploy. The deployer and distributor receive nothing.
- Each address gets exactly one token, once. The zero address, the token's own address, and duplicates are rejected; a batch is atomic — any bad entry reverts the whole call.
- `wasInitialRecipient(addr)` records who received an initial token. It is history, not a balance or a claim.
- Ordinary ERC-20 `transfer` / `approve` / `transferFrom` work normally, before and after finalize. `totalSupply` never changes.
- Fixed forever at deploy: name `CHECK AUGUR MIGRATION`, symbol `CHECKAUGUR`, decimals `18`, supply, `distributor`, `recipientCap`.

## Networks

Same steps for both; only three values differ.

| | Mainnet | Sepolia rehearsal |
| --- | --- | --- |
| `RPC` | your mainnet endpoint | your Sepolia endpoint |
| `CHAIN_ID` | `1` | `11155111` |
| plan `--target-chain-id` | `1` | `11155111` |

A rehearsal still distributes the real mainnet snapshot, so `provenance.sourceChainId` stays `1`.

## Setup

```bash
export RPC="https://..."          # mainnet or Sepolia endpoint (keep out of tracked files)
export CHAIN_ID=1                 # 11155111 for a Sepolia rehearsal
export ETHERSCAN_API_KEY="..."    # verification key (optional on testnet)
export ACCOUNT="mrep2-deployer"   # a Foundry keystore account name

cast wallet import "$ACCOUNT" --interactive   # key entered at a hidden prompt, never on the CLI
cast chain-id --rpc-url "$RPC"                 # MUST print $CHAIN_ID
```

Signing is supplied only through Foundry's keystore (`--account`). No private key, mnemonic, or password ever goes in a file, env var, or command.

## Deploy and distribute

### 0 · Freeze the build

```bash
forge clean && forge build && make check     # gate: fmt, lint, tests, ops-check, Slither
git rev-parse HEAD                            # record this commit; the plan binds to it
```

### 1 · Provenance — how the list was chosen

Records where the list came from. The tool validates **shape, not truth**, so it is never hand-edited. Two files already in the repo are hashed into it:

- `data/snapshots/approved-recipients.json` — the frozen recipient export (becomes `sourceDataSha256`).
- `data/snapshots/ruleset.md` — the written inclusion rules (becomes `rulesetSha256`). **Fill in its `Snapshot block` line first** and make it equal `$BLOCK` below; otherwise the hash covers a placeholder.

The snapshot chain is always Ethereum mainnet (chainId `1`). On a mainnet deploy `SNAPSHOT_RPC` is just your `$RPC`; only in a Sepolia rehearsal do they differ (`$RPC` is Sepolia, `SNAPSHOT_RPC` stays a mainnet endpoint).

```bash
export SNAPSHOT_RPC="$RPC"     # mainnet deploy: same endpoint. Sepolia rehearsal: a separate mainnet endpoint.
BLOCK=<snapshot block number>  # the mainnet block the snapshot was taken at; must equal ruleset.md's "Snapshot block"

jq -n \
  --argjson sourceChainId 1 \
  --arg snapshotBlockNumber "$BLOCK" \
  --arg snapshotBlockHash   "$(cast block "$BLOCK" -f hash --rpc-url "$SNAPSHOT_RPC")" \
  --arg sourceDataSha256    "sha256:$(sha256sum data/snapshots/approved-recipients.json | cut -d' ' -f1)" \
  --arg rulesetId           "rep-notice-v1" \
  --arg rulesetSha256       "sha256:$(sha256sum data/snapshots/ruleset.md | cut -d' ' -f1)" \
  '{
    sourceChainId: $sourceChainId,
    snapshotBlockNumber: $snapshotBlockNumber,
    snapshotBlockHash: $snapshotBlockHash,
    sourceContracts: ["0x1985365e9f78359a9B6AD760e32412f4a445E862","0x221657776846890989a759BA2973e427DfF5C9bB"],
    sourceDataSha256: $sourceDataSha256,
    rulesetId: $rulesetId,
    rulesetSha256: $rulesetSha256
  }' > data/snapshots/approved-provenance.json
```

`sourceContracts` are the two Augur reputation-token contracts on mainnet — REP v1 `0x1985365e9f78359a9B6AD760e32412f4a445E862` and REPv2 `0x221657776846890989a759BA2973e427DfF5C9bB`, the same pair listed under **Source** in `ruleset.md`. They define what "REP holder" means; leave them unchanged for an Augur snapshot.

Each field is validated: `snapshotBlockNumber` a positive integer string, `snapshotBlockHash` `0x`+64 hex, the two `sha256:` fields `sha256:`+64 lowercase hex, `sourceContracts` non-empty and unique. `SNAPSHOT_RPC` is always a mainnet (chain `1`) endpoint — on a Sepolia rehearsal that means it is **not** `$RPC`.

### 2 · Manifest — freeze the set, derive the cap

```bash
cd ops && bun run ops -- manifest \
  --recipients ../data/snapshots/approved-recipients.json \
  --provenance ../data/snapshots/approved-provenance.json \
  --batch-size 100 --out-dir ../data/batches/candidate-1 && cd ..
```

Validates, dedupes, checksums, and sorts the list. **The cap is derived — it equals the unique recipient count and cannot be supplied.** Copy the printed value exactly, never rounded up:

```bash
export MREP2_RECIPIENT_CAP="<derived cap>"
```

### 3 · Deploy — one CREATE (and your gas estimate)

The two constructor args are the only inputs you supply. **Simulate first — it prints your gas and ETH cost.**

```bash
export MREP2_DISTRIBUTOR="0x..."     # sole address that may distribute/finalize; immutable

# Simulate: no broadcast, no key. Prints "Estimated amount required: X ETH".
forge script script/DeployMigrateRepV2Token.s.sol:DeployMigrateRepV2Token \
  --rpc-url "$RPC" --account "$ACCOUNT" -vvvv

# Broadcast + verify (key supplied by the keystore, never on the CLI):
forge script script/DeployMigrateRepV2Token.s.sol:DeployMigrateRepV2Token \
  --rpc-url "$RPC" --account "$ACCOUNT" --broadcast --verify

export TOKEN="0x..."     # deployed address from the logs
```

Confirm the logged `distributor`, `recipientCap`, and `maximumSupply` equal the approved values before continuing.

### 4 · Post-deploy checks — all must match

```bash
cast call "$TOKEN" "distributor()(address)"              --rpc-url "$RPC"   # approved distributor
cast call "$TOKEN" "recipientCap()(uint256)"             --rpc-url "$RPC"   # approved cap
cast call "$TOKEN" "totalSupply()(uint256)"              --rpc-url "$RPC"   # cap * 1e18
cast call "$TOKEN" "balanceOf(address)(uint256)" "$TOKEN" --rpc-url "$RPC"  # == totalSupply
cast call "$TOKEN" "totalInitialRecipients()(uint256)"   --rpc-url "$RPC"   # 0
cast call "$TOKEN" "distributionFinalized()(bool)"       --rpc-url "$RPC"   # false
```

Also confirm `name` / `symbol` / `decimals` are `CHECK AUGUR MIGRATION` / `CHECKAUGUR` / `18`. Any mismatch on an immutable ⇒ discard and redeploy.

### 5 · Plan — bind the manifest to the deployed token

Offline: re-validates the manifest, rejects the token from its own recipient list, and encodes the exact `distribute` calldata per batch (then decodes it to confirm it matches).

```bash
RT="sha256:$(cast code "$TOKEN" --rpc-url "$RPC" | cut -c3- | xxd -r -p | sha256sum | cut -d' ' -f1)"

cd ops && bun run ops -- plan \
  --manifest ../data/batches/candidate-1/manifest.json \
  --manifest-sha256 ../data/batches/candidate-1/manifest.json.sha256 \
  --target-chain-id "$CHAIN_ID" --token "$TOKEN" \
  --source-commit "$(git rev-parse HEAD)" --runtime-bytecode-sha256 "$RT" \
  --output ../data/plans/candidate-1/plan.json && cd ..
```

### 6 · Distribute — every batch, one at a time

Run for `N` = 1, 2, … through the last batch. Send one, reconcile, then the next.

```bash
N=1     # ← increment each round
CALLDATA=$(jq -r ".batches[] | select(.number==$N) | .calldata" data/plans/candidate-1/plan.json)

# Estimate this batch's gas (read-only, sends nothing):
GAS_HEX=$(cast rpc eth_estimateGas \
  "{\"from\":\"$MREP2_DISTRIBUTOR\",\"to\":\"$TOKEN\",\"data\":\"$CALLDATA\"}" --rpc-url "$RPC" | tr -d '"')
cast to-dec "$GAS_HEX"

# Eyeball, then send the plan's exact bytes (do not re-encode):
cast decode-calldata "distribute(address[])" "$CALLDATA"     # MUST equal batch N, in order
cast send "$TOKEN" --data "$CALLDATA" --rpc-url "$RPC" --account "$ACCOUNT"

# Reconcile before the next batch:
cast call "$TOKEN" "totalInitialRecipients()(uint256)" --rpc-url "$RPC"   # cumulative; must reach recipientCap
```

Spot-check a recipient after sending: `wasInitialRecipient(addr)` is `true` and `balanceOf(addr)` is `1000000000000000000`. `totalSupply` stays constant.

### 7 · Finalize — only at the cap

> **STOP.** Finalize only when `totalInitialRecipients == recipientCap` (every batch sent and reconciled), or on a **written decision** to finalize early. Finalizing before all batches are sent **locks every remaining token forever** — `distribute` reverts permanently and no recovery exists. This is the single most common irreversible mistake.

```bash
cast call "$TOKEN" "totalInitialRecipients()(uint256)" --rpc-url "$RPC"   # confirm == recipientCap FIRST
cast send "$TOKEN" "finalizeDistribution()" --rpc-url "$RPC" --account "$ACCOUNT"
cast call "$TOKEN" "distributionFinalized()(bool)" --rpc-url "$RPC"       # true
```

## Gas

Measured on this contract (Sepolia, ~1.1 gwei). Cost scales linearly with gas price.

| Action | Gas | |
| --- | --- | --- |
| Deploy | ~840k | one-time |
| `distribute`, 100 recipients | ~4.9M | per full batch |
| `distribute`, 35 recipients | ~1.7M | partial batch |
| `finalizeDistribution` | ~50k | one-time |
| **500 recipients, 5 batches** | **~25.0M total** | end to end |

The end-to-end figure is one deploy, five full `distribute(100)` batches, and one finalize (`~840k + 5 × ~4.9M + ~50k`). A run whose last batch is partial substitutes the partial-batch row for one full batch.

**How to estimate before signing:** the **deploy** simulation (step 3, no `--broadcast`) prints the ETH cost; a **batch** uses the `eth_estimateGas` one-liner in step 6. Both read live chain state — these are the figures to fund against.

Cost is linear in gas price: the full ~25.0M-gas run costs **~0.025 ETH per gwei** of gas price, so multiply by whatever price the chain is quoting. As of 2026-07-21 mainnet gas was ~0.17 gwei with ETH ~$1,930, which puts the whole run at **~0.0043 ETH (~$8)**. Gas price is a volatile network property, independent of the ETH/USD price, and rises during congestion — size funding to the highest price you're willing to sign at, and confirm against the live `eth_estimateGas` reading at broadcast time.

## If something is wrong — stop

Halt and escalate; never work around it.

- Any getter, decoded calldata, chain id, distributor, or cap ≠ the approved value.
- `MREP2_RECIPIENT_CAP` ≠ the manifest's derived count.
- The token address appears anywhere in the recipient list.
- Distribution was finalized before all batches were sent → the contract is spent; **redeploy and start over.**
- An unexplained transaction, event, or balance appears, or any action would expose a key or secret.

A wrong immutable (`distributor`, `recipientCap`) or a premature finalize is unrecoverable on-chain: **discard the contract and redeploy.**

## Recipient policy & records

The recipient list is a **project-owner decision made before deployment** — approved in writing (source chain and contracts, snapshot block, inclusion/exclusion rules, dedup, minimum balance). Do not scrape an explorer holder list; no address class is automatically valid or invalid, and bytecode presence is never a filter. Retain per deployment: the chain and contract address; deploy tx, block, and deployer; source commit and build settings; constructor args; distributor and cap; manifest and plan checksums; every calldata and transaction; and the finalization state.
