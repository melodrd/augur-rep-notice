# Operations

This document governs safe preparation, deployment, distribution, reconciliation, finalization, Etherscan work, and public communications for `CHECK AUGUR REP MIGRATION`. Contract behavior is defined in [SPEC.md](SPEC.md); current local evidence is recorded in [VALIDATION.md](VALIDATION.md).

No step here authorizes RPC access, wallet or key handling, signing, submission, or broadcast. Those activities require an explicit human-approved task. Agents may prepare unsigned artifacts and simulations only when authorized and must never access or operate a production key.

## Stop conditions

Stop and preserve evidence if any of the following occurs:

- a required human approval or independent review is missing;
- source, compiler settings, dependency pins, bytecode, ABI, metadata, constructor data, chain, authority, cap, manifest, calldata, nonce, or checksum differs from the reviewed artifact;
- the manifest count does not exactly equal the immutable cap;
- required historical state is unavailable or inconsistent;
- a test, simulation, source-verification check, gas bound, or reconciliation fails;
- an unexplained transaction, replacement, event, balance, counter, EOA activity, or publication change appears;
- malware, key compromise, manifest misuse, wrong-chain preparation, or incorrect calldata is suspected; or
- any action would expose a key, seed phrase, recovery phrase, keystore, secret environment value, or credential.

Do not work around a stop condition. The responsible humans decide whether to correct, abandon, redeploy, finalize, or resume.

## Recipient source and snapshot

Recipient selection is security- and reputation-sensitive business logic. Before generating a manifest, approve and record:

- chain ID and RPC source category without credentials;
- snapshot block number, hash, and timestamp;
- every REP or migration contract address queried;
- holder-discovery method and historical-state availability;
- raw balance threshold and explicit decimals;
- included versions or universes;
- migration classification and deterministic exclusion rules;
- script commit hash, generation timestamp, and output checksum.

Use raw integer balances and `bigint`, never floating-point arithmetic. Fail closed when required historical state cannot be reproduced. Do not guess a source contract, snapshot, migration definition, threshold, exclusion, or address classification.

Each filter needs a stable identifier, plain-language rule, deterministic implementation, tests, affected-address count, and explicit inclusion or exclusion reason. Do not silently discard records or exclude a contract merely because bytecode exists.

## Address validation and manifest freeze

The recipient pipeline must:

1. reject malformed and zero addresses;
2. normalize addresses for case-insensitive comparison;
3. deduplicate deterministically;
4. sort by one documented canonical rule;
5. preserve checksum formatting in human-facing outputs; and
6. never infer, autocomplete, or repair an address from prose.

Generate deterministic JSON, reviewable CSV, a reason-coded summary, and cryptographic checksums. Regenerate from frozen inputs; never edit a production manifest manually.

Independently reproduce the output. The approved manifest's unique-address count becomes the exact nonzero constructor `distributionCap`; add no discretionary margin. Any material post-freeze change requires a new manifest, cap, artifact review, and usually redeployment.

Each numbered batch manifest records:

- recipient count and canonical first and last address;
- input and complete-manifest checksums;
- batch checksum and exact ordered recipient array;
- expected cumulative `totalIssued`; and
- expected active `totalSupply`, reconciled separately from issuance.

The contract hard limit is 500 recipients. Prefer approximately 100–200 per operational batch to simplify manual calldata review, signing, monitoring, and reconciliation. Use a smaller batch when gas, calldata, tooling, or incident exposure warrants it.

Before any production deployment, record the approved target-chain block gas limit and demonstrate with the canonical build that the worst-case successful 500-recipient call uses no more than 50% of that limit. If this gate is not met, stop and approve a lower operational bound or a revised candidate; do not treat the compile-time ceiling as an automatically safe transaction size.

## Candidate and unsigned artifacts

Before rehearsal or deployment:

- freeze the source commit, Solidity compiler, optimizer, EVM target, dependency pins, creation bytecode, runtime bytecode, ABI, storage layout, and hashes;
- reproduce the candidate in an independent environment;
- classify compiler and static-analysis findings;
- record the approved target-chain block gas limit and evidence for the 50% maximum-batch gate;
- review constructor arguments and encoded data;
- confirm the authority and cap are nonzero and the cap equals the manifest count; and
- confirm the ABI contains only the approved surface and no forbidden selector.

