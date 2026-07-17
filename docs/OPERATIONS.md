# Operations

This document governs safe preparation, deployment, distribution, reconciliation, finalization, explorer work, and public communications for `MigrateRepV2Token` (MREP2). Contract behavior is defined in [SPEC.md](SPEC.md); current local evidence is in [VALIDATION.md](VALIDATION.md).

No step here authorizes RPC access, wallet or key handling, signing, submission, verification, or broadcast. Those require an explicit, separately authorized human task. Agents may prepare unsigned artifacts and local simulations only when authorized and must never access or operate a production key.

## Stop conditions

Stop and preserve evidence if any of the following occurs:

- a required human approval or independent review is missing;
- the recipient eligibility policy, snapshot, or exclusion decisions are not approved in writing by the project owner;
- source, compiler settings, dependency pins, bytecode, ABI, metadata, constructor data, chain, distributor, cap, manifest, provenance, calldata, nonce, or checksum differs from the reviewed artifact;
- `MREP2_RECIPIENT_CAP` is not exactly the approved manifest's derived `recipientCap`;
- the deployed token address appears in the recipient list;
- the distributor is the token contract's own address;
- a test, simulation, source-verification, gas-bound, or reconciliation check fails;
- an unexplained transaction, replacement, event, balance, counter, EOA activity, or publication change appears;
- key compromise, manifest misuse, wrong-chain preparation, or incorrect calldata is suspected; or
- any action would expose a key, seed phrase, keystore, secret, or credential.

Do not work around a stop condition. The responsible humans decide whether to correct, abandon, redeploy, finalize, or resume.

## Recipient selection is a human policy gate

**Recipient selection is not a repository decision, and no agent or tool may make it.** This repository can validate, normalize, checksum, and package an approved list. Approving the eligibility policy that produces that list is the project owner's, and only the project owner's, decision.

Taking every address from an explorer holder list is **not** an approved recipient methodology. A holder list is an unreviewed, unattributed snapshot of one contract at one moment; it silently mixes exchanges, bridges, contracts, and dust, records no rules, and cannot be reproduced or audited later.

The following decisions are unresolved and must each be settled and recorded in writing by the project owner before any manifest is production data:

```text
source chain or chains
source REP/REPv2 contract addresses
snapshot block number and hash
whether already migrated addresses are included
minimum balance or dust threshold
treatment of exchanges and custodians
treatment of bridges, escrow, wrappers, and protocol contracts
treatment of smart wallets and multisignatures
treatment of burn/dead addresses
treatment of known project-controlled contracts
deduplication across sources
manual-review requirements
final inclusion and exclusion approval
```

The final process must produce, and retain: included addresses; excluded addresses; manual-review addresses; a stable reason code for every exclusion or manual-review decision; the source balance in raw integer units; a source reference for each decision; the final unique included count; and checksums of every frozen input and output. Store no personal information — an address, a raw balance, a reason code, and a source reference are sufficient, and nothing that identifies a natural person may enter this repository.

### Recipient classes requiring an explicit decision

None of these classes is automatically valid or invalid. Each needs a recorded policy decision with a reason, not a default:

EOAs; Safe and other smart-wallet contracts; centralized-exchange hot and cold wallets; custodians; bridges; escrow contracts; wrappers; liquidity contracts; Augur protocol contracts; dead and burn addresses; and contracts that held REP on behalf of multiple users.

Do not attempt to resolve this on chain with a `code.length` filter. Contract recipients may be entirely legitimate — a multisignature or smart wallet is an ordinary user — and bytecode presence does not identify who controls an address or on whose behalf it held REP. The contract deliberately performs no bytecode check; it rejects only the zero address and the token contract itself.

## Distribution workflow

The path from an approved recipient list to a finalized distribution:

```text
recipient source data
→ lean manifest          offline, human-approved recipient artifact
→ derived cap            MREP2_RECIPIENT_CAP = the unique recipient count
→ deployment             separately authorized human task
→ lean distribution plan binds the manifest to the deployed token
→ reviewed calldata      decoded and compared byte-for-byte before signing
→ signed transactions    human-signed, one batch at a time
→ reconciliation         events, counters, balances
→ finalization           irreversible close
```

Two facts frame everything below:

- **The contract never reads the manifest.** It is an offline, human-approved recipient artifact. The only value that crosses into the contract is the derived cap, copied by hand into `MREP2_RECIPIENT_CAP`.
- **Detached hashes detect accidents, not adversaries.** `manifest.json.sha256` and `plan.json.sha256` catch an accidental edit, a truncated copy, or a stale file. They are public, unkeyed SHA-256 over the exact emitted bytes and prove neither human approval nor authenticity; that rests on the separately authorized review process.

## Recipient manifest

