# Product and Architecture Decisions

Status: Approved for implementation

This document records the main design choices and trade-offs. Contract behavior is authoritative in the [product specification](../product/SPEC.md).

| Decision | Reason | Rejected alternative | Main trade-off |
| --- | --- | --- | --- |
| The artifact is a non-economic REP migration alert | Keeps the experiment focused on communication and avoids creating rights or value | Replacement REP, claim, reward, governance, staking, or migration mechanism | Recipients and interfaces may still misunderstand or ignore it |
| Metadata is `REP MIGRATION ALERT`, `CHECKREP`, and `0` decimals | The name states the subject and urgency; the symbol prompts checking official information | Previous passive wording, replacement-token tickers, or configurable metadata | Metadata can be copied, truncated, hidden, or classified as spam |
| Metadata is compiled into the contract | Prevents deployment-time or post-deployment mutation | Constructor-configurable or mutable metadata | A metadata change requires a new reviewed candidate and deployment |
| The contract address is the canonical identity | Names, symbols, logos, source, and ABI can be copied | Treating metadata or third-party listings as authentication | Official publication and correction procedures must be disciplined |
| The interface is ERC-20-shaped but intentionally non-transferable | Familiar selectors and issuance events may improve tooling recognition | A transferable ERC-20, NFT, claim contract, or event-only design | Some interfaces may display unusable transfer or approval controls |
| The implementation is standalone and non-upgradeable | Keeps the callable surface and state machine small | OpenZeppelin token/ownership inheritance, proxies, modules, or generalized frameworks | Behavior must be implemented and reviewed directly |
| Initial supply is zero and balances are binary | A balance of one directly records successful issuance | Prefunded inventory, fractional units, movable balances, or a separate receipt mapping | The receipt remains permanently visible on-chain |
| One array-based distribution path serves canaries and batches | Avoids divergent authorization, validation, cap, and event behavior | Separate single-recipient and batch functions or generic multicalls | A one-address canary still uses array calldata |
| Distribution is strictly atomic | Preserves deterministic manifest and state reconciliation | Partial success, silent skipping, or idempotent duplicates | One invalid entry blocks the complete batch |
| The cap exactly equals the final approved manifest count | Provides the strongest meaningful issuance bound | Mutable cap, discretionary margin, or unused headroom | A material recipient change after deployment may require redeployment |
| Maximum batch size is measurement-driven | Gas and calldata limits depend on candidate bytecode and chain conditions | An unbounded array or guessed constant | A conservative bound increases transaction count |
| The authority is one immutable constructor-supplied address | Avoids ownership, role, handoff, and recovery machinery | Ownable, role-based control, separate minter/finalizer, or replaceable authority | Wrong, lost, or compromised authority cannot be repaired in place |
| One dedicated project-owner EOA is the production authority | Matches the chosen single-person operating model and keeps contract administration simple | Multi-party control, an everyday wallet, shared custody, or delegated signing | Less authorization redundancy; key loss and compromise are accepted operational risks |
| The same dedicated EOA is expected to deploy and serve as authority | Removes an unnecessary production handoff while retaining explicit constructor authority | Requiring deployer and authority separation | Operators must preserve the distinction that deployment alone grants no privilege |
| Transfers, approvals, permits, and burns are unavailable | The alert has no legitimate movement, spender, signature, or destruction use case | Standard token movement, allowances, permit, or burn-to-remove | Interfaces may expose actions that always fail; recipients cannot remove the balance |
| Finalization is explicit and irreversible | Provides one auditable shutdown state | Automatic finalization, unfinalize, emergency mint, or upgrade | Premature finalization cannot be repaired; key loss may prevent finalization |
| Standard issuance events and one finalization event are used | Supports indexing and deterministic reconciliation with minimal event surface | Duplicate custom recipient events or operator-supplied on-chain manifest hashes | Operations must keep disciplined external manifest records |
| The contract makes no external calls and has no intended ETH path | Avoids custody, dependency, reentrancy, recovery, and migration-integration risk | On-chain eligibility checks, REP calls, arbitrary executors, or withdrawal helpers | Exceptionally forced ETH is permanently unrecoverable |
| Independent review remains required | Self-review is insufficient for code, data, unsigned artifacts, and communications | Author-only approval or calling informal review an audit | Review adds time and does not prove absence of defects |

## Accepted authority risks

- Permanent EOA key loss can prevent further distribution and finalization. No replacement or recovery path exists.
- EOA compromise can cause wrong-recipient issuance within the remaining cap or premature finalization. The cap limits quantity, not correctness.
- One project owner manually reviews and signs privileged transactions. The model does not provide multi-party authorization.

## Change control

Changes to metadata, authority, cap derivation, distribution, movement, approvals, burn, finalization, external interaction, upgradeability, or the alert’s public meaning require a specification revision before implementation.

This architecture has not received an independent security audit.
