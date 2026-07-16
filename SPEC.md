# Product Specification

## Document status

- Status: Initial decision record
- Milestone: Repository foundation only
- Approval: Required before production contract implementation
- Audit status: No independent security audit has occurred

## Confirmed assumptions

- The artifact is an informational notice only.
- It is not REP, migrated REP, a replacement token, a claim token, a reward, a governance asset, or a tradable instrument.
- It has no economic value and grants no migration, claim, or governance rights.
- A holder must never need to approve, sign, transfer, swap, burn, bridge, deposit, or claim anything because of the notice.
- The canonical migration process exists independently from this project.
- Users must independently navigate to official Augur surfaces and verify the canonical deployed contract address.
- Matching token names and symbols are not proof of authenticity.
- Each eligible recipient is expected to receive exactly one whole unit with `0` decimals.
- Ordinary transfers, `transferFrom`, approvals, operator approvals, and permits must be unavailable.
- Distribution and minting must become permanently impossible after irreversible finalization.
- The design has no upgrade mechanism, arbitrary external calls, payable functions, REP custody, ETH custody, withdrawal path, or recovery path.
- The repository uses Foundry for Solidity dependencies and Bun for TypeScript package management, runtime execution, and tests.

## Contract requirements

- Use the smallest auditable implementation that satisfies an approved specification.
- Reject the zero address and prevent duplicate notices.
- Ensure no address can hold more than one notice unit.
- Restrict distribution and finalization to the approved authority.
- Preserve deterministic batch behavior and verifiable supply accounting.
- Disable every token movement and approval path in contract logic.
- Make finalization explicit, authorized, irreversible, and permanent.
- Emit accurate distribution, finalization, and administrative-transition events.
- Expose only read methods required for verification.
- Avoid external calls, upgradeability, delegatecall, fallback functions, receive functions, assembly, and unbounded storage iteration.

## Operational requirements

- Snapshot and recipient rules must be deterministic, documented, tested, and reproducible.
- On-chain integer values must use `bigint` off chain.
- Addresses must be validated, normalized, deduplicated, and canonically sorted.
- Exclusions must have stable reason codes and reviewable reports.
- Production artifacts must include checksums and reconciliation data.
- Mainnet activity remains human-controlled; agents may not broadcast or submit Safe transactions.

## Non-goals

- Production contract implementation during the foundation milestone
- Recipient discovery, filtering, or REP balance queries during the foundation milestone
- Token trading, liquidity, pricing, yield, governance, staking, vesting, bridging, or composability
- Claim flows, wallet-connect flows, permit signatures, meta-transactions, callbacks, or hooks
- Proxies, upgradeability, delegatecall modules, diamonds, or generalized extension frameworks
- Frontend, database, Docker, or Python project scaffolding
- Marketing copy or promises about wallet visibility

## Unresolved maintainer decisions

- Final token name and symbol
- Whether any holder-controlled burn function exists
- Exact authority model and production Safe address
- REP contract addresses, versions, and universes in scope
- Definition of successful migration
- Snapshot block and holder-discovery method
- Minimum REP threshold
- Exchange, protocol, burn-address, and manual exclusions
- Canary recipient count and maximum batch size
- Finalization trigger and stop conditions
- Budget
- Canonical migration URL
- Public communications language
- Incident-response procedure and responsible owner

## Acceptance criteria for a future contract milestone

- Maintainers approve the product decisions above.
- Contract behavior matches this specification and `AGENTS.md`.
- Unit, fuzz, invariant, gas, coverage, and static-analysis checks are complete.
- Non-transferability, unique one-unit balances, authority, and irreversible finalization are demonstrated by tests.
- No RPC, deployment, wallet, key, or transaction behavior is introduced without explicit approval.
- Independent review occurs before any release gate is described as complete.
