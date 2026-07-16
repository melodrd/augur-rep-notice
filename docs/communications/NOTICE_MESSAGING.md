# REP Migration Notice Messaging Policy

## Document status

| Field | Value |
| --- | --- |
| Status | Approved canonical communications policy |
| Approval basis | The repository maintainer explicitly authorized the communications decisions recorded here |
| Approval date | 2026-07-16 |
| Scope | Public meaning, safety language, canonical identity, publication hierarchy, and communications release gates |
| Audit status | Not audited |

This policy defines the minimum language and publication controls for every official description of the REP Migration Notice. It does not authorize publication, deployment, wallet interaction, signing, or transaction submission.

## Canonical core message

> Augur REP Migration Notice is a non-economic notice intended to raise awareness of official REP migration information. It is not REP, migrated REP, replacement REP, a claim, or an asset with value. Receiving it does not migrate REP and grants no rights. Do not approve, transfer, swap, burn, bridge, claim, or connect a wallet because of this notice. Verify the canonical contract address and migration information through the official Augur website, and navigate there independently.

The core message must be reproduced verbatim across official surfaces. Supplemental short posts may point to it, but they must not replace, paraphrase away, or weaken any safety-critical sentence.

## Approved meaning

Receiving one notice unit means only:

> The address was included in a reviewed recipient set for an Augur REP migration-awareness campaign, and the notice authority successfully issued one notice to that address.

Receipt does not prove:

- current REP ownership;
- legal or beneficial ownership of the address;
- current migration eligibility;
- incomplete, successful, or failed migration;
- entitlement to REP or another asset;
- that a human controls the address;
- that the recipient saw or understood the notice.

The notice itself performs no migration and is not required for migration.

## Mandatory communications rules

Every official surface must:

- call the artifact a **notice**;
- state that it is not REP, migrated REP, replacement REP, a claim, reward, redemption instrument, governance asset, or asset with value;
- state that receiving it performs no migration and grants no right or entitlement;
- state that no recipient action is required;
- tell users not to approve, transfer, swap, burn, bridge, claim, deposit, sign for, or connect a wallet because of the notice;
- tell users to navigate independently to the official Augur website;
- identify the verified contract address as the only canonical on-chain identity;
- warn that fraudulent deployments may copy the exact name, symbol, interface, source, and branding;
- warn that third-party price data, liquidity, token lists, logos, links, or market presentation do not indicate authenticity or value;
- describe wallet visibility as an empirical observation, never a guarantee;
- use only independently reviewed links and addresses.

Official communications must never:

- call the notice migrated REP or imply that it replaces REP;
- imply that holding, buying, selling, transferring, approving, or burning it has a benefit;
- present it as a migration, claim, redemption, recovery, staking, governance, bridge, or wallet-connect mechanism;
- instruct users to trust a link displayed by a wallet, explorer, token list, search result, direct message, or copied deployment;
- treat matching metadata, verified source, ABI shape, a price listing, or a liquidity pool as authentication;
- place a migration URL in token metadata or contract storage;
- promise automatic wallet display, awareness, delivery to a person, or campaign success;
- describe independent review as a formal audit unless a formal audit has actually occurred.

## Canonical identity and verification

The deployed contract address, verified through official Augur surfaces, is the only canonical on-chain identity.

Before publishing an address, reviewers must independently verify:

- the network and chain ID;
- the deployment transaction and contract address;
- source-verification status;
- runtime bytecode against the reviewed candidate;
- exact name, symbol, and decimals;
- immutable authority and issuance cap;
- the canonical page content and every outbound link.

Names, symbols, logos, interfaces, verified source, and copied bytecode are not sufficient identity evidence by themselves. Communications must not publish a placeholder, guessed, unverified, or prose-derived address.

## Publication hierarchy

1. The official Augur website page is the canonical source.
2. The canonical page publishes the independently verified contract address, chain, source-verification link, notice meaning, safety warning, and official migration information.
3. X, Discord, Farcaster, and other official channels point back to the canonical page rather than becoming independent sources of contract details.
4. Pinned or persistent warnings are used where impersonation, copied-token, or malicious-link risk is high.
5. Every channel uses the approved core message and consistent address and chain information.
6. A correction is made first on the canonical page and then propagated to every other official channel.

Screenshots, reposts, direct messages, community summaries, search results, wallet metadata, token lists, and third-party explorers are not canonical sources.

## Channel guidance

### Official website

The canonical page must provide:

