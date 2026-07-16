# Etherscan Runbook

Status: Approved post-deployment workflow; non-operational

Etherscan is the only third-party metadata surface currently in scope. The official Augur website and the independently verified checksummed contract address remain canonical.

This runbook does not guarantee source verification, profile approval, metadata display, logo display, review timing, or continued availability. Exact submission forms, asset requirements, account-verification requirements, and review procedures must be checked against current official Etherscan instructions after deployment because they may change.

Do not invent a submission URL or assume a current process before that review.

## 1. Objectives

- Verify the contract source.
- Expose the correct ABI.
- Display the correct contract name where supported.
- Display the exact token name `CHECK AUGUR REP MIGRATION`.
- Display the exact symbol `MIGRATEREP`.
- Display decimals `0`.
- Associate the verified official Augur website where supported.
- Submit a reviewed logo where supported.
- Provide an accurate non-economic description.
- Correct incorrect metadata, links, or assets.
- Preserve evidence of submissions, responses, and corrections.

## 2. Preconditions

- [ ] Deployment is independently verified on the intended chain
- [ ] Checksummed contract address is confirmed
- [ ] Deployment transaction and block are recorded
- [ ] Source commit and candidate artifacts are frozen
- [ ] Compiler version and settings are recorded
- [ ] Constructor arguments are independently decoded
- [ ] Deployed runtime bytecode matches the reviewed candidate
- [ ] Exact ABI is recorded
- [ ] On-chain name is `CHECK AUGUR REP MIGRATION`
- [ ] On-chain symbol is `MIGRATEREP`
- [ ] On-chain decimals are `0`
- [ ] Immutable authority and cap are confirmed
- [ ] `totalIssued`, active `totalSupply`, and representative `wasAlerted` reads are confirmed
- [ ] Finalization state is confirmed
- [ ] Official Augur page and approved description are ready
- [ ] Current official Etherscan instructions have been reviewed
- [ ] Required submitting account or organizational role is approved

Stop when any source, bytecode, metadata, address, chain, link, or account requirement differs from the reviewed record.

## 3. Source and ABI verification

- [ ] Use the exact frozen source
- [ ] Use the exact compiler version and settings
- [ ] Use the exact constructor arguments
- [ ] Record verification submission date and status
- [ ] Record the resulting verification URL
- [ ] Confirm the displayed source matches the frozen source
- [ ] Confirm the displayed ABI matches the approved ABI
- [ ] Confirm the ABI includes only the approved `burn()`, `totalIssued()`, and `wasAlerted(address)` additions
- [ ] Confirm `burn(uint256)`, `burnFrom`, authority burn, delegated burn, and generalized burn helpers are absent
- [ ] Compare deployed runtime bytecode directly with the reviewed runtime hash
- [ ] Do not rely on Etherscan verification status as the sole bytecode check
- [ ] Preserve errors, responses, and resubmission history

## 4. Metadata package

Prepare only reviewed information:

- checksummed contract address;
- chain;
- exact token name `CHECK AUGUR REP MIGRATION`;
- exact symbol `MIGRATEREP`;
- decimals `0`;
- official Augur website URL;
- approved non-economic description;
- approved logo source and checksum, when a logo is supported;
- source-verification URL;
- submitting account or role.

Approved concise description:

> CHECK AUGUR REP MIGRATION is a non-economic on-chain alert directing recipients to independently check official
> Augur REP migration information. It is not REP, migrated REP, replacement REP, a claim, or an asset with value.
> Receiving it performs no migration and requires no action. An active holder may optionally self-burn only their own
> unit directly through the verified canonical contract, but burning is not required and provides no migration or
> economic benefit. Never use a third-party burn website, approval, signature, or wallet-connect flow.

Do not add trading, price, liquidity, reward, claim, migration-effect, urgency, wallet-connect, or interaction language
beyond the approved optional direct holder self-burn wording.

## 5. Logo controls

Do not create or submit a logo until the current Etherscan requirements are reviewed.

Any future logo must:

- come from an approved Augur brand source;
- be reviewed for correct brand use;
- be exported in the dimensions and format required at submission time;
- have a recorded cryptographic checksum;
- be stored in a reviewed repository or official brand location;
- contain no QR code;
- contain no wallet or contract address;
- contain no shortened URL;
- contain no claim instruction;
- contain no wallet-connect prompt.

Record the original source, reviewer, export settings, final path or official location, and checksum.

## 6. Submission and evidence register

Record:

| Field | Required record |
| --- | --- |
| Chain | Network name and chain ID |
| Contract | Checksummed address |
| Deployment | Transaction hash and block |
| Source | Commit or tag |
| Compiler | Version and complete settings |
| Constructor | Arguments and encoded data |
| Verification | Status and Etherscan URL |
| Runtime | Reviewed hash and direct match result |
| ABI | Approved ABI and displayed match result |
| Name | Exact on-chain value |
| Symbol | Exact on-chain value |
| Decimals | Exact on-chain value |
| Authority | Immutable checksummed EOA |
| Cap | Immutable distribution cap |
| Total issued | Permanent count of unique addresses ever alerted |
| Active supply | Current count of active, unburned units |
| Alert history | Representative `wasAlerted` verification and burn-event reconciliation |
| Finalization | Current finalized state |
| Website | Approved official Augur URL |
| Description | Approved submitted text |
| Logo | Approved source, export, location, and checksum |
| Submission | Date and submitting account or role |
| Status | Pending, accepted, rejected, or correction required |
| Response | Etherscan response or ticket record |
| History | Corrections and resubmissions |

Do not record private keys, seed phrases, recovery phrases, raw keystores, or secret environment values.

## 7. Post-submission review

- [ ] Source-verification page loads and identifies the correct chain and contract
- [ ] Source, compiler, constructor data, and ABI are correct
- [ ] Runtime bytecode still matches the reviewed candidate
- [ ] Displayed name is `CHECK AUGUR REP MIGRATION` where supported
- [ ] Displayed symbol is `MIGRATEREP` where supported
- [ ] Displayed decimals are `0`
- [ ] Website points to the approved official Augur page where supported
- [ ] Description is accurate and non-economic
- [ ] Logo is the reviewed asset where supported
- [ ] No incorrect claim, price implication, migration effect, or interaction instruction appears
- [ ] Any optional burn wording requires the exact canonical contract, states that burn is holder-only and optional,
      and makes no migration, economic, or history-erasure claim
- [ ] Any third-party price, liquidity, or market presentation is treated as non-canonical
- [ ] Evidence screenshots or records are preserved with dates

Etherscan controls its interface and review decisions. Unsupported or rejected optional metadata does not change the contract’s canonical identity.

## 8. Correction process

When a displayed field, link, description, or logo is incorrect:

1. Identify the incorrect field.
2. Preserve a screenshot or record.
3. Verify the correct source information.
4. Submit the correction through the current official Etherscan process.
5. Record the request and response.
6. Update the canonical Augur page first if the official source itself is incorrect.
7. Never tell users to interact with the alert as a correction mechanism.

Record every correction and resubmission. Do not treat silence, pending status, or an interface cache as approval.

## 9. Completion

The Etherscan workflow is complete only when:

- source, ABI, and runtime evidence are recorded;
- required on-chain metadata is correct;
- submitted optional metadata is reviewed for accuracy;
- current status and responses are preserved;
- known incorrect fields have an open or completed correction record;
- official Augur sources continue to publish the canonical checksummed address and safety wording.

Browser and mobile wallets, portfolio trackers, token lists, CoinGecko, CoinMarketCap, and other market-data or asset-listing services are deferred for a later specification and operations review. No current release gate depends on their inclusion.