The tooling in `ops/src/manifest.ts` prepares the recipient list off-chain and deterministically. It validates every address, rejects the zero address and case-insensitive duplicates, normalizes to EIP-55 checksum form, sorts by one canonical rule (ascending lowercase 20-byte hex), and rejects an empty list. It never repairs a malformed address, stores no personal data, and never signs, broadcasts, or reaches the network.

The manifest stores only authoritative inputs — a version, provenance, batch size, and the canonical recipient list. Everything else is derived on demand and never stored: the recipient cap, maximum supply, batch split, and per-recipient counts are computed whenever they are displayed or needed. There are no embedded checksums, no per-batch records, and no schema-migration machinery — the format is version 1 and there is no other version.

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
  "recipients": ["0x..."]
}
```

**The recipient cap is derived, not supplied.** It equals the number of addresses in the canonical list, and maximum supply equals `recipientCap * TOKEN_PER_RECIPIENT`. The build accepts no cap, so a manifest cannot carry discretionary supply or distribution headroom, and an empty recipient list is rejected. `MREP2_RECIPIENT_CAP` must be copied exactly from the derived cap the tool prints; it is never chosen independently, and never given a margin.

**Source and target chains are separate.** `provenance.sourceChainId` is the chain the snapshot was read from. It is intentionally independent of the plan's `targetChainId`, the chain MREP2 is deployed on. A real Ethereum-mainnet snapshot (`sourceChainId` 1) can therefore drive a Sepolia rehearsal (`targetChainId` 11155111); the two are never required to match.

Every manifest requires provenance — explicit, human-supplied values that are validated for shape but never invented: `sourceChainId`, `snapshotBlockNumber`, `snapshotBlockHash`, `sourceContracts`, `sourceDataSha256`, `rulesetId`, and `rulesetSha256`. The tool checks that these are present and well-formed; provenance is recorded and validated structurally, not independently verified — the tool cannot confirm it describes a real snapshot. `sourceDataSha256` is the value that binds the manifest to its frozen source data, and only the human who produced it can attest that it does. A manifest without provenance is not production-reviewable and the tool refuses to build one.

Regenerate from frozen inputs; never edit a production manifest by hand. On-chain duplicate protection remains authoritative even though the manifest is deduplicated. The contract hard limit is 200 recipients per `distribute` call; operations should normally use about 100 (and no more than 150) for easier review, signing, monitoring, and reconciliation.

Build a manifest offline. The command reads explicit files, writes `manifest.json`, `manifest.csv`, and `manifest.json.sha256` (the SHA-256 of the exact `manifest.json` bytes), refuses to overwrite existing output unless `--force` is passed, prints the derived counts and checksum, and makes no network request:

```bash
cd ops && bun run ops -- manifest \
  --recipients ../data/snapshots/approved-recipients.json \
  --provenance ../data/snapshots/approved-provenance.json \
  --batch-size 100 \
  --out-dir ../data/batches/candidate-1
