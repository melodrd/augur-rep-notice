// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.36;

import {Test} from "forge-std/Test.sol";

import {DeployRepMigrationAlert} from "../../script/DeployRepMigrationAlert.s.sol";
import {RepMigrationAlert} from "../../src/RepMigrationAlert.sol";

/// @notice Exercises the deployment script without RPC access or on-chain broadcasting.
/// @dev The script's bare `vm.startBroadcast()` resolves to the default Foundry sender
///      (`DEFAULT_SENDER`) under `forge test`, so these tests deploy locally and inspect
///      the resulting contract.
///
///      Most tests call `deploy(authority, cap)` directly with explicit arguments. Only
///      `test_RunReadsConfigurationFromEnvironment` exercises `run()`, which reads the
///      process-global `ALERT_AUTHORITY`/`DISTRIBUTION_CAP` variables; keeping env reads
///      to a single test avoids races with Foundry's parallel in-suite execution.
///
///      These tests intentionally do not duplicate the full contract behavior suite in
///      `test/RepMigrationAlert.t.sol`; they prove the script wires the supplied
///      configuration into an unchanged candidate.
contract DeployRepMigrationAlertTest is Test {
    address internal constant AUTHORITY = address(0xA11CE);
    address internal constant RECIPIENT = address(0x1001);
    uint256 internal constant DISTRIBUTION_CAP = 250;

    DeployRepMigrationAlert internal deployScript;

    function setUp() public {
        deployScript = new DeployRepMigrationAlert();
    }

    function test_DeploysWithSuppliedAuthorityStoredExactly() public {
        RepMigrationAlert alert = deployScript.deploy(AUTHORITY, DISTRIBUTION_CAP);

        assertEq(alert.authority(), AUTHORITY);
    }

    function test_DeploysWithSuppliedCapStoredExactly() public {
        RepMigrationAlert alert = deployScript.deploy(AUTHORITY, DISTRIBUTION_CAP);

        assertEq(alert.distributionCap(), DISTRIBUTION_CAP);
    }

    function test_DeployedMetadataIsExact() public {
        RepMigrationAlert alert = deployScript.deploy(AUTHORITY, DISTRIBUTION_CAP);

        assertEq(alert.name(), "CHECK AUGUR REP MIGRATION");
        assertEq(alert.symbol(), "MIGRATEREP");
        assertEq(alert.decimals(), 0);
        assertEq(alert.MAX_BATCH_SIZE(), 500);
    }

    function test_DeployedInitialCountersAreZero() public {
        RepMigrationAlert alert = deployScript.deploy(AUTHORITY, DISTRIBUTION_CAP);

        assertEq(alert.totalIssued(), 0);
        assertEq(alert.totalSupply(), 0);
    }

    function test_DeployedStartsUnfinalized() public {
        RepMigrationAlert alert = deployScript.deploy(AUTHORITY, DISTRIBUTION_CAP);

        assertFalse(alert.finalized());
    }

    function test_DeployerReceivesNoImplicitAuthorityWhenDifferentAuthoritySupplied() public {
        // The script deploys via `vm.startBroadcast()`, whose default sender is DEFAULT_SENDER.
        assertTrue(AUTHORITY != DEFAULT_SENDER);
        RepMigrationAlert alert = deployScript.deploy(AUTHORITY, DISTRIBUTION_CAP);

        assertEq(alert.authority(), AUTHORITY);
        assertEq(alert.balanceOf(DEFAULT_SENDER), 0);
        assertFalse(alert.wasAlerted(DEFAULT_SENDER));

        // The deployer cannot distribute or finalize; only the supplied authority can.
        address[] memory recipients = new address[](1);
        recipients[0] = RECIPIENT;
        vm.prank(DEFAULT_SENDER);
        vm.expectRevert(abi.encodeWithSelector(RepMigrationAlert.UnauthorizedCaller.selector, DEFAULT_SENDER));
        alert.distribute(recipients);

        vm.prank(DEFAULT_SENDER);
        vm.expectRevert(abi.encodeWithSelector(RepMigrationAlert.UnauthorizedCaller.selector, DEFAULT_SENDER));
        alert.finalize();
    }

    function test_RevertWhen_AuthorityIsZero() public {
        // A zero authority must fail before a usable deployment exists.
        vm.expectRevert(DeployRepMigrationAlert.MissingAlertAuthority.selector);
        deployScript.deploy(address(0), DISTRIBUTION_CAP);
    }

    function test_RevertWhen_DistributionCapIsZero() public {
        // A zero cap must fail before a usable deployment exists.
        vm.expectRevert(DeployRepMigrationAlert.MissingDistributionCap.selector);
        deployScript.deploy(AUTHORITY, 0);
    }

    function test_RunReadsConfigurationFromEnvironment() public {
        // The only test that touches the process-global environment, proving `run()`
        // wires `ALERT_AUTHORITY`/`DISTRIBUTION_CAP` into the deployed contract exactly.
        vm.setEnv("ALERT_AUTHORITY", vm.toString(AUTHORITY));
        vm.setEnv("DISTRIBUTION_CAP", vm.toString(DISTRIBUTION_CAP));

        RepMigrationAlert alert = deployScript.run();

        assertEq(alert.authority(), AUTHORITY);
        assertEq(alert.distributionCap(), DISTRIBUTION_CAP);
        assertEq(alert.totalIssued(), 0);
        assertEq(alert.totalSupply(), 0);
        assertFalse(alert.finalized());
    }

    function test_DeployedRuntimeBytecodeMatchesCandidate() public {
        RepMigrationAlert deployed = deployScript.deploy(AUTHORITY, DISTRIBUTION_CAP);
        // A direct construction with identical arguments embeds identical immutables, so
        // equal runtime bytecode proves the script deploys the unchanged candidate.
        RepMigrationAlert candidate = new RepMigrationAlert(AUTHORITY, DISTRIBUTION_CAP);

        assertEq(address(deployed).code, address(candidate).code);
    }

    function test_DeployedRuntimeBehaviorMatchesCandidate() public {
        RepMigrationAlert alert = deployScript.deploy(AUTHORITY, DISTRIBUTION_CAP);

        // Authority-only atomic issuance.
        address[] memory recipients = new address[](1);
        recipients[0] = RECIPIENT;
        vm.prank(AUTHORITY);
        alert.distribute(recipients);
        assertEq(alert.balanceOf(RECIPIENT), 1);
        assertTrue(alert.wasAlerted(RECIPIENT));
        assertEq(alert.totalIssued(), 1);
        assertEq(alert.totalSupply(), 1);

        // Holder-only self-burn.
        vm.prank(RECIPIENT);
        alert.burn();
        assertEq(alert.balanceOf(RECIPIENT), 0);
        assertTrue(alert.wasAlerted(RECIPIENT));
        assertEq(alert.totalIssued(), 1);
        assertEq(alert.totalSupply(), 0);

        // Movement stays disabled.
        vm.prank(RECIPIENT);
        vm.expectRevert(RepMigrationAlert.TransferDisabled.selector);
        alert.transfer(AUTHORITY, 1);

        // Authority-only irreversible finalization.
        vm.prank(AUTHORITY);
        alert.finalize();
        assertTrue(alert.finalized());
    }
}
