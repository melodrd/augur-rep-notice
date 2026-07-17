// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.36;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

import {RepMigrationAlert} from "../src/RepMigrationAlert.sol";

/// @title RepMigrationAlert deployment script
/// @notice Deploys exactly one `RepMigrationAlert` from operator-supplied environment
///         configuration. The script embeds no network, account, key, RPC endpoint,
///         secret, or production address, performs no distribution or finalization, and
///         contains no generic arbitrary-call behavior. Account selection, signing, and
///         broadcasting are supplied entirely by the human-run Foundry command.
/// @dev Reads only two non-secret values from the environment:
///      - `ALERT_AUTHORITY`: the sole address permitted to distribute or finalize;
///      - `DISTRIBUTION_CAP`: the immutable lifetime issuance cap.
///      It never reads a private key, mnemonic, seed phrase, or keystore password, and
///      never calls `vm.startBroadcast(privateKey)`. The bare `vm.startBroadcast()` defers
///      the broadcasting account to the human-selected Foundry account mechanism.
contract DeployRepMigrationAlert is Script {
    /// @notice Reverts when `ALERT_AUTHORITY` resolves to the zero address.
    error MissingAlertAuthority();

    /// @notice Reverts when `DISTRIBUTION_CAP` resolves to zero.
    error MissingDistributionCap();

    /// @notice Reads the two non-secret environment values and deploys one
    ///         `RepMigrationAlert`. This is the entry point invoked by `forge script`.
    /// @return alert The freshly deployed alert contract.
    function run() external returns (RepMigrationAlert alert) {
        address authority = vm.envAddress("ALERT_AUTHORITY");
        uint256 distributionCap = vm.envUint("DISTRIBUTION_CAP");

        alert = deploy(authority, distributionCap);
    }

    /// @notice Validates the supplied arguments and deploys exactly one
    ///         `RepMigrationAlert` with the authority and cap passed explicitly.
    /// @dev Both checks run before any broadcast preparation, so a misconfigured
    ///      argument fails without producing a signable transaction. The constructor
    ///      enforces the same nonzero invariants on-chain; these checks simply fail
    ///      earlier with script-specific errors and never weaken the on-chain checks.
    /// @param authority The sole address permitted to distribute or finalize.
    /// @param distributionCap The immutable lifetime issuance cap.
    /// @return alert The freshly deployed alert contract.
    function deploy(address authority, uint256 distributionCap) public returns (RepMigrationAlert alert) {
        if (authority == address(0)) {
            revert MissingAlertAuthority();
        }
        if (distributionCap == 0) {
            revert MissingDistributionCap();
        }

        vm.startBroadcast();
        alert = new RepMigrationAlert(authority, distributionCap);
        vm.stopBroadcast();

        console2.log("RepMigrationAlert deployed at:", address(alert));
        console2.log("authority:", authority);
        console2.log("distributionCap:", distributionCap);
    }
}
