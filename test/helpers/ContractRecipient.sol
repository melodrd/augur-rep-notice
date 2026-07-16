// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.36;

import {RepMigrationAlert} from "../../src/RepMigrationAlert.sol";

/// @notice Minimal deployed-code recipient used to prove contracts are valid recipients.
contract ContractRecipient {
    /// @notice Burns this contract's active alert unit.
    function burnAlert(RepMigrationAlert alert) external {
        alert.burn();
    }
}
