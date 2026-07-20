# Operations

Recipient preparation, distribution, reconciliation, and finalization for `MigrateRepV2Token` (CHECKAUGUR). Contract behavior is in [SPEC.md](SPEC.md); deployment is in [DEPLOYMENT.md](DEPLOYMENT.md); public messaging is in [COMMUNICATIONS.md](COMMUNICATIONS.md).

No step here authorizes RPC access, key handling, signing, or broadcast. Those require a separately approved human task. The tooling in `ops/` is offline: it validates and packages an approved recipient list and never signs, broadcasts, or reaches the network.

Code readiness (the contract and tooling satisfy their specification) is separate from release readiness. Distribution is release work: it requires an approved recipient policy, a frozen manifest, a deployed and verified token, and human sign-off at every batch.

## Recipient policy is a human decision

Recipient selection is not a repository decision, and no tool makes it. This repository validates, normalizes, checksums, and packages an approved list; approving the eligibility policy that produces that list is the project owner's decision alone.

Taking every address from an explorer holder list is not an approved methodology: a holder list is an unattributed snapshot of one contract at one moment that silently mixes exchanges, bridges, contracts, and dust, records no rules, and cannot be reproduced.

The following must each be settled and recorded in writing before any manifest is production data:

```text
source chain or chains
source REP/REPv2 contract addresses
snapshot block number and hash
whether already-migrated addresses are included
minimum balance / dust threshold
treatment of exchanges and custodians
treatment of bridges, escrow, wrappers, and protocol contracts
treatment of smart wallets and multisignatures
treatment of burn / dead addresses
treatment of known project-controlled contracts
deduplication across sources
manual-review requirements
final inclusion and exclusion approval
```

None of these address classes — EOAs, Safe and other smart wallets, exchange wallets, custodians, bridges, escrow, wrappers, liquidity or protocol contracts, dead addresses, or contracts holding REP for multiple users — is automatically valid or invalid. Each needs a recorded decision with a reason. Do not resolve this on-chain with a `code.length` filter: a contract recipient may be entirely legitimate, and bytecode presence does not identify who controls an address. The contract rejects only the zero address and the token contract itself.

The selection process must produce and retain: included, excluded, and manual-review addresses; a stable reason code for every exclusion or manual-review decision; the source balance in raw integer units; a source reference for each decision; the final unique included count; and checksums of every frozen input and output. Store no personal information — an address, a raw balance, a reason code, and a source reference are sufficient.

## Manifest

The manifest is the offline, human-approved recipient artifact: the exact set of addresses that will each receive one CHECKAUGUR token, plus the provenance of how that set was chosen. The contract never reads it; the only value that crosses into the contract is the derived cap, copied by hand into `MREP2_RECIPIENT_CAP`.

It is lean — it stores only authoritative inputs (version, provenance, batch size, canonical recipient list) and derives everything else (cap, maximum supply, batch split, counts) on demand. The format is version 1 with no migration path.

```json
{
  "version": 1,
  "provenance": {
    "sourceChainId": 1,
    "snapshotBlockNumber": "12345678",
    "snapshotBlockHash": "0x...",
    "sourceContracts": ["0x..."],
    "sourceDataSha256": "sha256:...",
    "rulesetId": "rep-notice-v1",
    "rulesetSha256": "sha256:..."
  },
  "batchSize": 100,
  "recipients": [
    "0x3A1F8B0D9c2e4a7F6B5D8C9E0a1B2C3d4e5F6A7B",
    "0x8C4d2e1f0a9b7c6D5E4f3A2b1c0d9e8F7a6b5C4d",
    "0xD9e0f1A2B3c4d5e6f708192A3B4C5d6e7f809A1b"
  ]
}
```

`ops/src/manifest.ts` validates every address, rejects the zero address and case-insensitive duplicates, normalizes to EIP-55, sorts ascending by lowercase address, and rejects an empty list.

- **The cap is derived, not supplied.** It equals the unique recipient count; the build accepts no cap, so a manifest cannot carry undisclosed headroom. `MREP2_RECIPIENT_CAP` is copied exactly from the derived cap the tool prints, never chosen independently.
- **Provenance is mandatory and validated for shape, never invented or verified.** The tool checks that the source chain ID, block number and hash, source contracts, ruleset ID, and checksums are present and well-formed; it cannot confirm they describe a real snapshot. `sourceDataSha256` binds the manifest to its frozen source data, and only the human who produced it can attest to that.
- **Source and target chains are separate.** `provenance.sourceChainId` (where the snapshot was read) is intentionally independent of the plan's `targetChainId` (where CHECKAUGUR is deployed); a mainnet snapshot may drive a Sepolia rehearsal.
- **The detached checksum detects accidents, not adversaries.** `manifest.json.sha256` is unkeyed SHA-256 over the exact emitted bytes. It catches an accidental edit, truncation, or stale file; it proves neither approval nor authenticity.

Regenerate from frozen inputs; never hand-edit a production manifest. The contract hard limit is 200 recipients per call; use about 100 (no more than 150) for easier review, signing, and reconciliation.

```bash
cd ops && bun run ops -- manifest \
  --recipients ../data/snapshots/approved-recipients.json \
  --provenance ../data/snapshots/approved-provenance.json \
  --batch-size 100 \
  --out-dir ../data/batches/candidate-1
```

## Distribution plan

The token address does not exist when the snapshot is prepared, so the manifest cannot name it. `ops/src/distribution-plan.ts` performs the one deterministic step that binds an approved manifest to a deployed token, offline.

