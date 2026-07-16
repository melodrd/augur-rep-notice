# REP MIGRATION ALERT Messaging

Status: Approved for implementation

This document defines the required public meaning, safety language, publication hierarchy, and correction rules. It does not authorize publication or deployment.

## Canonical core message

> REP MIGRATION ALERT is a non-economic on-chain alert related to Augur REP migration. It is not REP, migrated REP, replacement REP, a claim, or an asset with value. Receiving it does not migrate REP and requires no interaction with the token. Do not approve, transfer, swap, burn, bridge, claim, sign, or connect a wallet because of it. CHECKREP means to check official REP migration information independently through the official Augur website. Verify the canonical contract address through official Augur sources.

Safety-critical statements must remain intact across official surfaces. Short posts may point to the canonical message but must not weaken its meaning.

## Meaning of receipt

Receiving one unit means only that the address was included in a reviewed campaign recipient set and the authority successfully issued one alert to it.

Receipt does not prove:

- current REP ownership;
- legal or beneficial ownership of the address;
- current migration eligibility;
- incomplete, successful, or failed migration;
- entitlement to REP or another asset;
- that a human controls the address;
- that the recipient saw or understood the alert.

The alert performs no migration and grants no rights or entitlement.

## Meaning of CHECKREP

```text
CHECKREP means:
Check official REP migration information.

CHECKREP does not mean:
Approve, transfer, swap, burn, claim, sign, or connect a wallet.
```

Official wording must pair the symbol with an instruction to check official Augur information independently. It must never treat the symbol as a replacement REP denomination or an instruction to interact with the alert.

## Required statements

Official material must:

- call the artifact an alert, migration alert, or on-chain alert;
- state that it is not REP, migrated REP, replacement REP, a claim, reward, redemption instrument, governance asset, or asset with value;
- state that receipt performs no migration and grants no right;
- state that no recipient interaction is required;
- tell users not to approve, transfer, swap, burn, bridge, claim, deposit, sign, or connect a wallet because of it;
- tell users to navigate independently to the official Augur website;
- identify the verified checksummed contract address as the only canonical on-chain identity;
- warn that fraudulent deployments can copy metadata, ABI, source, and branding;
- warn that third-party prices, liquidity, token lists, logos, links, or market presentation do not create authenticity or value;
- state that receipt does not prove current REP ownership or migration eligibility;
- use only independently reviewed links and addresses.

Official material must not:

- suggest that the alert itself migrates REP;
- imply that holding, buying, selling, transferring, approving, burning, or claiming it has a benefit;
- present it as a claim, redemption, recovery, bridge, staking, governance, or wallet-connect mechanism;
- instruct users to trust a wallet, explorer, search result, direct message, copied deployment, or shortened link;
- treat matching metadata, verified source, ABI shape, a price, or liquidity as authentication;
- place a migration URL in token metadata or contract storage;
- promise automatic wallet display, delivery to a person, or campaign success;
- describe independent review as an audit unless a formal audit occurs.

## Canonical identity and publication hierarchy

The deployed contract address, verified through official Augur sources, is the only canonical on-chain identity.

Before publishing an address, independently verify:

- network and chain ID;
- deployment transaction and checksummed address;
- runtime bytecode against the reviewed candidate;
- source-verification status;
- exact name, symbol, and decimals;
- immutable authority and cap;
- official page content and outbound links.

Publication order:

1. The official Augur website is the canonical source.
2. The canonical page publishes the verified address, chain, source-verification link, alert meaning, safety warning, and migration information.
3. Other official channels link back to that page.
4. Corrections are made on the canonical page first and then propagated.

Screenshots, reposts, direct messages, community summaries, search results, wallets, token lists, and third-party interfaces are not canonical sources.

## Current third-party scope

Etherscan is the only third-party metadata surface currently in scope. Source verification, metadata, logo, evidence, and correction work follows the
[Etherscan runbook](../operations/ETHERSCAN_RUNBOOK.md).

Etherscan approval, display, and review timing are not guaranteed. The official Augur website and verified checksummed contract address remain canonical.

Browser and mobile wallets, portfolio trackers, token lists, CoinGecko, CoinMarketCap, and other market-data or asset-listing services are deferred for a later specification and operations review. No wallet-product matrix or submission to those services is currently approved, and no current release gate depends on their inclusion.

No claim is made that wallets will automatically display the alert.

## Corrections and incidents

When an address, chain, link, description, or safety statement is wrong or suspected to be compromised:

1. Stop scheduled publication and rollout communications.
2. Notify the responsible project, deployment, and communications owners.
3. Correct or temporarily replace the canonical page with a clear warning.
4. Propagate the correction to every official channel.
5. Preserve the incorrect material and correction timeline.
6. Never tell users to interact with the alert as a remedy.
7. Resume only after independent verification and human approval.

Communications cannot reverse issued alerts. Authority compromise, manifest misuse, or unexpected issuance also activates the deployment runbook’s incident procedure.

## Deferred publication values

The exact official Augur page URL and exact contract address remain deferred until the page and deployment exist and are independently verified. Do not publish placeholders or prose-derived addresses.
