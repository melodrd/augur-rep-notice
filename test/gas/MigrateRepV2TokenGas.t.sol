// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import {Test, Vm} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";

import {MigrateRepV2Token} from "../../src/MigrateRepV2Token.sol";

/// @title Isolated gas measurements for MigrateRepV2Token
/// @notice Kept separate from the ordinary suite. Each measurement uses fresh contracts and
///         cold recipient state. Reported figures are:
///           - "exec"  : execution gas of the call frame (vm.lastCallGas().gasTotalUsed);
///           - "cdGas" : EIP-2028 calldata gas (4 per zero byte, 16 per nonzero byte);
///           - "osaka" : full transaction gas
///                       21000 + max(cdGas + exec, 10 * tokens), tokens = cdGas / 4.
///         Successful distribution recipients use all-nonzero address bytes for the worst case.
contract MigrateRepV2TokenGas is Test {
    // OR mask forcing every address byte nonzero (worst-case calldata).
    uint160 private constant ONES = uint160(0x0101010101010101010101010101010101010101);
    address private constant DISTRIBUTOR = address(0xD1571B);
    uint256 private constant ONE = 1 ether;

    function _worstRecipients(uint256 n, uint256 seed) internal pure returns (address[] memory a) {
        a = new address[](n);
        for (uint256 i = 0; i < n; ++i) {
            a[i] = address(uint160(uint256(keccak256(abi.encode(seed, i)))) | ONES);
        }
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

    function test_gas_deployment() public {
        uint256 g0 = gasleft();
        MigrateRepV2Token token = new MigrateRepV2Token(DISTRIBUTOR, 100000);
        uint256 used = g0 - gasleft();
        assertGt(address(token).code.length, 0);
        console2.log("deployment (measured create gas):", used);
    }

    function test_gas_distribution_batches() public {
        uint256[7] memory sizes = [uint256(1), 10, 25, 50, 100, 150, 200];
        for (uint256 s = 0; s < sizes.length; ++s) {
            uint256 n = sizes[s];
            MigrateRepV2Token token = _fresh();
            address[] memory r = _worstRecipients(n, s + 1);
            bytes memory cd = abi.encodeCall(MigrateRepV2Token.distribute, (r));

            vm.prank(DISTRIBUTOR);
            token.distribute(r);
            uint256 exec = vm.lastCallGas().gasTotalUsed;

            string memory label = string.concat("distribute batch=", vm.toString(n));
            _report(label, exec, cd);
        }
    }

    function test_gas_standard_transfer() public {
        MigrateRepV2Token token = _fresh();
        address alice = address(0xA11CE);
        address[] memory r = new address[](1);
        r[0] = alice;
        vm.prank(DISTRIBUTOR);
        token.distribute(r);

        bytes memory cd = abi.encodeCall(token.transfer, (address(0xB0B), ONE));
        vm.prank(alice);
        token.transfer(address(0xB0B), ONE);
        _report("transfer (cold recipient)", vm.lastCallGas().gasTotalUsed, cd);
    }

    function test_gas_zero_transfer() public {
        MigrateRepV2Token token = _fresh();
        address alice = address(0xA11CE);
        bytes memory cd = abi.encodeCall(token.transfer, (address(0xB0B), 0));
        vm.prank(alice);
        token.transfer(address(0xB0B), 0);
        _report("transfer (zero value)", vm.lastCallGas().gasTotalUsed, cd);
    }

    function test_gas_approval() public {
        MigrateRepV2Token token = _fresh();
        address alice = address(0xA11CE);
        bytes memory cd = abi.encodeCall(token.approve, (address(0xB0B), ONE));
        vm.prank(alice);
        token.approve(address(0xB0B), ONE);
        _report("approve", vm.lastCallGas().gasTotalUsed, cd);
    }

    function test_gas_transferFrom_finite() public {
        MigrateRepV2Token token = _fresh();
        address alice = address(0xA11CE);
        address bob = address(0xB0B);
        address[] memory r = new address[](1);
        r[0] = alice;
        vm.prank(DISTRIBUTOR);
        token.distribute(r);
        vm.prank(alice);
        token.approve(bob, 5 * ONE);

        bytes memory cd = abi.encodeCall(token.transferFrom, (alice, bob, ONE));
        vm.prank(bob);
        token.transferFrom(alice, bob, ONE);
        _report("transferFrom (finite allowance)", vm.lastCallGas().gasTotalUsed, cd);
    }

    function test_gas_transferFrom_max() public {
        MigrateRepV2Token token = _fresh();
        address alice = address(0xA11CE);
        address bob = address(0xB0B);
        address[] memory r = new address[](1);
        r[0] = alice;
        vm.prank(DISTRIBUTOR);
        token.distribute(r);
        vm.prank(alice);
        token.approve(bob, type(uint256).max);

        bytes memory cd = abi.encodeCall(token.transferFrom, (alice, bob, ONE));
        vm.prank(bob);
        token.transferFrom(alice, bob, ONE);
        _report("transferFrom (max allowance)", vm.lastCallGas().gasTotalUsed, cd);
    }

    function test_gas_finalization() public {
        MigrateRepV2Token token = _fresh();
        bytes memory cd = abi.encodeCall(token.finalizeDistribution, ());
        vm.prank(DISTRIBUTOR);
        token.finalizeDistribution();
        _report("finalizeDistribution", vm.lastCallGas().gasTotalUsed, cd);
    }

    // ---- representative failures (measured via low-level call) ----

    function _measureRevert(MigrateRepV2Token token, address caller, bytes memory cd, string memory label) internal {
        vm.prank(caller);
        (bool ok,) = address(token).call(cd);
        assertFalse(ok);
        _report(label, vm.lastCallGas().gasTotalUsed, cd);
    }

    function test_gas_unauthorized_distribution() public {
        MigrateRepV2Token token = _fresh();
        bytes memory cd = abi.encodeCall(MigrateRepV2Token.distribute, (_worstRecipients(1, 1)));
        _measureRevert(token, address(0xBAD), cd, "distribute (unauthorized)");
    }

    function test_gas_empty_batch() public {
        MigrateRepV2Token token = _fresh();
        address[] memory empty = new address[](0);
        bytes memory cd = abi.encodeCall(MigrateRepV2Token.distribute, (empty));
        _measureRevert(token, DISTRIBUTOR, cd, "distribute (empty batch)");
    }

    function test_gas_oversized_batch() public {
        MigrateRepV2Token token = _fresh();
        bytes memory cd = abi.encodeCall(MigrateRepV2Token.distribute, (_worstRecipients(201, 1)));
        _measureRevert(token, DISTRIBUTOR, cd, "distribute (201 oversized)");
    }

    function test_gas_cap_overflow() public {
        MigrateRepV2Token token = new MigrateRepV2Token(DISTRIBUTOR, 100);
        bytes memory cd = abi.encodeCall(MigrateRepV2Token.distribute, (_worstRecipients(101, 1)));
        // 101 > MAX_BATCH_SIZE(200)? no; 101 <= 200, and 101 > cap 100 -> cap error.
        _measureRevert(token, DISTRIBUTOR, cd, "distribute (cap overflow)");
    }

    function test_gas_late_duplicate() public {
        MigrateRepV2Token token = _fresh();
        address[] memory r = _worstRecipients(200, 5);
        r[199] = r[0]; // duplicate at the final index
        bytes memory cd = abi.encodeCall(MigrateRepV2Token.distribute, (r));
        _measureRevert(token, DISTRIBUTOR, cd, "distribute (duplicate at final index)");
    }

    function test_gas_late_zero_recipient() public {
        MigrateRepV2Token token = _fresh();
        address[] memory r = _worstRecipients(200, 6);
        r[199] = address(0); // zero at the final index
        bytes memory cd = abi.encodeCall(MigrateRepV2Token.distribute, (r));
        _measureRevert(token, DISTRIBUTOR, cd, "distribute (zero at final index)");
    }
}
