# Mainnet Runbook

The whole path from an approved recipient list to a finalized distribution on **Ethereum mainnet**, as copy-paste commands. This is a condensed happy-path guide over [DEPLOYMENT.md](DEPLOYMENT.md) and [OPERATIONS.md](OPERATIONS.md); those remain authoritative for edge cases, rationale, and every stop condition. Contract behavior is in [SPEC.md](SPEC.md).

Two rules override everything below. A human signs every transaction — the repository tooling is offline and never holds a key, reaches the network, or broadcasts. And a wrong `distributor`, `recipientCap`, chain, or token address is *immutable*: the only fix is discarding the deployment and redoing it. When anything fails to match, stop; do not work around it.

## Setup

```bash
export MAINNET_RPC_URL="https://..."     # your mainnet endpoint (keep out of tracked files)
export ETHERSCAN_API_KEY="..."           # explorer verification key
export ACCOUNT="mrep2-deployer"          # a Foundry keystore account name (see below)
```

Import the signing key once into an encrypted keystore — the key is entered at a hidden prompt, never on the command line, never in an env var:

```bash
cast wallet import "$ACCOUNT" --interactive
```

Confirm you are pointed at mainnet before anything else:

```bash
cast chain-id --rpc-url "$MAINNET_RPC_URL"     # must print 1
```

## 0 · Freeze the build

```bash
forge clean && forge build
git rev-parse HEAD          # record this commit; the plan binds to it later
make check                  # gate: fmt, lint, tests, ops-check, Slither
```

## 1 · Provenance — record how the list was chosen

Recipient selection is a human policy decision, not a tool's ([OPERATIONS.md](OPERATIONS.md#recipient-policy-is-a-human-decision)). Fill [data/snapshots/approved-provenance.json](../data/snapshots/approved-provenance.json), replacing every `REPLACE_...` placeholder. Compute the checksummed pieces from your frozen inputs:

```bash
# snapshotBlockHash — from the exact snapshot block you read balances at
cast block <SNAPSHOT_BLOCK_NUMBER> -f hash --rpc-url "$MAINNET_RPC_URL"

# sourceDataSha256 — binds the manifest to your frozen snapshot export
printf 'sha256:%s\n' "$(sha256sum <frozen-snapshot-export> | cut -d' ' -f1)"

# rulesetSha256 — binds it to your written eligibility ruleset
printf 'sha256:%s\n' "$(sha256sum <ruleset-file> | cut -d' ' -f1)"
```

`sourceChainId` is `1`, `snapshotBlockNumber` is that block as a string, and `sourceContracts` are the REP / REPv2 addresses already templated in the file. The tool checks *shape*, not truth — only you can attest the snapshot is real.

## 2 · Manifest — freeze the set and derive the cap

Put the addresses in `data/snapshots/approved-recipients.json` (a JSON array, or `{ "recipients": [...] }`), then:

```bash
cd ops && bun run ops -- manifest \
  --recipients ../data/snapshots/approved-recipients.json \
  --provenance ../data/snapshots/approved-provenance.json \
  --batch-size 100 \
  --out-dir ../data/batches/candidate-1 && cd ..
```

This validates every address, rejects the zero address / duplicates / an empty list, normalizes to EIP-55, sorts ascending, and writes `manifest.json` + `manifest.json.sha256`. **Record the printed `recipients (derived cap)` value** — that exact number becomes `MREP2_RECIPIENT_CAP`. Never round it up or add headroom.

```bash
export MREP2_RECIPIENT_CAP="<derived cap from the line above>"
```

## 3 · Deploy — one `CREATE`

```bash
export MREP2_DISTRIBUTOR="0x..."     # sole address that may distribute/finalize; immutable

# simulate (no broadcast). --account must equal the broadcast account so the
# predicted CREATE address and nonce match what actually deploys.
forge script script/DeployMigrateRepV2Token.s.sol:DeployMigrateRepV2Token \
  --rpc-url "$MAINNET_RPC_URL" --account "$ACCOUNT" -vvvv

# broadcast + verify. The key is supplied by the keystore, never on the CLI.
forge script script/DeployMigrateRepV2Token.s.sol:DeployMigrateRepV2Token \
  --rpc-url "$MAINNET_RPC_URL" --account "$ACCOUNT" --broadcast --verify
```

Confirm the logged `distributor`, `recipientCap`, and `maximumSupply` equal the approved values. Record the deployed address:

```bash
export TOKEN="0x..."     # the deployed token address
```

The deploying account and the `distributor` are separate roles — they may be the same address but need not be, and deploying grants no distribution authority beyond what the constructor assigns.

## 4 · Post-deploy checks — every value must match

```bash
cast call "$TOKEN" "name()(string)"                     --rpc-url "$MAINNET_RPC_URL"   # CHECK AUGUR MIGRATION
cast call "$TOKEN" "symbol()(string)"                   --rpc-url "$MAINNET_RPC_URL"   # CHECKAUGUR
cast call "$TOKEN" "decimals()(uint8)"                  --rpc-url "$MAINNET_RPC_URL"   # 18
cast call "$TOKEN" "distributor()(address)"             --rpc-url "$MAINNET_RPC_URL"   # approved distributor
cast call "$TOKEN" "recipientCap()(uint256)"            --rpc-url "$MAINNET_RPC_URL"   # approved cap
cast call "$TOKEN" "maximumSupply()(uint256)"           --rpc-url "$MAINNET_RPC_URL"   # cap * 1e18
cast call "$TOKEN" "totalSupply()(uint256)"             --rpc-url "$MAINNET_RPC_URL"   # == maximumSupply
cast call "$TOKEN" "balanceOf(address)(uint256)" "$TOKEN" --rpc-url "$MAINNET_RPC_URL" # == maximumSupply
cast call "$TOKEN" "totalInitialRecipients()(uint256)"  --rpc-url "$MAINNET_RPC_URL"   # 0
cast call "$TOKEN" "distributionFinalized()(bool)"      --rpc-url "$MAINNET_RPC_URL"   # false
```

