# Deployment

Release procedure for `MigrateRepV2Token` (MREP2). Contract behavior is defined in [SPEC.md](SPEC.md); validation evidence is in [VALIDATION.md](VALIDATION.md); recipient preparation and distribution are in [OPERATIONS.md](OPERATIONS.md).

This document assumes familiarity with Ethereum, Foundry, RPC endpoints, contract verification, and hardware-wallet or multisig signing. It covers a single production deployment: one `CREATE` of one token contract. It authorizes nothing on its own — signing and broadcasting are performed by a human under a separate, explicitly approved task.

## Preconditions

Every item must hold before a mainnet transaction is prepared:

- source frozen at a reviewed commit, with a clean working tree;
- `make check`, `make check-deep`, `make coverage`, and `make gas` passing on that commit;
- a recipient manifest approved under [OPERATIONS.md](OPERATIONS.md), with its derived `recipientCap`;
- `MREP2_RECIPIENT_CAP` set to that exact derived count — never chosen independently, never given headroom;
- the production `distributor` selected and confirmed to be neither the zero address nor the predicted token address;
- the deployment account funded and controlled by the project owner;
- compiler, EVM target, optimizer, and dependency pins reviewed against `foundry.toml` and `foundry.lock`;
- the target chain confirmed, including that it is at or past the EVM version in `foundry.toml` (`osaka`).

## Immutable deployment inputs

These are fixed at construction and can never be changed afterward. A wrong value is corrected only by discarding the deployment and redeploying.

```text
distributor        constructor argument; sole address that may distribute or finalize
recipientCap       constructor argument; maximum unique initial recipients
maximumSupply      derived: recipientCap * 1e18, minted once to the token contract
contract bytecode  fixed by source + compiler settings + dependency pins
token metadata     name "MIGRATE REPV2", symbol "MREP2", decimals 18
```

`distributor` and `recipientCap` are the only two inputs the operator supplies. Everything else is fixed by the source. The deploying account — the keystore account that signs the `CREATE`, chosen with `--account` — is a separate decision from `distributor`: the two may be the same address but need not be, and deploying by itself confers no distribution authority, only what the constructor assigns to `distributor`.

## Build and artifact freeze

Build from the frozen commit and record the artifacts the deployment and verification will be checked against.

```bash
forge clean && forge build
git rev-parse HEAD
forge inspect MigrateRepV2Token bytecode         | cut -c3- | xxd -r -p | sha256sum   # creation bytecode
forge inspect MigrateRepV2Token deployedBytecode | cut -c3- | xxd -r -p | sha256sum   # runtime bytecode (immutables zeroed)
forge inspect MigrateRepV2Token abi
forge inspect MigrateRepV2Token storageLayout
forge inspect MigrateRepV2Token methodIdentifiers
```

Every bytecode hash in this repository is taken over the raw decoded bytecode bytes, never over the printed hex string: `cut -c3-` strips the `0x` prefix and `xxd -r -p` converts the hex text to bytes before `sha256sum`. Hashing the printed hex string instead yields a different, non-comparable digest.

