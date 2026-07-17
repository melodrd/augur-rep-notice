# Operations

This document governs safe preparation, deployment, distribution, reconciliation, finalization, explorer work, and public communications for `MigrateRepV2Token` (MREP2). Contract behavior is defined in [SPEC.md](SPEC.md); current local evidence is in [VALIDATION.md](VALIDATION.md).

No step here authorizes RPC access, wallet or key handling, signing, submission, verification, or broadcast. Those require an explicit, separately authorized human task. Agents may prepare unsigned artifacts and local simulations only when authorized and must never access or operate a production key.

## Stop conditions

Stop and preserve evidence if any of the following occurs:

- a required human approval or independent review is missing;
- source, compiler settings, dependency pins, bytecode, ABI, metadata, constructor data, chain, distributor, cap, manifest, calldata, nonce, or checksum differs from the reviewed artifact;
- the manifest count does not match the approved `recipientCap`;
- a test, simulation, source-verification, gas-bound, or reconciliation check fails;
- an unexplained transaction, replacement, event, balance, counter, EOA activity, or publication change appears;
- key compromise, manifest misuse, wrong-chain preparation, or incorrect calldata is suspected; or
- any action would expose a key, seed phrase, keystore, secret, or credential.

Do not work around a stop condition. The responsible humans decide whether to correct, abandon, redeploy, finalize, or resume.

## Recipient manifest

Recipient selection is security- and reputation-sensitive business logic and is out of scope for this repository until separately approved. Do not invent REP sources, snapshots, migration semantics, thresholds, exclusions, or addresses.

The tooling in `ops/src/manifest.ts` prepares distribution off-chain and deterministically. It validates every address, rejects zero and duplicate addresses, normalizes for comparison, sorts by one canonical rule (ascending lowercase 20-byte hex), splits into batches no larger than the operational batch size, and records batch numbers, recipient counts, cumulative recipient counts, the expected reserve after each batch, and cryptographic checksums (input, per-batch, and full-manifest). It refuses to generate more recipients than `recipientCap`, never repairs a malformed address, stores no personal data, and never signs or broadcasts.

The approved manifest's unique-address count becomes the exact nonzero constructor `recipientCap`; add no discretionary margin. Regenerate from frozen inputs; never edit a production manifest by hand. On-chain duplicate protection remains authoritative even though the manifest is deduplicated. The contract hard limit is 200 recipients per `distribute` call; operations should normally use about 100 (and no more than 150) for easier review, signing, monitoring, and reconciliation.

## Candidate and unsigned artifacts

Before rehearsal or deployment: freeze the source commit, Solidity compiler, optimizer, EVM target, dependency pins, creation and runtime bytecode, ABI, storage layout, and hashes; reproduce the candidate independently; classify compiler and Slither findings; review constructor arguments and encoded data; confirm the distributor and cap are nonzero and the cap equals the manifest count; and confirm the ABI contains only the approved surface and no forbidden selector. Every unsigned artifact states chain and chain ID, target, value, nonce assumptions, decoded calldata, checksum, expected state transition, expected counters, and simulation result, and contains no secret.

Regenerate the frozen artifacts from the canonical build:

```bash
forge inspect MigrateRepV2Token bytecode | sha256sum
forge inspect MigrateRepV2Token deployedBytecode | sha256sum
forge inspect MigrateRepV2Token abi
forge inspect MigrateRepV2Token storageLayout
```

## Distributor EOA boundaries

The production distributor is one dedicated EOA controlled by the project owner. The same address is expected to deploy and be supplied explicitly as `distributor`; deployment by itself grants no token balance or privilege. Use no everyday, shared, or unrelated wallet; prefer hardware-backed signing; keep only reasonably required operational ETH; use a distinct Sepolia-only key for any testnet work. Review chain, target, value, calldata, nonce, manifest checksum, and simulation before every signature. Humans alone control, sign with, submit from, and monitor the EOA. Agents and tooling must never request, read, create, import, store, print, or operate any key or secret.

Key loss can prevent distribution and finalization. Compromise can cause wrong-recipient distribution within remaining cap headroom or premature finalization. Neither risk creates an on-chain recovery administrator, and no reserve-recovery path exists.

## Deployment tooling

The repository contains one auditable deployment script, `script/DeployMigrateRepV2Token.s.sol`. It reads two non-secret environment values, rejects a zero distributor or zero cap before any broadcast preparation, deploys exactly one `MigrateRepV2Token` with those values passed explicitly, and logs the deployed address, distributor, cap, and maximum supply. It performs no distribution, transfer, approval, or finalization; embeds no network, account, key, RPC endpoint, or secret; deploys no liquidity; and never reads a private key, mnemonic, or keystore password. Signing and broadcasting are supplied entirely by a human-run Foundry command in a later, separately authorized task.

Set the two non-secret arguments and the RPC endpoint in the operator's shell. `MREP2_DISTRIBUTOR` and `MREP2_RECIPIENT_CAP` must equal the reviewed, approved values, and the cap must equal the frozen manifest's unique-address count.

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

Humans approve the batch sequence and stop conditions. For each `distribute` transaction: compare the decoded ordered array with the numbered manifest and checksum; confirm a count within the operational size; confirm chain, target, zero value, nonce, gas, expected cumulative `totalInitialRecipients`, and expected reserve; have the project owner review and sign; record the transaction, block, nonce, and fee; and reconcile before preparing the next batch. Reconciliation requires exact calldata and `Transfer` event order, `wasInitialRecipient == true` for every distributed address, a one-token balance increase per recipient, `totalInitialRecipients` equal to unique successful recipients, unchanged `totalSupply`, and `totalInitialRecipients <= recipientCap`. Any mismatch is a stop condition.

Finalize only after reconciling every manifest, event, counter, and remaining cap, with no unresolved incident and human approval. Decode and simulate the exact zero-value `finalizeDistribution` transaction; record `totalInitialRecipients` and the current reserve. Finalizing below the cap requires a written reason. After confirmation, record `DistributionFinalized` and prove later distribution and repeated finalization revert while standard transfers still succeed. Consider immediate finalization for a credible incident while the owner retains legitimate control; it cannot recover a key, reverse prior distribution, or move the locked reserve.

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