Any mismatch is a stop condition. Immutables cannot be edited — a wrong one means discard and redeploy.

## 5 · Distribution plan — bind manifest to the deployed token

Compute the on-chain runtime bytecode hash (raw bytes, not the printed hex string):

```bash
RT="sha256:$(cast code "$TOKEN" --rpc-url "$MAINNET_RPC_URL" | cut -c3- | xxd -r -p | sha256sum | cut -d' ' -f1)"
echo "$RT"
```

```bash
cd ops && bun run ops -- plan \
  --manifest ../data/batches/candidate-1/manifest.json \
  --manifest-sha256 ../data/batches/candidate-1/manifest.json.sha256 \
  --target-chain-id 1 \
  --token "$TOKEN" \
  --source-commit "$(git rev-parse HEAD)" \
  --runtime-bytecode-sha256 "$RT" \
  --output ../data/plans/candidate-1/plan.json && cd ..
```

The plan re-validates the manifest, rejects the token address appearing in the recipient list, and emits per-batch pre-encoded `distribute(address[])` calldata. It carries **no nonce, fee, or gas** by design — the signer supplies those from live chain state.

## 6 · Distribute — one batch at a time, on separate occasions

On-chain state persists, so batches can be sent minutes or days apart: `totalInitialRecipients` accumulates and the cap is enforced across all calls. Distribute one batch, fully reconcile it, then prepare the next. Every transaction is sent by the **distributor** account and carries **zero value**.

For each batch — set `N` to the batch number:

```bash
N=1
CALLDATA=$(jq -r ".batches[] | select(.number==$N) | .calldata" data/plans/candidate-1/plan.json)

# Decode and eyeball: the recipients MUST equal the approved batch, in order.
cast decode-calldata "distribute(address[])" "$CALLDATA"

# Send the plan's exact bytes — pass the calldata verbatim, do not re-encode.
cast send "$TOKEN" --data "$CALLDATA" \
  --rpc-url "$MAINNET_RPC_URL" --account "$ACCOUNT"
```

Reconcile before the next batch (any mismatch halts distribution):

```bash
# cumulative unique recipients so far == sum of batch sizes sent
cast call "$TOKEN" "totalInitialRecipients()(uint256)"        --rpc-url "$MAINNET_RPC_URL"
# a spot-checked recipient is recorded and holds exactly one token
cast call "$TOKEN" "wasInitialRecipient(address)(bool)" <addr> --rpc-url "$MAINNET_RPC_URL"   # true
cast call "$TOKEN" "balanceOf(address)(uint256)"        <addr> --rpc-url "$MAINNET_RPC_URL"   # 1000000000000000000
# supply never changes during distribution
cast call "$TOKEN" "totalSupply()(uint256)"                    --rpc-url "$MAINNET_RPC_URL"   # == maximumSupply
```

The remaining allocation is an off-chain projection, `(recipientCap - totalInitialRecipients) * 1e18` — **not** a prediction of `balanceOf(token)`. Since CHECKAUGUR is transferable, a holder can send tokens back to the contract and push its live balance *above* that projection; a positive difference is not a defect. Record the transaction, block, nonce, and fee for each batch.

## 7 · Finalize — irreversible

Only after every batch is reconciled with no open incident:

```bash
cast send "$TOKEN" "finalizeDistribution()" \
  --rpc-url "$MAINNET_RPC_URL" --account "$ACCOUNT"

cast call "$TOKEN" "distributionFinalized()(bool)"     --rpc-url "$MAINNET_RPC_URL"   # true
cast call "$TOKEN" "totalInitialRecipients()(uint256)" --rpc-url "$MAINNET_RPC_URL"   # final count
```

Read the `DistributionFinalized` event's third field, `contractBalanceAtFinalization` (= `balanceOf(token)` at finalization), and record it against the computed remaining allocation.

**Implications — understand these before signing:**

- `distribute` reverts forever; the cap can never be topped up and no new initial recipient can be added.
- Any undistributed reserve stays **permanently locked** in the token contract — there is no burn, sweep, rescue, or withdrawal path. The same is true for tokens holders later transfer back to the contract.
- Ordinary `transfer`, `approve`, and `transferFrom` keep working unchanged, and `totalSupply` does not change.
- Finalizing **below** the cap is allowed but requires a written reason.
- Finalization is also the emergency brake: if the distributor key is compromised while you still control it, finalizing stops further wrong-recipient distribution within the remaining cap — but it recovers no key, reverses no prior distribution, and moves no locked reserve.

## Stop conditions (any one → halt and escalate)

- A getter, decoded calldata, chain id, distributor, or cap does not match the approved value.
- `MREP2_RECIPIENT_CAP` is not exactly the manifest's derived count.
- The token address appears anywhere in the recipient list.
- An unexplained transaction, nonce, address, or balance appears.
- Calldata does not decode to the approved batch — never sign it.
- Any action would expose a key, seed phrase, keystore, or secret.

Full incident handling and records requirements are in [OPERATIONS.md](OPERATIONS.md#incident-handling).