Every unsigned transaction artifact states chain and chain ID, target, value, nonce assumptions, decoded calldata, relevant checksum, expected state transition, expected counters, and simulation result. It contains no secret or signing authorization.

## Authority EOA boundaries

The production authority is one dedicated EOA controlled by the project owner. The same address is expected to deploy and be supplied explicitly as `authority`; deployment by itself grants no privilege.

- Use no everyday, shared, or unrelated DeFi wallet.
- Prefer hardware-backed signing and document any exception without exposing secrets.
- Keep only reasonably required operational ETH.
- Use a distinct Sepolia-only key; never reuse the mainnet key on a testnet.
- Review chain, target, value, calldata, nonce, manifest checksum, simulation, and expected state before every signature.
- Humans alone control, sign with, submit from, and monitor the EOA.
- Agents and repository tooling must not request, read, create, import, store, print, or operate any private key, seed phrase, recovery phrase, raw keystore, or secret environment value.

Key loss can prevent distribution and finalization. Compromise can cause wrong-recipient issuance within remaining cap headroom or premature finalization. Neither risk creates an on-chain recovery administrator.

## Simulation and deployment preparation

Run the validation commands in [VALIDATION.md](VALIDATION.md) using the checked-in configuration. Simulation must cover deployment, canary, normal batches, a 500-recipient batch, 501-recipient rejection, cap boundaries, duplicates, prior active and burned recipients, unauthorized callers, finalization, and self-burn before and after finalization.

Before a human signs a deployment transaction, independently confirm:

- network and chain ID;
- creation bytecode, runtime expectation, compiler settings, and constructor data;
- checksummed deployer and explicit authority equality;
- exact manifest-derived cap;
- zero value, expected nonce, gas assumptions, and simulated state; and
- exact metadata, zero initial counters, readable authority and cap, and unfinalized state.

An incorrect authority, cap, chain, bytecode, or constructor value is an abandon-or-redeploy condition, not a repairable configuration.

## Deployment tooling

The repository contains one auditable deployment script, `script/DeployRepMigrationAlert.s.sol`. It reads two non-secret values from the environment, rejects a zero authority or zero cap before any broadcast preparation, deploys exactly one `RepMigrationAlert` with the authority and cap passed explicitly, and logs the deployed address. It performs no distribution or finalization, embeds no network, account, key, RPC endpoint, secret, or production address, and never reads a private key, mnemonic, or keystore password. Account selection, signing, and broadcasting are supplied entirely by a human-run Foundry command during a later, separately authorized task; documenting the commands here does not authorize an agent to run them.

Set the two contract arguments and the RPC endpoint in the operator's shell. `ALERT_AUTHORITY` and `DISTRIBUTION_CAP` must equal the reviewed, approved values, and `DISTRIBUTION_CAP` must equal the frozen manifest's unique-address count.

```bash
export ALERT_AUTHORITY="0x..."
export DISTRIBUTION_CAP="..."
export SEPOLIA_RPC_URL="..."
```

`SEPOLIA_RPC_URL` is sensitive provider configuration. Keep it only in the operator's shell or an untracked `.env`; never commit it, log it, or place it in a tracked file. `.env` and its variants are git-ignored.

Confirm the endpoint points at Sepolia before anything else:

```bash
cast chain-id --rpc-url "$SEPOLIA_RPC_URL"
```

The expected Sepolia chain ID is:

```text
11155111
```

Simulate the deployment with no broadcasting. This reads the environment, runs the script's validation, and reports the would-be transaction without signing or sending anything:

```bash
forge script \
  script/DeployRepMigrationAlert.s.sol:DeployRepMigrationAlert \
  --rpc-url "$SEPOLIA_RPC_URL" \
  -vvvv
```

The following broadcast shape is recorded for reference only and is **not authorized by this task**. A human runs it under a separate, explicitly authorized task, selecting the signing account through Foundry's keystore mechanism (`--account`); this repository and its tooling never hold the key:

