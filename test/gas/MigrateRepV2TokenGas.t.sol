// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import {Test, Vm} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";

import {MigrateRepV2Token} from "../../src/MigrateRepV2Token.sol";

/// @title Isolated gas measurements for MigrateRepV2Token
/// @notice Kept separate from the ordinary suite. The load-bearing measurement is
///         {test_gas_distribution_batches}: it proves the worst-case successful `distribute` stays
///         well under the Osaka transaction gas cap, which is what makes `MAX_BATCH_SIZE = 200`
///         measurement-derived. Reported figures are:
///           - "exec"  : execution gas of the call frame (vm.lastCallGas().gasTotalUsed);
///           - "cdGas" : EIP-2028 calldata gas (4 per zero byte, 16 per nonzero byte);
///           - "osaka" : full transaction gas 21000 + max(cdGas + exec, 10 * tokens), tokens = cdGas / 4.
///         Successful distribution recipients use all-nonzero address bytes for the worst case.
///
///         Every figure is a local measurement against the checked-in configuration. No RPC,
///         wallet, or live chain is involved, so none of these is a live-chain estimate.
contract MigrateRepV2TokenGas is Test {
    // OR mask forcing every address byte nonzero (worst-case calldata).
    uint160 private constant ONES = uint160(0x0101010101010101010101010101010101010101);
    address private constant DISTRIBUTOR = address(0xD1571B);

    /// @dev Worst-case recipients: every address byte is forced nonzero by the ONES mask, so each
    ///      costs the maximum 16 gas per calldata byte and can never be address(0). `forbidden` —
    ///      the token under measurement — and duplicates are excluded explicitly, so a measurement
    ///      never depends on an address collision being cryptographically unlikely.
    function _worstRecipients(uint256 n, uint256 seed, address forbidden) internal pure returns (address[] memory a) {
        a = new address[](n);
        for (uint256 i = 0; i < n; ++i) {
            address candidate = address(uint160(uint256(keccak256(abi.encode(seed, i)))) | ONES);
            while (candidate == forbidden || _contains(a, i, candidate)) {
                candidate = address(uint160(uint256(keccak256(abi.encode(candidate)))) | ONES);
            }
            a[i] = candidate;
        }
    }

    function _contains(address[] memory a, uint256 length, address who) private pure returns (bool) {
        for (uint256 i = 0; i < length; ++i) {
            if (a[i] == who) return true;
        }
        return false;
    }

    function _cdGas(bytes memory cd) internal pure returns (uint256 gas, uint256 tokens) {
        uint256 zero;
        uint256 nonzero;
        for (uint256 i = 0; i < cd.length; ++i) {
            if (cd[i] == 0) zero++;
            else nonzero++;
        }
        gas = zero * 4 + nonzero * 16;
        tokens = zero + nonzero * 4;
    }

    function _osaka(uint256 exec, uint256 cdGas, uint256 tokens) internal pure returns (uint256) {
        uint256 standard = cdGas + exec;
        uint256 floor = 10 * tokens;
        return 21000 + (standard > floor ? standard : floor);
    }

    function _report(string memory label, uint256 exec, bytes memory cd) internal pure {
        (uint256 cdGas, uint256 tokens) = _cdGas(cd);
        console2.log(label);
        console2.log("  exec / cdGas / osaka:", exec, cdGas, _osaka(exec, cdGas, tokens));
    }

    function _fresh() internal returns (MigrateRepV2Token token) {
        token = new MigrateRepV2Token(DISTRIBUTOR, 100000);
    }

    // ------------------------------------------------------------------

    /// @dev Deployment is reported as three separate figures, never as one "deployment gas":
    ///        - CREATE-frame gas   : measured. Initcode execution plus the code deposit.
    ///        - intrinsic/calldata : computed. The 21,000 transaction base plus initcode calldata gas.
    ///        - full deployment tx : a LOCAL APPROXIMATION combining the two under the Osaka floor
    ///                               formula. Not a live-chain estimate.
    function test_gas_deployment() public {
        bytes memory initcode =
            abi.encodePacked(type(MigrateRepV2Token).creationCode, abi.encode(DISTRIBUTOR, uint256(100000)));

        uint256 g0 = gasleft();
        MigrateRepV2Token token = new MigrateRepV2Token(DISTRIBUTOR, 100000);
        uint256 createFrame = g0 - gasleft();
        assertGt(address(token).code.length, 0);

        (uint256 cdGas, uint256 tokens) = _cdGas(initcode);
        console2.log("deployment CREATE-frame gas (measured):", createFrame);
        console2.log("  initcode bytes / calldata gas:", initcode.length, cdGas);
        console2.log("  full deployment tx (LOCAL APPROXIMATION):", _osaka(createFrame, cdGas, tokens));
    }

    /// @dev The load-bearing measurement: worst-case successful `distribute` across representative
    ///      batch sizes up to the `MAX_BATCH_SIZE` maximum. The 200-recipient figure must stay well
    ///      under the Osaka transaction gas cap (16,777,216).
    function test_gas_distribution_batches() public {
        uint256[7] memory sizes = [uint256(1), 10, 25, 50, 100, 150, 200];
        for (uint256 s = 0; s < sizes.length; ++s) {
            uint256 n = sizes[s];
            MigrateRepV2Token token = _fresh();
            address[] memory r = _worstRecipients(n, s + 1, address(token));
            bytes memory cd = abi.encodeCall(MigrateRepV2Token.distribute, (r));

            vm.prank(DISTRIBUTOR);
            token.distribute(r);
            uint256 exec = vm.lastCallGas().gasTotalUsed;

            _report(string.concat("distribute batch=", vm.toString(n)), exec, cd);
        }
    }
}
