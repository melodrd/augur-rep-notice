# Mainnet Operator Guide

The whole path from an approved recipient list to a finalized distribution of `MigrateRepV2Token` (CHECKAUGUR) on **Ethereum mainnet**, as copy-paste commands with the rationale and stop conditions inline. Contract behavior is defined in [SPEC.md](SPEC.md); this guide is authoritative for how it is deployed and operated.

Two rules override everything below:

1. **A human signs every transaction.** The repository tooling is offline: it never holds a key, reaches the network, or broadcasts. Signing and broadcasting happen under a separate, explicitly approved human task.
2. **Immutable values are permanent.** A wrong `distributor`, `recipientCap`, chain, or token address cannot be edited — the only fix is discarding the deployment and redoing it.

When anything fails to match an approved value, **stop**; do not work around it. This guide assumes familiarity with Ethereum, Foundry, RPC endpoints, contract verification, and hardware-wallet or multisig signing.

## Release readiness

Code readiness (the contract and tooling satisfy their specification, with passing tests and a clean Slither run) is separate from release readiness. Before any mainnet transaction is prepared, every item must hold:

- source frozen at a reviewed commit with a clean working tree, and `make check`, `make check-deep`, `make coverage`, and `make gas` passing on it;
- an **independent Solidity reviewer** has inspected the final source, the OpenZeppelin pin, the supply and distribution model, ABI, storage layout, constructor arguments, and the final manifest and provenance (passing tests are not an audit);
- a recipient manifest approved under [Recipient policy](#recipient-policy) below, with its exact derived `recipientCap`;
- the production `distributor` selected and confirmed to be neither the zero address nor the predicted token address;
- the deployment account funded and controlled by the project owner;
- compiler, EVM target, optimizer, and dependency pins reviewed against `foundry.toml` and `foundry.lock`;
- the target chain confirmed to be at or past the EVM version in `foundry.toml` (`osaka`).

## Setup

```bash
export MAINNET_RPC_URL="https://..."     # your mainnet endpoint (keep out of tracked files)
export ETHERSCAN_API_KEY="..."           # explorer verification key
export ACCOUNT="mrep2-deployer"          # a Foundry keystore account name
```

`MAINNET_RPC_URL` and `ETHERSCAN_API_KEY` are secret-adjacent: keep them in the shell or a git-ignored `.env`, never in a tracked file. No private key, mnemonic, or keystore password is ever placed in the environment — signing is supplied through Foundry's keystore. Import the signing key once (entered at a hidden prompt, never on the command line):

```bash
cast wallet import "$ACCOUNT" --interactive
cast chain-id --rpc-url "$MAINNET_RPC_URL"     # must print 1 before anything else
```

## 0 · Freeze the build

```bash
forge clean && forge build
git rev-parse HEAD          # record this commit; the plan binds to it later
make check                  # gate: fmt, lint, tests, ops-check, Slither, consistency
```

Optionally record the build identity. Every bytecode hash here is taken over the **raw decoded bytes**, not the printed hex string (`cut -c3-` strips `0x`, `xxd -r -p` decodes to bytes); hashing the hex text yields a different, non-comparable digest.

```bash
forge inspect MigrateRepV2Token bytecode | cut -c3- | xxd -r -p | sha256sum   # creation bytecode; stable build id
```

## Recipient policy

Recipient selection is a **human policy decision**, not a repository decision, and no tool makes it. This repository validates, normalizes, checksums, and packages an approved list; approving the eligibility policy that produces it is the project owner's alone. Taking every address from an explorer holder list is not an approved methodology — a holder snapshot silently mixes exchanges, bridges, contracts, and dust, records no rules, and cannot be reproduced.

Each of the following must be settled and recorded in writing before any manifest is production data. None of the address classes (EOAs, smart wallets, exchanges, custodians, bridges, escrow, wrappers, protocol contracts, dead addresses) is automatically valid or invalid — each needs a recorded decision with a reason. Do **not** resolve this on-chain with a `code.length` filter: a contract recipient may be legitimate, and bytecode presence does not identify who controls an address. The contract rejects only the zero address and the token contract itself.

```text
source chain(s) and REP/REPv2 contract addresses
snapshot block number and hash
whether already-migrated addresses are included
minimum balance / dust threshold
treatment of exchanges, custodians, bridges, escrow, wrappers, protocol contracts
treatment of smart wallets, multisignatures, burn/dead addresses, project-controlled contracts
deduplication across sources
manual-review requirements
final inclusion and exclusion approval
```

Retain, per decision: the address, its raw source balance (integer base units), a stable reason code, and a source reference — no personal information.

## 1 · Provenance — record how the list was chosen

Fill [../data/snapshots/approved-provenance.json](../data/snapshots/approved-provenance.json), replacing every `REPLACE_...` placeholder. The tool checks *shape*, not truth — only you can attest the snapshot is real.

```bash
cast block <SNAPSHOT_BLOCK_NUMBER> -f hash --rpc-url "$MAINNET_RPC_URL"                  # snapshotBlockHash
printf 'sha256:%s\n' "$(sha256sum <frozen-snapshot-export> | cut -d' ' -f1)"             # sourceDataSha256
printf 'sha256:%s\n' "$(sha256sum <ruleset-file> | cut -d' ' -f1)"                       # rulesetSha256
```

`provenance.sourceChainId` (where the snapshot was read) is intentionally independent of the plan's `targetChainId` (where CHECKAUGUR is deployed) — a mainnet snapshot may drive a Sepolia rehearsal, so the two are never required to match.

## 2 · Manifest — freeze the set and derive the cap

The manifest is the offline, human-approved recipient artifact: the exact set of addresses that will each receive one token, plus provenance. It is lean — it stores only authoritative inputs and derives the cap, supply, and batch split on demand. The contract never reads it; the only value that crosses into the contract is the derived cap, copied by hand into `MREP2_RECIPIENT_CAP`.

Put the addresses in `data/snapshots/approved-recipients.json` (a JSON array, or `{ "recipients": [...] }`), then:

```bash
cd ops && bun run ops -- manifest \
  --recipients ../data/snapshots/approved-recipients.json \
  --provenance ../data/snapshots/approved-provenance.json \
  --batch-size 100 \
  --out-dir ../data/batches/candidate-1 && cd ..
```

This validates every address, rejects the zero address / duplicates / an empty list, normalizes to EIP-55, sorts ascending, and writes `manifest.json` + `manifest.json.sha256`. The cap is **derived** (it equals the unique recipient count; no cap can be supplied, so a manifest cannot carry undisclosed headroom). Regenerate from frozen inputs; never hand-edit a production manifest. The contract hard limit is 200 per call; use ~100 (≤150) for easier review.

**Record the printed `recipients (derived cap)` value** — that exact number becomes `MREP2_RECIPIENT_CAP`, never rounded up or given headroom.

```bash
export MREP2_RECIPIENT_CAP="<derived cap from the line above>"
```

## 3 · Deploy — one `CREATE`

The two constructor arguments (`MREP2_DISTRIBUTOR`, `MREP2_RECIPIENT_CAP`) are the only inputs the operator supplies; everything else is fixed by the source. The deploying account (`--account`) is a separate decision from `distributor`: they may be the same address but need not be, and deploying grants no distribution authority beyond what the constructor assigns.

```bash
export MREP2_DISTRIBUTOR="0x..."     # sole address that may distribute/finalize; immutable

# Simulate (no broadcast). --account must equal the broadcast account so the predicted
# CREATE address and nonce match what actually deploys. No key is used, nothing is sent.
forge script script/DeployMigrateRepV2Token.s.sol:DeployMigrateRepV2Token \
  --rpc-url "$MAINNET_RPC_URL" --account "$ACCOUNT" -vvvv

# Broadcast + verify. The key is supplied by the keystore, never on the CLI.
forge script script/DeployMigrateRepV2Token.s.sol:DeployMigrateRepV2Token \
  --rpc-url "$MAINNET_RPC_URL" --account "$ACCOUNT" --broadcast --verify
```

Confirm the logged `distributor`, `recipientCap`, and `maximumSupply` equal the approved values, then record the deployed address:

```bash
export TOKEN="0x..."     # the deployed token address
```

Verification uses compiler `0.8.36`, optimizer enabled at 200 runs, via-ir disabled, evm `osaka`, and constructor args `abi.encode(distributor, recipientCap)`. `--verify` submits these automatically when `ETHERSCAN_API_KEY` is set. Because the contract has immutables, the explorer's source verification (which reconstructs immutables from metadata) is the authoritative match; a raw `sha256` of on-chain runtime code will **not** equal the zeroed-immutable `deployedBytecode` artifact hash.

## 4 · Post-deploy checks — every value must match

Any mismatch is a stop condition; a wrong immutable means discard and redeploy.

```bash
cast call "$TOKEN" "name()(string)"                      --rpc-url "$MAINNET_RPC_URL"   # CHECK AUGUR MIGRATION
cast call "$TOKEN" "symbol()(string)"                    --rpc-url "$MAINNET_RPC_URL"   # CHECKAUGUR
cast call "$TOKEN" "decimals()(uint8)"                   --rpc-url "$MAINNET_RPC_URL"   # 18
cast call "$TOKEN" "distributor()(address)"              --rpc-url "$MAINNET_RPC_URL"   # approved distributor
cast call "$TOKEN" "recipientCap()(uint256)"             --rpc-url "$MAINNET_RPC_URL"   # approved cap
cast call "$TOKEN" "maximumSupply()(uint256)"            --rpc-url "$MAINNET_RPC_URL"   # cap * 1e18
cast call "$TOKEN" "totalSupply()(uint256)"              --rpc-url "$MAINNET_RPC_URL"   # == maximumSupply
cast call "$TOKEN" "balanceOf(address)(uint256)" "$TOKEN" --rpc-url "$MAINNET_RPC_URL"  # == maximumSupply
cast call "$TOKEN" "totalInitialRecipients()(uint256)"   --rpc-url "$MAINNET_RPC_URL"   # 0
cast call "$TOKEN" "distributionFinalized()(bool)"       --rpc-url "$MAINNET_RPC_URL"   # false
```

## 5 · Distribution plan — bind manifest to the deployed token

The token address does not exist when the snapshot is prepared, so the manifest cannot name it. The plan is the one deterministic step that binds an approved manifest to a deployed token, offline: it re-validates the manifest, verifies the manifest checksum, validates the target chain / token / source commit / runtime bytecode hash, rejects the plan if the token address appears in the recipient list, and encodes the exact `distribute(address[])` calldata per batch — then decodes each payload and asserts it equals the batch, so a mis-encoded payload never reaches a signer.

Compute the on-chain runtime bytecode hash over the raw bytes (not the printed hex string):

```bash
RT="sha256:$(cast code "$TOKEN" --rpc-url "$MAINNET_RPC_URL" | cut -c3- | xxd -r -p | sha256sum | cut -d' ' -f1)"

cd ops && bun run ops -- plan \
  --manifest ../data/batches/candidate-1/manifest.json \
  --manifest-sha256 ../data/batches/candidate-1/manifest.json.sha256 \
  --target-chain-id 1 \
  --token "$TOKEN" \
  --source-commit "$(git rev-parse HEAD)" \
  --runtime-bytecode-sha256 "$RT" \
  --output ../data/plans/candidate-1/plan.json && cd ..
```

The plan carries **no nonce, fee, or gas** by design — any such value produced offline would be a guess presented as authoritative; the signer supplies those from live chain state. It exists so a human can compare the exact decoded transaction against the approved batch before signing.

## 6 · Distribute — one batch at a time

On-chain state persists, so batches can be sent minutes or days apart: `totalInitialRecipients` accumulates and the cap is enforced across all calls. Distribute one batch, fully reconcile it, then prepare the next. Every transaction is sent by the **distributor** account and carries **zero value**; the project owner approves the sequence and signs every transaction.

```bash
N=1
CALLDATA=$(jq -r ".batches[] | select(.number==$N) | .calldata" data/plans/candidate-1/plan.json)

# Decode and eyeball: the recipients MUST equal the approved batch, in order.
cast decode-calldata "distribute(address[])" "$CALLDATA"

# Send the plan's exact bytes — pass the calldata verbatim, do not re-encode.
cast send "$TOKEN" --data "$CALLDATA" --rpc-url "$MAINNET_RPC_URL" --account "$ACCOUNT"
```

Reconcile before the next batch (any mismatch halts distribution): exact calldata and `Transfer` event order; `wasInitialRecipient == true` and a one-token balance for each distributed address; `totalInitialRecipients` equal to the cumulative unique recipients; unchanged `totalSupply`; and `totalInitialRecipients <= recipientCap`.

```bash
cast call "$TOKEN" "totalInitialRecipients()(uint256)"         --rpc-url "$MAINNET_RPC_URL"   # == sum of batch sizes sent
cast call "$TOKEN" "wasInitialRecipient(address)(bool)" <addr> --rpc-url "$MAINNET_RPC_URL"   # true
cast call "$TOKEN" "balanceOf(address)(uint256)"        <addr> --rpc-url "$MAINNET_RPC_URL"   # 1000000000000000000
cast call "$TOKEN" "totalSupply()(uint256)"                    --rpc-url "$MAINNET_RPC_URL"   # == maximumSupply
```

The remaining initial allocation, `(recipientCap - totalInitialRecipients) * 1e18`, is an off-chain projection — **not** a prediction of `balanceOf(token)`. Since CHECKAUGUR is transferable, a holder can send tokens back to the contract and push its live balance *above* that projection; a positive difference is not a defect. Record the transaction, block, nonce, and fee for each batch.

## 7 · Finalize — irreversible

Only after every batch is reconciled with no open incident and the owner's approval:

```bash
cast send "$TOKEN" "finalizeDistribution()" --rpc-url "$MAINNET_RPC_URL" --account "$ACCOUNT"

cast call "$TOKEN" "distributionFinalized()(bool)"     --rpc-url "$MAINNET_RPC_URL"   # true
cast call "$TOKEN" "totalInitialRecipients()(uint256)" --rpc-url "$MAINNET_RPC_URL"   # final count
```

Read the `DistributionFinalized` event's third field, `contractBalanceAtFinalization` (= `balanceOf(token)` at finalization), and record it against the computed remaining allocation. If the balance exceeds it, the difference is tokens transferred to the contract outside distribution — investigate and record it before finalizing; no rescue or withdrawal path exists.

**Implications — understand these before signing:**

- `distribute` reverts forever; the cap can never be topped up and no new initial recipient can be added.
- Any undistributed reserve stays **permanently locked** — no burn, sweep, rescue, or withdrawal path exists, and the same is true for tokens holders later transfer back.
- Ordinary `transfer`, `approve`, and `transferFrom` keep working unchanged, and `totalSupply` does not change.
- Finalizing **below** the cap is allowed but requires a written reason.
- Finalization is also the emergency brake: if the distributor key is compromised while you still control it, finalizing stops further wrong-recipient distribution within remaining cap — but it recovers no key, reverses no prior distribution, and moves no locked reserve.

## Stop conditions and incident handling

Halt, preserve evidence, and escalate to the responsible humans if any of the following holds. Do not work around an incident.

- A getter, decoded calldata, chain id, distributor, or cap does not match the approved value.
- `MREP2_RECIPIENT_CAP` is not exactly the manifest's derived count.
- The predicted or deployed token address appears anywhere in the recipient list.
- The distributor is the zero address or the token contract's own address.
- Simulation, deployment, verification, or any post-deployment getter does not match expectation.
- An unexplained transaction, event, address, nonce, or balance appears.
- Any action would expose a key, seed phrase, keystore, or secret.

| Incident | Immediate action |
| --- | --- |
| Wrong recipient list | Halt before signing. A wrong list already partly distributed cannot be reversed — record scope and escalate. |
| Wrong chain | Halt; a plan's `targetChainId` must match the deployment chain. Nothing signed on the wrong chain is valid distribution. |
| Wrong / compromised distributor | The distributor is immutable. A wrong one means discard and redeploy. On compromise, consider immediate `finalizeDistribution` while the owner retains control — it stops further wrong-recipient distribution but recovers no key and reverses nothing. |
| Incorrect calldata | Halt; the plan's decoded calldata must match the signing device byte for byte. Never sign calldata that does not decode to the approved batch. |
| Failed reconciliation | Halt before the next batch; never finalize with an unresolved discrepancy. |

Key loss can prevent distribution and finalization; compromise can cause wrong-recipient distribution within remaining cap or premature finalization. Neither creates an on-chain recovery path — none exists.

## Records

Retain, per deployment: the chain and contract address; deployment transaction, block, and deployer; source commit and build settings; constructor arguments and artifact hashes; distributor and cap; manifests, plans, and checksums; every calldata payload and transaction; event and counter reconciliations; finalization state; incident records; and confirmation that agents accessed no key and signed or broadcast nothing.

## Public communications (prepared, not published)

If explorer/wallet metadata or user messaging is prepared, a human publishes it under a separate task. Do not invent missing values — leave placeholders. Any package must state the exact name/symbol/decimals, the fixed supply with no post-deployment minting, the absence of taxes/blacklist/pause/owner/roles/upgradeability/project-supported liquidity, that the token performs no migration, and that receiving it requires no wallet connection, approval, swap, claim, bridge, or payment. Do not promise automatic wallet display, and do not describe testing or review as an audit.