```bash
forge script \
  script/DeployRepMigrationAlert.s.sol:DeployRepMigrationAlert \
  --chain sepolia \
  --rpc-url "$SEPOLIA_RPC_URL" \
  --account <SEPOLIA_KEYSTORE_ACCOUNT> \
  --broadcast \
  --verify \
  --verifier etherscan \
  --etherscan-api-key "$ETHERSCAN_API_KEY" \
  -vvvv
```

After a deployment is confirmed, independently read the live contract and reconcile every value against the reviewed candidate and constructor arguments:

```bash
cast call "$DEPLOYED_ADDRESS" "name()(string)"             --rpc-url "$SEPOLIA_RPC_URL"
cast call "$DEPLOYED_ADDRESS" "symbol()(string)"           --rpc-url "$SEPOLIA_RPC_URL"
cast call "$DEPLOYED_ADDRESS" "decimals()(uint8)"          --rpc-url "$SEPOLIA_RPC_URL"
cast call "$DEPLOYED_ADDRESS" "MAX_BATCH_SIZE()(uint256)"  --rpc-url "$SEPOLIA_RPC_URL"
cast call "$DEPLOYED_ADDRESS" "authority()(address)"       --rpc-url "$SEPOLIA_RPC_URL"
cast call "$DEPLOYED_ADDRESS" "distributionCap()(uint256)" --rpc-url "$SEPOLIA_RPC_URL"
cast call "$DEPLOYED_ADDRESS" "totalIssued()(uint256)"     --rpc-url "$SEPOLIA_RPC_URL"
cast call "$DEPLOYED_ADDRESS" "totalSupply()(uint256)"     --rpc-url "$SEPOLIA_RPC_URL"
cast call "$DEPLOYED_ADDRESS" "finalized()(bool)"          --rpc-url "$SEPOLIA_RPC_URL"
```

Expect the fixed metadata, `MAX_BATCH_SIZE` of 500, the exact supplied authority and cap, zero `totalIssued` and `totalSupply`, and `finalized` false. Any mismatch is a stop condition.

## Sepolia rehearsal

Sepolia requires explicit authorization and a separate test-only dedicated EOA. Deploy the exact candidate and verify its source. Exercise:

- one-address canary plus representative 100–200 and maximum-size batches;
- every validation stage and atomic rollback;
- active-holder, never-alerted, and repeated burn;
- burned-recipient reissuance rejection and cap accounting after burns;
- a contract recipient calling `burn()` itself;
- normal and emergency finalization; and
- post-finalization distribution rejection with continuing holder self-burn.

Reconcile calldata, issuance and burn events, balances, `wasAlerted`, both counters, remaining cap, and finalization state after each step. Independently review the rehearsal. Any candidate change invalidates the rehearsal.

## Source verification and Etherscan

After deployment, compare runtime bytecode directly with the frozen hash before relying on an explorer. Submit the exact frozen source, compiler and optimizer settings, EVM target, constructor arguments, and ABI for verification.

Etherscan is the only third-party metadata surface currently in scope. Its forms and requirements may change, so review the current official Etherscan instructions after deployment; do not invent a submission URL or assume approval. Where supported, submit only reviewed values:

- exact name `CHECK AUGUR REP MIGRATION`, symbol `MIGRATEREP`, and decimals `0`;
- the official Augur page;
- an accurate non-economic description; and
- an approved logo without an address, QR code, shortened URL, claim, or wallet-connect prompt.

Record the submission date, submitting role, source-verification link, displayed ABI and metadata, response, status, screenshots, and all corrections. Etherscan verification or display is not a substitute for direct bytecode checks and is never the canonical identity.

## Canary and batch execution

Humans approve the canary recipients, exact batch sequence, and stop conditions before execution. For each transaction:

1. compare the decoded ordered array with the numbered manifest and checksum;
2. confirm a count of no more than 500, normally approximately 100–200;
3. confirm chain, target, zero value, nonce, gas, cumulative `totalIssued`, active `totalSupply`, and simulation;
4. have the project owner manually review and sign;
5. record transaction, block, confirmations, fee, nonce, and replacement history; and
6. reconcile the confirmed transaction before preparing the next batch.

