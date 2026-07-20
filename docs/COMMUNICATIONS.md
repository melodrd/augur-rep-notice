# Communications

Public-facing material for CHECKAUGUR: explorer and wallet metadata, and user messaging. It gives an accurate, neutral account of what the token does and does not do. Contract behavior is in [SPEC.md](SPEC.md); operating the contract is in [OPERATIONS.md](OPERATIONS.md).

Nothing here is submitted from this repository. Prepare and review the material; a human publishes it under a separate task. Do not invent missing values — leave placeholders.

## Token description

> CHECK AUGUR MIGRATION (CHECKAUGUR) is a fixed-supply ERC-20 notice token. One token is distributed to each selected address. CHECKAUGUR does not perform REP migration or grant any claim, redemption, governance, or financial right.

## Authentication

A specific deployment is identified by its verified, checksummed contract address and that address's on-chain source verification — not by appearance. Matching name, symbol, source, ABI, price, or branding is not authentication, and neither are wallets, explorers, search results, reposts, direct messages, or copied source.

## User messaging

Tell users plainly:

- receiving CHECKAUGUR requires no action;
- do not approve, transfer, swap, bridge, claim, deposit, sign, or connect a wallet because of it;
- reach any website by navigating to it yourself, not by following a link from the token, a message, or a search result;
- any market price is third-party and implies no project endorsement.

Do not promise automatic wallet display, and do not describe testing or review as an audit.

## Explorer and wallet metadata package

Prepare this reviewable, non-secret package for eventual explorer and wallet submissions.

```text
contract address    : <checksummed address, after deployment>
official website    : https://augur.net
official migration  : https://6.augurfork.eth.limo/#/migration
logo                : https://raw.githubusercontent.com/AugurProject/docs/master/static/img/augur-logo/REPv2%20Icon/REPv2%20Icon%20-%20Full%20Color%20over%20Black.png
token description   : the description above
source repository   : <if public>
```

The package must state: exact name `CHECK AUGUR MIGRATION`, symbol `CHECKAUGUR`, decimals `18`; fixed maximum supply with no post-deployment minting; no taxes, blacklist, or pause; no owner or roles; no upgradeability; no project-supported liquidity or price; that the token performs no migration; and that receiving it requires no wallet connection, approval, swap, claim, bridge, or payment.
