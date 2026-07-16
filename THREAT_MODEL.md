# Threat Model

## Status and scope

This is an initial threat inventory for a foundation-only repository. No production contract or recipient pipeline exists, and this project has not received an independent security audit.

## Contract risks

- Unauthorized distribution or minting
- Finalization bypass or reversal
- Accidental transferability or inherited approval behavior
- Duplicate distribution and incorrect total-supply accounting
- Hidden administrative powers or authority misconfiguration
- Unexpected external calls, REP interaction, ETH custody, upgradeability, or delegatecall
- Compiler, dependency, or override behavior differing from reviewed assumptions

## Recipient-data risks

- Incorrect REP contract address, snapshot block, or chain
- Incomplete holder discovery or unavailable historical state
- Malformed, zero, duplicate, or non-canonical addresses
- Incorrect migration-status evaluation
- Eligible holders excluded or ineligible holders included
- Exchange and protocol addresses misclassified
- Floating-point balance handling
- Non-deterministic output, manual artifact edits, or checksum mismatch
- RPC inconsistency or archive-node failure

## Deployment risks

- Wrong network, contract bytecode, constructor values, authority, or Safe
- Dependency or compiler mismatch between reviewed and deployed builds
- Repeated, skipped, reordered, or oversized batches
- Nonce conflicts, gas spikes, transaction replacement, or incomplete reconciliation
- Premature finalization or failure to finalize
- Source-verification or runtime-bytecode mismatch

## Communications and scam risks

- Holders mistake the notice for REP, migrated REP, or an asset with value
- Wallets hide, truncate, mislabel, or attach incorrect price data to the notice
- Scammers copy the name and symbol or create fake liquidity
- Users follow a malicious migration link shown by an interface
- Public materials omit or misstate the canonical contract address
- Wallet visibility is treated as guaranteed rather than empirically tested

## Administrative risks

- Compromised deployer, Safe signer, or operational workstation
- Authority handed to the wrong address
- Temporary deployer privilege remains after handoff
- Multiple or overlapping administrator systems obscure control
- Finalization decision lacks independent reconciliation and approval

## Assumptions

- Maintainers will approve token semantics, authority, recipient rules, and communications before implementation.
- Production control will use an Augur-controlled Safe rather than a personal hot wallet.
- Mainnet signing, submission, and broadcast remain human-controlled.
- Dependencies, compiler settings, artifacts, and recipient inputs remain pinned and reviewable.
- Users do not need to interact with the notice to migrate REP.

## Unresolved threats

- Exact wallet-display behavior across supported interfaces
- Exact phishing and impersonation mitigations in public communications
- Exact Safe signer and incident-response model
- Exact snapshot completeness and migration-detection methodology
- Exact gas-safe batch limit and canary stop conditions
- Exact treatment of contracts, exchanges, protocols, and custody addresses
