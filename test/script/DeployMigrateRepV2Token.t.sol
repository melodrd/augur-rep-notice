// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import {Test} from "forge-std/Test.sol";

import {MigrateRepV2Token} from "../../src/MigrateRepV2Token.sol";
import {DeployMigrateRepV2Token} from "../../script/DeployMigrateRepV2Token.s.sol";

contract DeployMigrateRepV2TokenTest is Test {
    DeployMigrateRepV2Token internal script;

    address internal constant DISTRIBUTOR = address(0xD1571B);
    uint256 internal constant CAP = 250;
    uint256 internal constant ONE = 1 ether;

    function setUp() public {
        script = new DeployMigrateRepV2Token();
    }

    function test_deploy_sets_exact_metadata() public {
        MigrateRepV2Token token = script.deploy(DISTRIBUTOR, CAP);
        assertEq(token.name(), "MIGRATE REPV2");
        assertEq(token.symbol(), "MREP2");
        assertEq(token.decimals(), 18);
    }

    function test_deploy_sets_exact_constructor_values() public {
        MigrateRepV2Token token = script.deploy(DISTRIBUTOR, CAP);
        assertEq(token.distributor(), DISTRIBUTOR);
        assertEq(token.recipientCap(), CAP);
    }

    function test_deploy_sets_exact_maximum_supply_and_reserve() public {
        MigrateRepV2Token token = script.deploy(DISTRIBUTOR, CAP);
        assertEq(token.maximumSupply(), CAP * ONE);
        assertEq(token.totalSupply(), CAP * ONE);
        assertEq(token.balanceOf(address(token)), CAP * ONE);
    }

    function test_deploy_gives_no_deployer_or_distributor_balance() public {
        MigrateRepV2Token token = script.deploy(DISTRIBUTOR, CAP);
        assertEq(token.balanceOf(DISTRIBUTOR), 0);
        assertEq(token.balanceOf(address(script)), 0);
        assertEq(token.balanceOf(address(this)), 0);
        assertEq(token.totalInitialRecipients(), 0);
        assertFalse(token.distributionFinalized());
    }

    function test_deploy_rejects_zero_distributor() public {
        vm.expectRevert(DeployMigrateRepV2Token.MissingDistributor.selector);
        script.deploy(address(0), CAP);
    }

    function test_deploy_rejects_zero_cap() public {
        vm.expectRevert(DeployMigrateRepV2Token.MissingRecipientCap.selector);
        script.deploy(DISTRIBUTOR, 0);
    }

    function test_no_post_deployment_mint_or_admin_selectors() public {
        MigrateRepV2Token token = script.deploy(DISTRIBUTOR, CAP);
        // None of these selectors exist; the contract has no fallback, so each call reverts.
        _assertNoFunction(token, abi.encodeWithSignature("mint(address,uint256)", DISTRIBUTOR, ONE));
        _assertNoFunction(token, abi.encodeWithSignature("burn(uint256)", ONE));
        _assertNoFunction(token, abi.encodeWithSignature("burnFrom(address,uint256)", DISTRIBUTOR, ONE));
        _assertNoFunction(token, abi.encodeWithSignature("owner()"));
        _assertNoFunction(token, abi.encodeWithSignature("pause()"));
        _assertNoFunction(
            token, abi.encodeWithSignature("permit(address,address,uint256,uint256,uint8,bytes32,bytes32)")
        );
    }

    function test_runtime_matches_direct_construction() public {
        MigrateRepV2Token viaScript = script.deploy(DISTRIBUTOR, CAP);
        MigrateRepV2Token direct = new MigrateRepV2Token(DISTRIBUTOR, CAP);
        assertEq(address(viaScript).code, address(direct).code);
    }

    function _assertNoFunction(MigrateRepV2Token token, bytes memory cd) internal {
        (bool ok,) = address(token).call(cd);
        assertFalse(ok);
    }
}