Reconciliation requires exact calldata and issuance-event order, `wasAlerted == true` for every issued address, balance one for active recipients, balance zero for burned recipients, `totalIssued` equal to unique successful recipients, `totalSupply` equal to active units, and:

```text
totalSupply <= totalIssued <= distributionCap
remaining issuance capacity = distributionCap - totalIssued
```

Record burn events separately. A burn changes active supply only; it never creates issuance headroom. Any mismatch is a stop condition.

## Self-burn operational test

Use only controlled rehearsal holders. Confirm a valid holder can call `burn()` before and after finalization, the event is `Transfer(holder, address(0), 1)`, the balance and `totalSupply` decrease by one, and `wasAlerted` and `totalIssued` remain unchanged. Confirm never-alerted and repeated burns fail and no account can burn another holder's unit.

Never present self-burn as required, recommended, corrective, or part of REP migration. It cannot erase events, transaction history, permanent alert history, or cached records.

## Finalization

### Normal finalization

Wait at least 24 hours after the final normal batch. Reconcile every manifest, issuance and burn event, recipient state, both counters, remaining cap, EOA nonce and activity, and any issuance shortfall. Require no unresolved incident, independent review, and human approval.

Decode and simulate the exact zero-value finalization transaction. Record expected `finalIssued` and current active `totalSupply` separately. Finalization below the cap requires a written reason such as an approved recipient removal, operational stop, incident response, or campaign termination.

After confirmation, record the event and prove later distribution and repeated finalization fail while active-holder burn still succeeds.

### Emergency finalization

Consider immediate finalization for credible key compromise, manifest misuse, unexpected issuance, wrong transaction preparation, or another active incident, but only while the project owner retains legitimate control.

Stop distribution, preserve and reconcile the current state, decode and simulate finalization, obtain human approval, and have the owner manually sign. Record the issuance shortfall separately from burns and issue any required public warning. Finalization cannot recover a lost key, reverse prior issuance, or guarantee control after compromise.

## Canonical user messaging

The official Augur website must be the canonical source for the independently verified checksummed contract address, chain, source-verification link, alert meaning, safety warnings, and migration information. Other official channels link back to it. Wallets, explorers, search results, reposts, direct messages, prices, liquidity, copied source, and matching metadata are not authentication.

Official messaging must state:

> CHECK AUGUR REP MIGRATION is a non-economic on-chain alert. It is not REP, migrated REP, replacement REP, a claim, or an asset with value. Receiving it performs no migration, grants no right, and requires no action. MIGRATEREP refers to the migration subject; it is not REP or an instruction to perform migration. Hiding the alert through wallet controls is acceptable where available. An active holder may optionally burn only their own unit directly through the verified canonical contract, but burning is not required, provides no migration or economic benefit, and cannot erase transaction history, events, permanent alert history, or cached records.

Tell users not to approve, transfer, swap, bridge, claim, deposit, sign, use a third-party burn site, or connect a wallet because of the alert. Nobody can burn another recipient's alert. Direct users to navigate independently to official Augur sources. Do not promise wallet display or describe validation or review as an audit.

## Incidents and corrections

For an issuance, key, manifest, publication, address, chain, link, description, or explorer incident:

1. stop distribution and scheduled communications;
2. notify the designated deployment, security, and communications owners;
3. preserve manifests, unsigned artifacts, transactions, logs, screenshots, and the timeline without exposing secrets;
4. reconcile the current on-chain and publication state;
5. correct or replace the canonical official page first, then propagate the correction to every official channel;
6. submit an Etherscan correction through its current official process when applicable;
7. evaluate emergency finalization when legitimate authority control remains; and
8. resume only after independent verification and human approval.

Never present burn as an incident remedy. It cannot reverse issuance, authenticate a deployment, or correct public records.

## Permanent records

Retain the chain and contract address; deployment transaction, block, timestamp, and deployer; source commit and build settings; constructor arguments; bytecode and artifact hashes; authority and cap; source-verification state; manifests and checksums; every calldata payload and transaction; events and counter reconciliations; finalization state; Etherscan submissions and corrections; official publication evidence; incident records; and confirmation that agents accessed no key and signed or broadcast no transaction.