```

### Remaining initial allocation is not the contract balance

The remaining initial allocation is `(recipientCap - distributed) * TOKEN_PER_RECIPIENT`: an off-chain projection of the original allocation not yet distributed. It is **not** a prediction of the token contract's live balance. MREP2 is freely transferable, so any holder may transfer tokens back to `address(token)`, and `balanceOf(address(token))` can therefore exceed the remaining initial allocation by an arbitrary amount. Reconcile the two separately and never treat a positive difference as an accounting defect on its own.

## Offline distribution plan

The final token address does not exist when the recipient snapshot is prepared, so an approved manifest cannot name it. `ops/src/distribution-plan.ts` performs the one deterministic step that binds an approved manifest to a deployed candidate, entirely offline.

It reads the manifest, re-validates it, and hashes the exact `manifest.json` bytes to bind the plan to that one file (recorded as `manifestSha256`; if a detached checksum file is supplied with `--manifest-sha256`, the tool verifies the bytes against it first). It validates the target chain, the deployed token address (rejecting the zero address), the source commit, and the runtime bytecode hash; rejects the plan if the deployed token address appears anywhere in the recipient list; derives batches from the manifest's canonical recipients and batch size; encodes the exact `distribute(address[])` calldata for each batch with viem; and then decodes each generated payload and asserts the decoded recipients exactly equal the expected batch, so a mis-encoded payload never reaches a signer.

The plan is lean: it stores only the target chain, token, source commit, runtime bytecode hash, the bound manifest checksum, and — per batch — the batch number, recipients, and calldata. It repeats no manifest-derived value: no maximum supply, recipient cap, cumulative count, remaining allocation, first/last address, or per-batch checksum.

```json
{
  "version": 1,
  "targetChainId": 11155111,
  "token": "0x...",
  "sourceCommit": "40-character commit SHA",
  "runtimeBytecodeSha256": "sha256:...",
  "manifestSha256": "sha256:...",
  "batches": [{ "number": 1, "recipients": ["0x..."], "calldata": "0x..." }]
}
```

It makes no RPC request, signs nothing, and broadcasts nothing. It deliberately records **no nonce, fee, or gas figure**: any such value produced offline would be a guess presented as authoritative. The human preparing each transaction supplies those from live chain state under a separately authorized task.

The plan exists so a human can compare the exact decoded transaction against the approved batch before signing: for each batch, the calldata in the plan must equal, byte for byte, what the signing device is about to sign.

Generate the plan offline. It writes `plan.json` and `plan.json.sha256` (the SHA-256 of the exact `plan.json` bytes) and refuses to overwrite existing output unless `--force` is passed:

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

## Candidate and unsigned artifacts

Before rehearsal or deployment: freeze the source commit, Solidity compiler, optimizer, EVM target, dependency pins, creation and runtime bytecode, ABI, storage layout, and hashes; reproduce the candidate independently; classify compiler and Slither findings; review constructor arguments and encoded data; confirm the distributor and cap are nonzero, the distributor is not the predicted token address, and the cap equals the manifest's derived count; and confirm the ABI contains only the approved surface and no forbidden selector. Every unsigned artifact states chain and chain ID, target, value, nonce assumptions, decoded calldata, checksum, expected state transition, expected counters, and simulation result, and contains no secret.

Regenerate the frozen artifacts from the canonical build:

```bash
forge inspect MigrateRepV2Token bytecode | sha256sum
forge inspect MigrateRepV2Token deployedBytecode | sha256sum
forge inspect MigrateRepV2Token abi
forge inspect MigrateRepV2Token storageLayout
```

## Distributor EOA boundaries

The production distributor is one dedicated EOA controlled by the project owner. The same address is expected to deploy and be supplied explicitly as `distributor`; deployment by itself grants no token balance or privilege. Use no everyday, shared, or unrelated wallet; prefer hardware-backed signing; keep only reasonably required operational ETH; use a distinct Sepolia-only key for any testnet work. Review chain, target, value, calldata, nonce, manifest checksum, and simulation before every signature. Humans alone control, sign with, submit from, and monitor the EOA. Agents and tooling must never request, read, create, import, store, print, or operate any key or secret.

The distributor must be neither the zero address nor the token contract's own address; the constructor rejects both. A deployment that passed the predicted token address as its distributor would be permanently unusable, because only the token contract could call `distribute` or `finalizeDistribution` and it has no self-call mechanism. A reviewed contract distributor, such as a multisignature, remains valid.

Key loss can prevent distribution and finalization. Compromise can cause wrong-recipient distribution within remaining cap headroom or premature finalization. Neither risk creates an on-chain recovery administrator, and no reserve-recovery path exists.

## Deployment tooling

The repository contains one auditable deployment script, `script/DeployMigrateRepV2Token.s.sol`. It reads two non-secret environment values, rejects a zero distributor or zero cap before any broadcast preparation, deploys exactly one `MigrateRepV2Token` with those values passed explicitly, and logs the deployed address, distributor, cap, and maximum supply. It performs no distribution, transfer, approval, or finalization; embeds no network, account, key, RPC endpoint, or secret; deploys no liquidity; and never reads a private key, mnemonic, or keystore password. The script contains `vm.startBroadcast()` and will broadcast when a human explicitly invokes Forge with `--broadcast`; it embeds no account, key, RPC, or network and does not broadcast otherwise.

Set the two non-secret arguments and the RPC endpoint in the operator's shell. `MREP2_DISTRIBUTOR` and `MREP2_RECIPIENT_CAP` must equal the reviewed, approved values, and the cap must be copied exactly from the frozen manifest's derived `recipientCap`.

```bash
export MREP2_DISTRIBUTOR="0x..."
export MREP2_RECIPIENT_CAP="..."
export SEPOLIA_RPC_URL="..."
```

`SEPOLIA_RPC_URL` and `ETHERSCAN_API_KEY` are sensitive; keep them only in the shell or an untracked `.env` (git-ignored). Confirm the endpoint is Sepolia (`cast chain-id`, expect `11155111`) before anything else, then simulate without broadcasting:

```bash
forge script script/DeployMigrateRepV2Token.s.sol:DeployMigrateRepV2Token --rpc-url "$SEPOLIA_RPC_URL" -vvvv
```

The `--broadcast --verify` shape is recorded for reference only and is **not authorized by this task**; a human runs it under a separate task, selecting the signing account via Foundry's keystore (`--account`). After a confirmed deployment, independently read the live contract and reconcile `name`, `symbol`, `decimals`, `MAX_BATCH_SIZE`, `distributor`, `recipientCap`, `maximumSupply`, `totalSupply`, `balanceOf(contract)`, `totalInitialRecipients`, and `distributionFinalized`. Expect the fixed metadata, cap and maximum supply equal to the approved values, the whole supply held by the contract, zero `totalInitialRecipients`, and `distributionFinalized` false. Any mismatch is a stop condition.

## Distribution and finalization

Humans approve the batch sequence and stop conditions. Generate the offline distribution plan once the candidate is deployed, then work from it. For each `distribute` transaction: compare the decoded ordered array with the plan's numbered batch and its calldata byte for byte; confirm a count within the operational size; confirm chain, target, zero value, nonce, gas, the expected cumulative `totalInitialRecipients`, and the expected remaining initial allocation (both computed from the batch sequence); have the project owner review and sign; record the transaction, block, nonce, and fee; and reconcile before preparing the next batch. Reconciliation requires exact calldata and `Transfer` event order, `wasInitialRecipient == true` for every distributed address, a one-token balance increase per recipient, `totalInitialRecipients` equal to unique successful recipients, unchanged `totalSupply`, and `totalInitialRecipients <= recipientCap`. Any mismatch is a stop condition.

Finalize only after reconciling every manifest, event, counter, and remaining cap, with no unresolved incident and human approval. Decode and simulate the exact zero-value `finalizeDistribution` transaction; record both `totalInitialRecipients` and `contractBalanceAtFinalization` (the token contract's complete balance, `balanceOf(address(this))`, and the event's third field). Separately compute the remaining initial allocation as `(recipientCap - totalInitialRecipients) * TOKEN_PER_RECIPIENT`. If the contract balance exceeds that figure, the difference is tokens transferred to the contract outside initial distribution; do not treat such a difference as a contract accounting defect on its own — investigate and record it before finalizing. No rescue or withdrawal path exists for returned tokens. Finalizing below the cap requires a written reason. After confirmation, record `DistributionFinalized` and prove later distribution and repeated finalization revert while standard transfers still succeed. Consider immediate finalization for a credible incident while the owner retains legitimate control; it cannot recover a key, reverse prior distribution, or move the locked reserve.

## Source verification and explorer metadata

After deployment, compare runtime bytecode with the frozen hash before relying on an explorer. Submit the exact frozen source, compiler and optimizer settings, EVM target, constructor arguments, and ABI for verification. Review the current official explorer instructions; do not invent a submission URL or assume approval. Record submission date, submitting role, verification link, displayed ABI and metadata, response, status, and screenshots. Explorer display is never the canonical identity and never a substitute for direct bytecode checks.

## Trust and anti-scam metadata package

Prepare this reviewable, non-secret package for eventual explorer and wallet submissions. Do not submit it here, and do not invent missing values — leave placeholders.

```text
canonical contract address    : <checksummed address, after deployment>
official website              : <placeholder>
official migration page       : <informational, independently navigable; no wallet-connect>
official project email        : <placeholder>
logo                          : <no address, QR, shortened URL, claim, or wallet-connect prompt>
project description           : the neutral description below
source repository             : <if public>
official social profiles      : <placeholder>
verified-source URL           : <after verification>
```

The package must state: exact name `MIGRATE REPV2`, symbol `MREP2`, and decimals `18`; fixed maximum supply with no post-deployment minting; no taxes, blacklist, or pause; no owner or roles; no upgradeability; no project-supported liquidity or price; that the token performs no migration; that receiving it requires no wallet connection; and that no approval, swap, claim, bridge, or payment is required. The official migration page must be informational and independently navigable, with no embedded wallet-connect requirement, and must not claim that standard ERC-20 behavior guarantees automatic wallet display.

## Canonical user messaging

Neutral description:

> MIGRATE REPV2 (MREP2) is a transferable, fixed-supply ERC-20 notice token distributed to selected addresses. Each initial recipient receives one MREP2 token. MREP2 does not perform REP migration and is not REP, REPv2, a migration claim, migration eligibility proof, redemption right, governance right, reward, or project-supported investment asset.

The official Augur website must be the canonical source for the verified checksummed address, chain, source-verification link, the notice meaning, and safety guidance; other official channels link back to it. Wallets, explorers, search results, reposts, direct messages, prices, liquidity, and copied source are not authentication. Tell users that receiving MREP2 requires no action and that they should not approve, transfer, swap, bridge, claim, deposit, sign, or connect a wallet because of it, and should navigate independently to official Augur sources. Do not promise wallet display or describe validation or review as an audit.

## Permanent records

Retain the chain and contract address; deployment transaction, block, timestamp, and deployer; source commit and build settings; constructor arguments; bytecode and artifact hashes; distributor and cap; source-verification state; manifests and checksums; every calldata payload and transaction; events and counter reconciliations; finalization state; explorer submissions and corrections; official publication evidence; incident records; and confirmation that agents accessed no key and signed or broadcast no transaction.
