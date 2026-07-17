// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

import {MigrateRepV2Token} from "../src/MigrateRepV2Token.sol";

/// @title MigrateRepV2Token deployment script
/// @notice Deploys exactly one `MigrateRepV2Token` from two non-secret environment values.
///         The script embeds no network, account, key, RPC endpoint, secret, or production
///         address. It performs no distribution, transfer, approval, or finalization, deploys
///         no liquidity, and interacts with no router. Account selection, signing, and
///         broadcasting are supplied entirely by the human-run Foundry command.
/// @dev Reads only:
///        - `MREP2_DISTRIBUTOR`   : the sole address permitted to distribute or finalize;
///        - `MREP2_RECIPIENT_CAP` : the maximum number of unique initial recipients.
///      It never reads a private key, mnemonic, seed phrase, or keystore password, and never
///      calls `vm.startBroadcast(privateKey)`. The bare `vm.startBroadcast()` defers the
///      broadcasting account to the human-selected Foundry account mechanism.
contract DeployMigrateRepV2Token is Script {
    /// @notice Reverts when `MREP2_DISTRIBUTOR` resolves to the zero address.
    error MissingDistributor();

    /// @notice Reverts when `MREP2_RECIPIENT_CAP` resolves to zero.
    error MissingRecipientCap();

    /// @notice Reads the two non-secret environment values and deploys one token.
    /// @return token The freshly deployed token contract.
    function run() external returns (MigrateRepV2Token token) {
        address distributor = vm.envAddress("MREP2_DISTRIBUTOR");
        uint256 recipientCap = vm.envUint("MREP2_RECIPIENT_CAP");

        token = deploy(distributor, recipientCap);
    }

    /// @notice Validates the supplied arguments and deploys exactly one `MigrateRepV2Token`.
    /// @dev Both checks run before any broadcast preparation, so a misconfigured argument
    ///      fails without producing a signable transaction. The constructor enforces the same
    ///      nonzero invariants on-chain; these checks simply fail earlier with script-specific
    ///      errors and never weaken the on-chain checks.
    /// @param distributor The sole address permitted to distribute or finalize.
    /// @param recipientCap The maximum number of unique initial recipients.
    /// @return token The freshly deployed token contract.
    function deploy(address distributor, uint256 recipientCap) public returns (MigrateRepV2Token token) {
        if (distributor == address(0)) {
            revert MissingDistributor();
        }
        if (recipientCap == 0) {
            revert MissingRecipientCap();
        }

        vm.startBroadcast();
        token = new MigrateRepV2Token(distributor, recipientCap);
        vm.stopBroadcast();

        console2.log("MigrateRepV2Token deployed at:", address(token));
        console2.log("distributor:", token.distributor());
        console2.log("recipientCap:", token.recipientCap());
        console2.log("maximumSupply:", token.maximumSupply());
    }
}
