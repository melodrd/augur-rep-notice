# Deployment Runbook

Status: Placeholder / unapproved

This runbook is reserved for future human-controlled deployment preparation. It does not authorize deployment, signing, transaction submission, RPC access, or Safe operation. The draft [product specification](../product/SPEC.md) and [threat model](../security/THREAT_MODEL.md) must be approved before this checklist becomes operational.

## Document approval

- [ ] Approved specification
- [ ] Approved threat model
- [ ] Approved release gates
- [ ] Independent code review
- [ ] Independent recipient-data review
- [ ] Independent deployment-artifact review

## Candidate freeze

- [ ] Exact source commit recorded
- [ ] Compiler version recorded
- [ ] Optimizer settings recorded
- [ ] Dependency tags and commits recorded
- [ ] Creation bytecode hash recorded
- [ ] Runtime bytecode hash recorded
- [ ] Constructor arguments recorded

## Environment verification

- [ ] Network name confirmed
- [ ] Chain ID confirmed
- [ ] Snapshot block confirmed
- [ ] Intended authority confirmed
- [ ] Intended Safe confirmed
- [ ] Deployer role and removal plan confirmed

## Pre-deployment simulation

- [ ] Local checks passed
- [ ] Static-analysis findings reviewed
- [ ] Pinned fork simulation passed
- [ ] Gas assumptions reviewed
- [ ] Authority handoff simulated
- [ ] Distribution batches simulated
- [ ] Finalization simulated
- [ ] Post-finalization behavior simulated

## Unsigned artifact review

- [ ] Deployment target reviewed
- [ ] Constructor data reviewed
- [ ] Authority-transfer data reviewed
- [ ] Batch data reviewed
- [ ] Finalization data reviewed
- [ ] Safe simulation reviewed
- [ ] Checksums reviewed

## Human-controlled execution

- [ ] Human operators approved execution
- [ ] Human operators confirmed the network
- [ ] Human operators confirmed each target address
- [ ] Human operators signed and submitted
- [ ] Transaction records captured
- [ ] Source verification completed

## Distribution controls

- [ ] Canary recipients approved
- [ ] Stop conditions active
- [ ] Each batch checksum confirmed
- [ ] Each batch reconciled
- [ ] Cumulative supply reconciled
- [ ] Unexpected events investigated

## Finalization

- [ ] Every approved batch reconciled
- [ ] Final authority confirmed
- [ ] Maintainers approved irreversible finalization
- [ ] Finalization transaction recorded
- [ ] Further distribution confirmed impossible
- [ ] Existing balances confirmed preserved
- [ ] Transfers and approvals confirmed unavailable

## Post-deployment records

- [ ] Contract address recorded
- [ ] Deployment transaction recorded
- [ ] Deployment block recorded
- [ ] Source-verification status recorded
- [ ] Runtime bytecode rechecked
- [ ] Authority state rechecked
- [ ] Finalization state recorded
- [ ] Public verification material reviewed
