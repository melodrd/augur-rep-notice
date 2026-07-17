# CHECK AUGUR REP MIGRATION

CHECK AUGUR REP MIGRATION is a minimal, non-economic on-chain alert. The authority may issue one
non-transferable unit to each approved address. Holders may optionally burn their own unit. The contract does not
migrate REP, grant rights, or interact with REP or a migration contract.

## Purpose and status

The alert directs selected addresses to independently check official Augur REP migration information. Receiving it
requires no action and does not establish REP ownership, migration eligibility, or control of an address.

The core contract is implemented and locally validated. No production deployment exists. Recipient selection,
deployment tooling, and live-chain rehearsal remain separate review stages.

## Non-goals

The contract provides no:

- REP custody, approval, transfer, migration, claim, redemption, reward, or governance right;
- transfer, transfer-from, approval, permit, operator, or delegated-burn path;
- owner, role system, authority transfer, successor, recovery administrator, proxy, or upgrade;
- payable function, withdrawal, token recovery, callback, hook, bridge, oracle, or arbitrary call;
- pricing, liquidity, tax, staking, yield, vesting, rebasing, or other economic behavior.

## Fixed metadata

| Property | Value |
| --- | --- |
| Name | CHECK AUGUR REP MIGRATION |
| Symbol | MIGRATEREP |
| Decimals | 0 |
| Unit per recipient | 1 |
| Initial supply | 0 |

Metadata is compiled into the contract. Only the checksummed deployed address published through official Augur
sources can identify a canonical deployment.

## Contract behavior

| Area | Behavior |
| --- | --- |
| Construction | Requires one nonzero immutable authority and one nonzero immutable lifetime cap |
| Distribution | Authority-only, atomic array issuance before finalization |
| Batch ceiling | Hard compile-time maximum of 500 recipients |
| Recipient eligibility | Zero, duplicate, active, and previously burned addresses revert the complete batch |
| Balance | Always zero or one |
| Self-burn | An active holder may permanently remove only their own unit |
| Finalization | Authority-only, explicit, irreversible, and permanently closes issuance |
| Movement | Transfers and approvals always revert; allowance is always zero |

Operational batches should normally contain about 100–200 recipients for easier review, signing, monitoring, and
reconciliation even though the contract ceiling is 500.

## Recipient lifecycle

~~~text
NeverAlerted -> Active -> Burned
~~~

NeverAlerted addresses have balance zero and no receipt history. Active addresses have balance one. Burned addresses
have balance zero but retain permanent receipt history and can never be issued again.

## Supply accounting

- totalIssued is the number of unique addresses ever successfully alerted. It only increases.
- totalSupply is the number of active, unburned units. It increases on distribution and decreases on self-burn.
- wasAlerted(address) remains true after burn.
- The lifetime cap applies to totalIssued; burning never restores issuance capacity.

The invariant is:

~~~text
totalSupply <= totalIssued <= distributionCap
~~~

## Public interface

Reads expose fixed metadata, MAX_BATCH_SIZE, authority, distributionCap, finalized, totalIssued, totalSupply,
balanceOf, wasAlerted, and zero allowance.

State-changing calls are limited to:

- distribute(address[]) for authority-controlled atomic issuance;
- burn() for holder-only self-burn;
- finalize() for irreversible authority-controlled closure.

ERC-20-shaped transfer, transferFrom, and approve selectors exist only to revert explicitly.

## Validation and gas

The local suite covers direct behavior, exact errors and events, fuzz properties, stateful invariants, isolated gas
measurements, ABI and storage inspection, production coverage, compiler diagnostics, and Slither.

Current isolated measurements show approximately 24,787 total Osaka gas per additional recipient and approximately
12.46 million total gas for a successful 500-recipient batch. Normal operations prefer smaller batches. Exact current
deployment, distribution, burn, finalization, bytecode-size, and transaction-margin evidence is recorded in
[docs/VALIDATION.md](docs/VALIDATION.md).

Validation is evidence for reviewed local paths; it is not an audit or proof that vulnerabilities are absent.

## Local commands

~~~bash
make check
forge test -vvv
forge test --gas-report
FOUNDRY_SNAPSHOTS=/tmp/rep-alert-snapshot-values \
  forge snapshot --snap /tmp/rep-alert-gas.snapshot
~~~

The canonical build uses Solidity 0.8.36, EVM Osaka, optimizer enabled with 200 runs, and via IR disabled.

## Repository layout

~~~text
src/            production Solidity
test/           unit, fuzz, invariant, helper, and gas tests
ops/            Bun and TypeScript operational tooling
docs/SPEC.md    authoritative contract behavior
docs/OPERATIONS.md  deployment, recipient, and communications controls
docs/VALIDATION.md  current evidence and remaining work
~~~

## Next step

The next stage is minimal deployment tooling and a controlled Sepolia rehearsal after the relevant human approvals.
That stage must use a separate test-only authority, unsigned review artifacts, simulation, and exact reconciliation.

No task in this repository authorizes mainnet deployment, production-key access, signing, submission, or broadcast.