- the full core message;
- the verified contract address in unambiguous copyable text;
- the network and chain ID;
- a source-verification link;
- a plain-language explanation of what receipt does and does not mean;
- a warning that identical metadata and copied source do not prove authenticity;
- a warning that price data or liquidity does not create legitimacy or value;
- official migration information that does not require interaction with the notice;
- the publication date and a visible correction or update record;
- instructions to navigate independently to official Augur surfaces.

### Social and community channels

Posts must:

- lead with the notice-only meaning rather than a ticker or token image;
- point to the canonical official page;
- avoid shortened links where practical;
- avoid urgency, scarcity, reward, price, or claim language;
- warn users that moderators and maintainers will not request approval, signatures, seed phrases, private keys, swaps, transfers, burns, bridges, claims, or wallet connections;
- keep a pinned or persistent warning while impersonation risk is active.

### Wallets, explorers, and portfolio interfaces

Observed third-party presentation must not be repeated as an official claim. Test records should distinguish:

- automatic visibility from manual import;
- interface-supplied price or liquidity data from official information;
- transfer and approval affordances from actual contract behavior;
- spam classification from authenticity;
- displayed links and descriptions from reviewed official links.

If a third-party interface presents misleading information, official materials should document the limitation and direct users back to the canonical page.

## Corrections and incidents

When an address, chain, link, or safety statement is wrong or suspected to be compromised:

1. Stop scheduled publication and rollout communications.
2. Treat the issue as an incident and notify the repository maintainer, deployment operator, and communications maintainer.
3. Correct or temporarily replace the canonical page with a clear warning.
4. Propagate the correction to every official channel.
5. Preserve the incorrect material and correction timeline for review.
6. Do not tell users to interact with the notice as a remedy.
7. Resume publication only after independent verification and maintainer approval.

Communications cannot reverse an issued notice. If the incident also concerns controller compromise, manifest misuse, or unexpected issuance, the deployment runbook's emergency-finalization process applies.

## Independent communications review

Before public Sepolia communication and again before mainnet deployment, a reviewer other than the author of the final copy must verify:

- the complete notice-only meaning;
- the canonical address, chain, and official links;
- consistency across official surfaces;
- the absence of approval, signature, swap, transfer, burn, bridge, claim, deposit, and wallet-connect instructions;
- the copied-metadata, price-data, liquidity, and impersonation warnings;
- the absence of wallet-visibility guarantees;
- that no audit claim is made without an actual audit.

Review completion must be recorded. Self-review alone does not satisfy the gate.

## Deferred publication gates

### Canonical official page URL

Status: **DEFERRED WITH GATE**

| Requirement | Approved rule |
| --- | --- |
| Why deferred | The official page does not yet exist, so its URL and control cannot be responsibly asserted. |
| Owner | Communications maintainer |
| Required evidence | A live official Augur page, verified site control, approved core message, independently checked links, correction process, and repository-maintainer approval. |
| Decision rule | Approve only the official page containing the verified address, chain, source-verification link, notice meaning, safety warning, and migration information. |
| Resolution phase | Before any public Sepolia communication |
| Release gate blocked | Public Sepolia communication and every mainnet deployment gate |

### Canonical contract address publication

Status: **DEFERRED WITH GATE**

| Requirement | Approved rule |
| --- | --- |
| Why deferred | No approved deployment exists. |
| Owner | Communications maintainer, using independently reviewed deployment records |
| Required evidence | Correct chain, deployment transaction, checksummed address, matching runtime bytecode, source verification, immutable settings, and independent review. |
| Decision rule | Publish only the address that exactly matches the approved deployment record and reviewed candidate. |
| Resolution phase | After the corresponding Sepolia or mainnet deployment is independently verified |
| Release gate blocked | Public address announcement |

### Wallet-product communications matrix

Status: **DEFERRED WITH GATE**

| Requirement | Approved rule |
| --- | --- |
| Why deferred | Wallet and portfolio relevance and behavior may change before Sepolia testing. |
| Owner | Communications maintainer |
| Required evidence | A current product-selection rationale and a test plan covering at least two browser wallets, two mobile wallets, one portfolio tracker, one explorer, one spam-filtering interface, and one manual-import interface. |
| Decision rule | Select the exact products immediately before testing while satisfying every approved category. |
| Resolution phase | Sepolia test planning |
| Release gate blocked | Wallet-display test completion and any public claim about observed presentation |

## Change control

The core message and safety rules are approved product behavior. Any proposed wording that adds economic meaning, requires recipient interaction, weakens canonical-address verification, adds a token-attached URL, or implies guaranteed wallet visibility requires an explicit product-specification revision and maintainer approval.