The runtime bytecode reported by `forge inspect deployedBytecode` has the three immutables (`distributor`, `recipientCap`, `maximumSupply`) zeroed. On-chain runtime code has them populated, so its hash will not equal this artifact hash — see [Source verification](#source-verification). The creation-bytecode hash is independent of constructor arguments and is the stable build identifier.

## Environment

The deployment reads two non-secret arguments and one RPC endpoint. Verification adds an explorer key.

```text
MREP2_DISTRIBUTOR    non-secret   the approved distributor address
MREP2_RECIPIENT_CAP  non-secret   the manifest's exact derived recipient count
MAINNET_RPC_URL      sensitive    endpoint; keep in the shell or an untracked .env
ETHERSCAN_API_KEY    sensitive    explorer verification key
```

`MREP2_DISTRIBUTOR` and `MREP2_RECIPIENT_CAP` are consumed by the script and may appear in review artifacts. `MAINNET_RPC_URL` and `ETHERSCAN_API_KEY` are secret-adjacent: keep them in the shell or a git-ignored `.env`, never in a tracked file. No private key, mnemonic, or keystore password is ever placed in the environment — signing is supplied through Foundry's keystore.

```bash
export MREP2_DISTRIBUTOR="0x..."
export MREP2_RECIPIENT_CAP="..."
export MAINNET_RPC_URL="..."
```

Confirm the endpoint is the intended chain before anything else: `cast chain-id` (expect `1` for Ethereum mainnet).

## Simulation

Simulate against the target chain without broadcasting. This resolves the constructor, runs the script's own zero-argument checks, and reports the address the deployment would produce. Pass the same `--account` as the broadcast so the simulation's sender — and therefore the predicted `CREATE` address and nonce — matches the account that will actually deploy. No key is used and nothing is broadcast.

```bash
forge script script/DeployMigrateRepV2Token.s.sol:DeployMigrateRepV2Token \
  --rpc-url "$MAINNET_RPC_URL" \
  --account <keystore-account> \
  -vvvv
```

Confirm the logged `distributor`, `recipientCap`, and `maximumSupply` equal the approved values before proceeding.

## Deployment

Broadcast with a keystore account. The signing key is selected by Foundry and never appears on the command line.

```bash
forge script script/DeployMigrateRepV2Token.s.sol:DeployMigrateRepV2Token \
  --rpc-url "$MAINNET_RPC_URL" \
  --account <keystore-account> \
  --broadcast --verify
```

The script calls `vm.startBroadcast()` with no key, deferring the account entirely to `--account`. It performs one `CREATE` and no distribution, transfer, approval, or finalization.

The deployment account (the keystore account passed to `--account`) signs and pays for the `CREATE`. The distributor is the immutable constructor argument that alone may later distribute or finalize. They are separate roles: they may be the same address, but nothing requires that, and deploying grants the deployment account no token balance or authority beyond what the constructor assigns to `distributor`. Whichever account deploys must be dedicated and controlled by the project owner — not a shared or everyday wallet. Humans alone hold, sign with, and monitor these accounts; the repository and its tooling never touch key material.

## Immediate post-deployment verification

Read the live contract directly and confirm each value before treating the deployment as canonical. Any mismatch is a stop condition.

| Getter | Expected |
| --- | --- |
| `name()` | `MIGRATE REPV2` |
| `symbol()` | `MREP2` |
| `decimals()` | `18` |
| `TOKEN_PER_RECIPIENT()` | `1000000000000000000` |
| `MAX_BATCH_SIZE()` | `200` |
| `distributor()` | approved distributor |
| `recipientCap()` | approved cap |
| `maximumSupply()` | `recipientCap * 1e18` |
| `totalSupply()` | `maximumSupply()` |
| `balanceOf(token)` | `maximumSupply()` |
| `totalInitialRecipients()` | `0` |
| `distributionFinalized()` | `false` |

```bash
cast call <token> "distributor()(address)"              --rpc-url "$MAINNET_RPC_URL"
cast call <token> "recipientCap()(uint256)"             --rpc-url "$MAINNET_RPC_URL"
cast call <token> "maximumSupply()(uint256)"            --rpc-url "$MAINNET_RPC_URL"
cast call <token> "totalSupply()(uint256)"              --rpc-url "$MAINNET_RPC_URL"
cast call <token> "balanceOf(address)(uint256)" <token> --rpc-url "$MAINNET_RPC_URL"
cast call <token> "totalInitialRecipients()(uint256)"   --rpc-url "$MAINNET_RPC_URL"
cast call <token> "distributionFinalized()(bool)"       --rpc-url "$MAINNET_RPC_URL"
```

## Source verification

Verify against the exact frozen build:

```text
compiler          0.8.36
optimizer         enabled, 200 runs
via-ir            disabled
evm version       osaka
constructor args  abi.encode(distributor, recipientCap)
```

`--verify` during broadcast submits these automatically when `ETHERSCAN_API_KEY` is set; otherwise run `forge verify-contract` with the same settings and `--constructor-args $(cast abi-encode "constructor(address,uint256)" <distributor> <recipientCap>)`.

Because the contract has immutables, verify the deployment rather than hashing runtime code against the artifact:

- the explorer's source verification reconstructs and matches immutables from the metadata, so a successful verification is the authoritative match;
- to check bytes independently, compare the deployment transaction's input data against the frozen creation bytecode followed by the ABI-encoded constructor arguments;
- a `sha256` of on-chain runtime code will not equal the `deployedBytecode` artifact hash — the immutables differ — so treat the two as distinct hashes, not as a direct match.

The distribution plan binds to the deployed token's on-chain runtime bytecode hash (`--runtime-bytecode-sha256`, see [OPERATIONS.md](OPERATIONS.md)). Compute it over the raw bytecode bytes returned by `cast code`, not the printed hex string:

```bash
cast code <token> --rpc-url "$MAINNET_RPC_URL" | cut -c3- | xxd -r -p | sha256sum
```

`cut -c3-` strips the `0x` prefix and `xxd -r -p` decodes the hex text to bytes before `sha256sum`. Prefix the resulting digest with `sha256:` when passing it to the plan. Because this hash covers the on-chain runtime with immutables populated, it differs by design from the zeroed-immutable `deployedBytecode` artifact hash in [VALIDATION.md](VALIDATION.md).

Record the submission date, submitting role, verification link, displayed ABI and metadata, and status. Explorer display is never a canonical identity and never a substitute for a direct bytecode check.

## Stop conditions

Halt, preserve evidence, and escalate to the responsible humans if any of the following holds. Do not work around it.

- a required approval or funded/controlled account is missing;
- source, compiler settings, dependency pins, chain, distributor, cap, or constructor data differs from the reviewed artifact;
- `MREP2_RECIPIENT_CAP` is not exactly the approved manifest's derived count;
- the predicted or deployed token address appears in the recipient list;
- the distributor is the zero address or the token contract's own address;
- simulation, deployment, verification, or any post-deployment getter does not match expectation;
- an unexplained transaction, address, nonce, or balance appears;
- any action would expose a key, seed phrase, keystore, or secret.
