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
- [ ] Immutable authority argument recorded
- [ ] Immutable distribution-cap argument and evidence recorded

## Environment verification

- [ ] Network name confirmed
- [ ] Chain ID confirmed
- [ ] Snapshot block confirmed
- [ ] Intended immutable authority confirmed
- [ ] Deployer and authority separation confirmed
- [ ] Deployer receives no implicit contract privilege

## Future authority and controller review

These are unapproved future deployment gates. They do not establish a controller address or approve a Safe configuration.

- [ ] Intended chain confirmed
- [ ] Immutable authority address confirmed
- [ ] Authority address checksum independently reviewed
- [ ] Controller type documented
- [ ] Safe address confirmed, if applicable
- [ ] Safe owners verified, if applicable
- [ ] Safe threshold verified, if applicable
- [ ] Signer independence assessed
- [ ] Enabled modules reviewed
- [ ] Guard configuration reviewed
- [ ] Fallback handler reviewed
- [ ] Signer key-storage method reviewed
- [ ] Recovery plan documented
- [ ] Dedicated-purpose use confirmed
- [ ] Unrelated assets and protocol activity reviewed
- [ ] Constructor arguments independently reviewed
- [ ] Deployer and authority separation reviewed
- [ ] Issuance-cap value and supporting evidence reviewed
- [ ] Controller transaction simulation reviewed
- [ ] Finalization authority and procedure reviewed

## Pre-deployment simulation

- [ ] Local checks passed
- [ ] Static-analysis findings reviewed
- [ ] Pinned fork simulation passed
- [ ] Gas assumptions reviewed
- [ ] Immutable authority constructor configuration simulated
- [ ] Distribution-cap boundary behavior simulated
- [ ] Distribution batches simulated
- [ ] Finalization simulated
- [ ] Post-finalization behavior simulated

## Unsigned artifact review

- [ ] Deployment target reviewed
- [ ] Constructor data reviewed
- [ ] Batch data reviewed
- [ ] Finalization data reviewed
- [ ] Controller transaction simulation reviewed
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
- [ ] Immutable authority confirmed
- [ ] Maintainers approved irreversible finalization
- [ ] Finalization transaction recorded
- [ ] Further distribution confirmed impossible
- [ ] Existing balances confirmed preserved
- [ ] Transfers and approvals confirmed unavailable
- [ ] Final supply reconciled against the immutable distribution cap
- [ ] Authority remains readable but has no effective contract power

## Post-deployment records

- [ ] Contract address recorded
- [ ] Deployment transaction recorded
- [ ] Deployment block recorded
- [ ] Source-verification status recorded
- [ ] Runtime bytecode rechecked
- [ ] Authority state rechecked
- [ ] Distribution-cap state rechecked
- [ ] Finalization state recorded
- [ ] Public verification material reviewed
