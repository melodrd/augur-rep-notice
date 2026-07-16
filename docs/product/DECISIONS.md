# Product and Architecture Decisions

Status: Approved for V2 implementation

Revision date: 2026-07-16

This document records the main design choices and trade-offs. Contract behavior is authoritative in the [product specification](SPEC.md).

| Decision | Reason | Rejected alternative | Main trade-off |
| --- | --- | --- | --- |
| The artifact is a non-economic REP migration alert | Keeps the experiment focused on communication and avoids creating rights or value | Replacement REP, claim, reward, governance, staking, or migration mechanism | Recipients and interfaces may still misunderstand or ignore it |
| Metadata is `CHECK AUGUR REP MIGRATION`, `MIGRATEREP`, and `0` decimals | The name directs recipients to independently check official Augur REP migration information; the symbol identifies the migration subject without claiming to be REP | The V1 metadata, replacement-token tickers, migration-effect wording, or configurable metadata | Metadata can be copied, truncated, hidden, or classified as spam |
| Metadata is compiled into the contract | Prevents deployment-time or post-deployment mutation | Constructor-configurable or mutable metadata | A metadata change requires a new reviewed candidate and deployment |
| The contract address is the canonical identity | Names, symbols, logos, source, and ABI can be copied | Treating metadata or third-party listings as authentication | Official publication and correction procedures must be disciplined |
| The interface is ERC-20-shaped but intentionally non-transferable | Familiar selectors and issuance events may improve tooling recognition | A transferable ERC-20, NFT, claim contract, or event-only design | Some interfaces may display unusable transfer or approval controls |
| The implementation is standalone and non-upgradeable | Keeps the callable surface and state machine small | OpenZeppelin token/ownership inheritance, proxies, modules, or generalized frameworks | Behavior must be implemented and reviewed directly |
| Initial supply is zero and active balances are binary | Each successful distribution creates exactly one active alert unit and no deployer inventory | Prefunded inventory, fractional units, or movable balances | A burned active balance becomes zero and therefore cannot alone prove whether the address was alerted |
| One private three-state status preserves alert history | `NeverAlerted`, `Active`, and `Burned` represent the only required states in one straightforward storage slot per address | Separate balance and receipt mappings, bit packing, assembly, mutable status APIs, or inferring history from current balance | The contract adds `wasAlerted`; a burn removes active balance but cannot erase permanent receipt history |
| `totalIssued` and `totalSupply` have distinct meanings | Permanent issuance and current active units must remain independently observable after burns | Treating current supply as all-time issuance or deriving issuance capacity from active balances | Operations must reconcile two counters and burn events |
| One array-based distribution path serves canaries and batches | Avoids divergent authorization, validation, cap, and event behavior | Separate single-recipient and batch functions or generic multicalls | A one-address canary still uses array calldata |
| Distribution is strictly atomic | Preserves deterministic manifest and state reconciliation | Partial success, silent skipping, or idempotent duplicates | One invalid entry blocks the complete batch |
| The cap exactly equals the final approved manifest count and applies to `totalIssued` | Provides the strongest meaningful permanent issuance bound and prevents burns from restoring headroom | A cap based on active `totalSupply`, mutable cap, discretionary margin, or unused headroom | A material recipient change after deployment may require redeployment |
| Maximum batch size is measurement-driven | Gas and calldata limits depend on candidate bytecode and chain conditions | An unbounded array or guessed constant | A conservative bound increases transaction count |
| The authority is one immutable constructor-supplied address | Avoids ownership, role, handoff, and recovery machinery | Ownable, role-based control, separate minter/finalizer, or replaceable authority | Wrong, lost, or compromised authority cannot be repaired in place |
| One dedicated project-owner EOA is the production authority | Matches the chosen single-person operating model and keeps contract administration simple | Multi-party control, an everyday wallet, shared custody, or delegated signing | Less authorization redundancy; key loss and compromise are accepted operational risks |
| The same dedicated EOA is expected to deploy and serve as authority | Removes an unnecessary production handoff while retaining explicit constructor authority | Requiring deployer and authority separation | Operators must preserve the distinction that deployment alone grants no privilege |
| Transfers, approvals, permits, and delegated destruction are unavailable; active holders may self-burn | Optional self-burn lets a recipient remove only their own active unit without creating movement, spender, authority-burn, or recovery powers | Transferable tokens, allowances, permit, `burn(uint256)`, `burnFrom`, authority burn, batch burn, signature burn, or burn-and-reissue | Active supply can decrease; burning has no migration or economic benefit and cannot erase history or third-party records |
| Finalization is explicit and irreversible and closes only issuance | Provides one auditable authority shutdown while preserving the holder's independent ability to remove an active unit | Automatic finalization, unfinalize, emergency mint, upgrade, or disabling holder burn after finalization | Premature finalization cannot be repaired; key loss may prevent finalization; active supply may decrease after finalization |
| Standard issuance and burn `Transfer` events plus one finalization event are used | Supports indexing and deterministic reconciliation with minimal event surface; finalization reports permanent `totalIssued` | Duplicate custom recipient events, a second supply event, or operator-supplied on-chain manifest hashes | Operations must distinguish mint, burn, final issuance, and current active supply in external records |
| The contract makes no external calls and has no intended ETH path | Avoids custody, dependency, reentrancy, recovery, and migration-integration risk | On-chain eligibility checks, REP calls, arbitrary executors, or withdrawal helpers | Exceptionally forced ETH is permanently unrecoverable |
| Etherscan is the only current third-party metadata surface | Provides one focused source-verification and metadata workflow without assuming broad interface support | Mandatory wallet matrices, tracker submissions, token-list work, or market-data listings in the current phase | Etherscan controls its display and review; broader visibility remains unknown |
| Independent review remains required | Self-review is insufficient for code, data, unsigned artifacts, and communications | Author-only approval or calling informal review an audit | Review adds time and does not prove absence of defects |

## Accepted authority risks

- Permanent EOA key loss can prevent further distribution and finalization. No replacement or recovery path exists.
- EOA compromise can cause wrong-recipient issuance within the remaining issuance capacity (`distributionCap - totalIssued`) or premature finalization. The cap limits quantity, not correctness.
- One project owner manually reviews and signs privileged transactions. The model does not provide multi-party authorization.

## Change control

Changes to metadata, authority, cap derivation, distribution, movement, approvals, burn, finalization, external interaction, upgradeability, or the alert’s public meaning require a specification revision before implementation.

This architecture has not received an independent security audit.

Browser and mobile wallets, portfolio trackers, token lists, CoinGecko, CoinMarketCap, and other market-data or asset-listing services are deferred for a later specification and operations review.