It re-validates the manifest, hashes the exact `manifest.json` bytes (verifying a supplied `--manifest-sha256` first), validates the target chain, deployed token address, source commit, and runtime bytecode hash, and rejects the plan if the token address appears anywhere in the recipient list. It derives batches from the canonical recipients, encodes the exact `distribute(address[])` calldata for each, then decodes each payload and asserts the decoded recipients equal the batch — so a mis-encoded payload never reaches a signer.

```json
{
  "version": 1,
  "targetChainId": 11155111,
  "token": "0x...",
  "sourceCommit": "40-character commit SHA",
  "runtimeBytecodeSha256": "sha256:...",
  "manifestSha256": "sha256:...",
  "batches": [
    {
      "number": 1,
      "recipients": [
        "0x3A1F8B0D9c2e4a7F6B5D8C9E0a1B2C3d4e5F6A7B",
        "0x8C4d2e1f0a9b7c6D5E4f3A2b1c0d9e8F7a6b5C4d",
        "0xD9e0f1A2B3c4d5e6f708192A3B4C5d6e7f809A1b"
      ],
      "calldata": "0x..."
    }
  ]
}
```

The plan is lean and repeats no manifest-derived value. It records **no nonce, fee, or gas**: any such value produced offline would be a guess presented as authoritative. The human preparing each transaction supplies those from live chain state under a separate task. The plan exists so a human can compare the exact decoded transaction against the approved batch before signing — for each batch, the plan's calldata must equal, byte for byte, what the signing device is about to sign.

```bash
cd ops && bun run ops -- plan \
  --manifest ../data/batches/candidate-1/manifest.json \
  --manifest-sha256 ../data/batches/candidate-1/manifest.json.sha256 \
  --target-chain-id 11155111 \
  --token 0xDeployedTokenAddress... \
  --source-commit <40-character hex git commit SHA> \
  --runtime-bytecode-sha256 sha256:<64 lowercase hex> \
  --output ../data/plans/candidate-1/plan.json
```

## Distribution

Distribute one batch at a time, reconciling each before preparing the next. The project owner approves the batch sequence and signs every transaction.

For each `distribute` transaction:

- confirm target is the deployed token, value is zero, and the recipient count is within the operational size (~100, ≤150);
- decode the calldata and compare the ordered array against the plan's numbered batch, byte for byte;
- confirm chain, nonce, gas, the expected cumulative `totalInitialRecipients`, and the expected remaining initial allocation (both computed from the batch sequence);
- have the project owner review and sign; record the transaction, block, nonce, and fee.

Reconcile before the next batch: exact calldata and `Transfer` event order; `wasInitialRecipient == true` for every distributed address; a one-token balance increase per recipient; `totalInitialRecipients` equal to the unique successful recipients; unchanged `totalSupply`; and `totalInitialRecipients <= recipientCap`. Any mismatch is a stop condition.

The remaining initial allocation, `(recipientCap - totalInitialRecipients) * 1e18`, is an off-chain projection — not a prediction of `balanceOf(token)`. CHECKAUGUR is freely transferable, so a holder may return tokens to the contract and push its live balance above the remaining allocation. Reconcile the two separately; a positive difference is not a defect on its own.

## Finalization

Finalize only after reconciling every batch, event, counter, and the remaining cap, with no unresolved incident and the owner's approval. Finalization is irreversible and closes distribution only; standard transfers, approvals, and `transferFrom` continue afterward, and total supply is unchanged.

- Decode and simulate the exact zero-value `finalizeDistribution` transaction.
- Record `totalInitialRecipients` and `contractBalanceAtFinalization` (the event's third field, `balanceOf(token)` at finalization).
- Separately compute the remaining initial allocation. If the contract balance exceeds it, the difference is tokens transferred to the contract outside distribution — investigate and record it before finalizing; no rescue or withdrawal path exists for returned tokens.
- Finalizing below the cap requires a written reason.
- After confirmation, record `DistributionFinalized` and prove that later distribution and repeated finalization revert while standard transfers still succeed.

## Incident handling

Stop, preserve evidence, and escalate to the responsible humans. Do not work around an incident.

| Incident | Immediate action |
| --- | --- |
| Wrong recipient list | Halt before signing; do not distribute. A wrong list already partly distributed cannot be reversed — record scope and escalate. |
| Wrong chain | Halt; a plan's `targetChainId` must match the deployment chain. Nothing signed on the wrong chain is valid distribution. |
| Wrong distributor | The distributor is immutable. A wrong or unusable distributor cannot be changed — the deployment is discarded and redone. |
| Unexpected transaction, event, or balance | Halt distribution; reconcile against the plan and on-chain state before any further batch. |
| Compromised distributor | Consider immediate `finalizeDistribution` while the owner retains legitimate control. It cannot recover a key, reverse prior distribution, or move the locked reserve, but it prevents further wrong-recipient distribution within remaining cap. |
| Incorrect calldata | Halt; the plan's decoded calldata must match the signing device byte for byte. Never sign calldata that does not decode to the approved batch. |
| Failed reconciliation | Halt before the next batch; do not finalize with an unresolved discrepancy. |
| Premature-finalization risk | Finalization is irreversible; never finalize with distribution or reconciliation incomplete absent a written incident decision. |

Key loss can prevent distribution and finalization; compromise can cause wrong-recipient distribution within remaining cap or premature finalization. Neither creates an on-chain recovery path — none exists.

## Records

Retain, per deployment: the chain and contract address; deployment transaction, block, and deployer; source commit and build settings; constructor arguments and artifact hashes; distributor and cap; manifests, plans, and checksums; every calldata payload and transaction; event and counter reconciliations; finalization state; incident records; and confirmation that agents accessed no key and signed or broadcast nothing.
