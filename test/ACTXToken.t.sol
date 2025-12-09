// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {ACTXToken} from "../src/ACTXToken.sol";
import {IACTXToken} from "../src/interfaces/IACTXToken.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @title ACTXToken Unit Tests
 * @author BlessUP Team
 * @notice Comprehensive unit tests for ACT.X Token
 * @dev Tests cover initialization, transfers, tax, roles, upgrades, and edge cases
 *
 * ╔═══════════════════════════════════════════════════════════════════════════════╗
 * ║                            TEST CATEGORIES                                     ║
 * ╠═══════════════════════════════════════════════════════════════════════════════╣
 * ║  1. Initialization    - Constructor, initialize(), initial state              ║
 * ║  2. ERC-20 Compliance - transfer, approve, transferFrom, permit               ║
 * ║  3. Tax Mechanism     - Tax calculation, exemptions, reservoir transfers      ║
 * ║  4. Reward Distribution - distributeReward, batch, role restrictions          ║
 * ║  5. Access Control    - Role management, unauthorized access                  ║
 * ║  6. Upgradeability    - UUPS upgrade authorization                            ║
 * ║  7. Pausability       - pause, unpause, transfer restrictions                 ║
 * ║  8. Edge Cases        - Zero values, max values, boundary conditions          ║
 * ╚═══════════════════════════════════════════════════════════════════════════════╝
 */
contract ACTXTokenTest is Test {
    // ═══════════════════════════════════════════════════════════════════════════
    // TEST FIXTURES
    // ═══════════════════════════════════════════════════════════════════════════

    ACTXToken public token;
    ACTXToken public tokenImpl;
    ERC1967Proxy public proxy;

    // Test addresses
    address public treasury = makeAddr("treasury");
    address public reservoir = makeAddr("reservoir");
    address public admin = makeAddr("admin");
    address public rewardManager = makeAddr("rewardManager");
    address public taxManager = makeAddr("taxManager");
    address public upgrader = makeAddr("upgrader");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public charlie = makeAddr("charlie");

    // Constants
    uint256 public constant TOTAL_SUPPLY = 100_000_000 * 10 ** 18;
    uint256 public constant INITIAL_TAX_RATE = 200; // 2%
    uint256 public constant MAX_TAX_RATE = 1000; // 10%
    uint256 public constant BPS_DENOMINATOR = 10_000;

    // Roles
    bytes32 public constant REWARD_MANAGER_ROLE = keccak256("REWARD_MANAGER_ROLE");
    bytes32 public constant TAX_MANAGER_ROLE = keccak256("TAX_MANAGER_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    // ═══════════════════════════════════════════════════════════════════════════
    // SETUP
    // ═══════════════════════════════════════════════════════════════════════════

    function setUp() public {
        // Deploy implementation
        tokenImpl = new ACTXToken();

        // Prepare initialization data
        bytes memory initData = abi.encodeCall(
            ACTXToken.initialize,
            (treasury, reservoir, admin, INITIAL_TAX_RATE)
        );

        // Deploy proxy
        proxy = new ERC1967Proxy(address(tokenImpl), initData);

        // Get token interface
        token = ACTXToken(address(proxy));

        // Setup roles
        vm.startPrank(admin);
        token.grantRole(REWARD_MANAGER_ROLE, rewardManager);
        token.grantRole(TAX_MANAGER_ROLE, taxManager);
        token.grantRole(UPGRADER_ROLE, upgrader);
        vm.stopPrank();

        // Fund reward pool (transfer from treasury to contract)
        uint256 rewardPoolAmount = 30_000_000 * 10 ** 18; // 30M for rewards
        vm.prank(treasury);
        token.transfer(address(token), rewardPoolAmount);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // 1. INITIALIZATION TESTS
    // ═══════════════════════════════════════════════════════════════════════════

    function test_Initialize_Name() public view {
        assertEq(token.name(), "ACT.X Token");
    }

    function test_Initialize_Symbol() public view {
        assertEq(token.symbol(), "ACTX");
    }

    function test_Initialize_TotalSupply() public view {
        assertEq(token.totalSupply(), TOTAL_SUPPLY);
    }

    function test_Initialize_TreasuryBalance() public view {
        uint256 rewardPool = 30_000_000 * 10 ** 18;
        assertEq(token.balanceOf(treasury), TOTAL_SUPPLY - rewardPool);
    }

    function test_Initialize_TaxRate() public view {
        assertEq(token.taxRateBps(), INITIAL_TAX_RATE);
    }

    function test_Initialize_Reservoir() public view {
        assertEq(token.reservoir(), reservoir);
    }

    function test_Initialize_Treasury() public view {
        assertEq(token.treasury(), treasury);
    }

    function test_Initialize_TreasuryTaxExempt() public view {
        assertTrue(token.isTaxExempt(treasury));
    }

    function test_Initialize_ReservoirTaxExempt() public view {
        assertTrue(token.isTaxExempt(reservoir));
    }

    function test_Initialize_ContractTaxExempt() public view {
        assertTrue(token.isTaxExempt(address(token)));
    }

    function test_Initialize_AdminRole() public view {
        assertTrue(token.hasRole(DEFAULT_ADMIN_ROLE, admin));
    }

    function test_Initialize_UpgraderRole() public view {
        assertTrue(token.hasRole(UPGRADER_ROLE, admin));
    }

    function test_Initialize_RevertZeroTreasury() public {
        ACTXToken newImpl = new ACTXToken();
        bytes memory initData = abi.encodeCall(
            ACTXToken.initialize,
            (address(0), reservoir, admin, INITIAL_TAX_RATE)
        );
        vm.expectRevert(IACTXToken.ZeroAddressNotAllowed.selector);
        new ERC1967Proxy(address(newImpl), initData);
    }

    function test_Initialize_RevertZeroReservoir() public {
        ACTXToken newImpl = new ACTXToken();
        bytes memory initData = abi.encodeCall(
            ACTXToken.initialize,
            (treasury, address(0), admin, INITIAL_TAX_RATE)
        );
        vm.expectRevert(IACTXToken.ZeroAddressNotAllowed.selector);
        new ERC1967Proxy(address(newImpl), initData);
    }

    function test_Initialize_RevertExcessiveTaxRate() public {
        ACTXToken newImpl = new ACTXToken();
        bytes memory initData = abi.encodeCall(
            ACTXToken.initialize,
            (treasury, reservoir, admin, MAX_TAX_RATE + 1)
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                IACTXToken.TaxRateExceedsMaximum.selector,
                MAX_TAX_RATE + 1,
                MAX_TAX_RATE
            )
        );
        new ERC1967Proxy(address(newImpl), initData);
    }

    function test_Initialize_CannotReinitialize() public {
        vm.expectRevert();
        token.initialize(treasury, reservoir, admin, INITIAL_TAX_RATE);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // 2. ERC-20 COMPLIANCE TESTS
    // ═══════════════════════════════════════════════════════════════════════════

    function test_Transfer_Basic() public {
        uint256 amount = 1000 * 10 ** 18;

        // Treasury is tax exempt, so transfer full amount
        vm.prank(treasury);
        token.transfer(alice, amount);

        assertEq(token.balanceOf(alice), amount);
    }

    function test_Transfer_WithTax() public {
        uint256 amount = 1000 * 10 ** 18;
        uint256 taxAmount = (amount * INITIAL_TAX_RATE) / BPS_DENOMINATOR;
        uint256 netAmount = amount - taxAmount;

        // First fund Alice from treasury (exempt)
        vm.prank(treasury);
        token.transfer(alice, amount);

        // Alice transfers to Bob (not exempt, tax applies)
        vm.prank(alice);
        token.transfer(bob, amount);

        assertEq(token.balanceOf(bob), netAmount);
        assertEq(token.balanceOf(reservoir), taxAmount);
    }

    function test_Transfer_FromExemptAddress() public {
        uint256 amount = 1000 * 10 ** 18;

        // Treasury is exempt
        vm.prank(treasury);
        token.transfer(alice, amount);

        assertEq(token.balanceOf(alice), amount);
        assertEq(token.balanceOf(reservoir), 0); // No tax collected
    }

    function test_Transfer_ToExemptAddress() public {
        uint256 amount = 1000 * 10 ** 18;

        // Fund Alice
        vm.prank(treasury);
        token.transfer(alice, amount);

        // Alice transfers to treasury (recipient exempt)
        vm.prank(alice);
        token.transfer(treasury, amount);

        // No tax when recipient is exempt
        assertEq(token.balanceOf(treasury), TOTAL_SUPPLY - 30_000_000 * 10 ** 18);
    }

    function test_Approve_Basic() public {
        uint256 amount = 1000 * 10 ** 18;

        vm.prank(alice);
        token.approve(bob, amount);

        assertEq(token.allowance(alice, bob), amount);
    }

    function test_TransferFrom_Basic() public {
        uint256 amount = 1000 * 10 ** 18;
        uint256 taxAmount = (amount * INITIAL_TAX_RATE) / BPS_DENOMINATOR;
        uint256 netAmount = amount - taxAmount;

        // Fund Alice
        vm.prank(treasury);
        token.transfer(alice, amount);

        // Alice approves Bob
        vm.prank(alice);
        token.approve(bob, amount);

        // Bob transfers from Alice to Charlie
        vm.prank(bob);
        token.transferFrom(alice, charlie, amount);

        assertEq(token.balanceOf(charlie), netAmount);
        assertEq(token.balanceOf(alice), 0);
    }

    function test_Decimals() public view {
        assertEq(token.decimals(), 18);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // 3. TAX MECHANISM TESTS
    // ═══════════════════════════════════════════════════════════════════════════

    function test_CalculateTax() public view {
        uint256 amount = 1000 * 10 ** 18;
        uint256 expectedTax = (amount * INITIAL_TAX_RATE) / BPS_DENOMINATOR;

        assertEq(token.calculateTax(amount), expectedTax);
    }

    function test_SetTaxRate_Success() public {
        uint256 newRate = 500; // 5%

        vm.prank(taxManager);
        token.setTaxRate(newRate);

        assertEq(token.taxRateBps(), newRate);
    }

    function test_SetTaxRate_EmitsEvent() public {
        uint256 newRate = 500;

        vm.prank(taxManager);
        vm.expectEmit(true, true, true, true);
        emit IACTXToken.TaxRateUpdated(INITIAL_TAX_RATE, newRate, taxManager);
        token.setTaxRate(newRate);
    }

    function test_SetTaxRate_RevertExceedsMax() public {
        vm.prank(taxManager);
        vm.expectRevert(
            abi.encodeWithSelector(
                IACTXToken.TaxRateExceedsMaximum.selector,
                MAX_TAX_RATE + 1,
                MAX_TAX_RATE
            )
        );
        token.setTaxRate(MAX_TAX_RATE + 1);
    }

    function test_SetTaxRate_RevertUnauthorized() public {
        vm.prank(alice);
        vm.expectRevert();
        token.setTaxRate(500);
    }

    function test_SetReservoir_Success() public {
        address newReservoir = makeAddr("newReservoir");

        vm.prank(admin);
        token.setReservoir(newReservoir);

        assertEq(token.reservoir(), newReservoir);
        assertTrue(token.isTaxExempt(newReservoir));
        assertFalse(token.isTaxExempt(reservoir)); // Old reservoir no longer exempt
    }

    function test_SetReservoir_RevertZeroAddress() public {
        vm.prank(admin);
        vm.expectRevert(IACTXToken.ZeroAddressNotAllowed.selector);
        token.setReservoir(address(0));
    }

    function test_SetTaxExempt_Success() public {
        vm.prank(taxManager);
        token.setTaxExempt(alice, true);

        assertTrue(token.isTaxExempt(alice));
    }

    function test_SetTaxExempt_RemoveExemption() public {
        vm.prank(taxManager);
        token.setTaxExempt(alice, true);
        assertTrue(token.isTaxExempt(alice));

        vm.prank(taxManager);
        token.setTaxExempt(alice, false);
        assertFalse(token.isTaxExempt(alice));
    }

    function test_Transfer_ZeroTaxRate() public {
        // Set tax to 0
        vm.prank(taxManager);
        token.setTaxRate(0);

        uint256 amount = 1000 * 10 ** 18;

        vm.prank(treasury);
        token.transfer(alice, amount);

        vm.prank(alice);
        token.transfer(bob, amount);

        // Full amount received, no tax
        assertEq(token.balanceOf(bob), amount);
        assertEq(token.balanceOf(reservoir), 0);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // 4. REWARD DISTRIBUTION TESTS
    // ═══════════════════════════════════════════════════════════════════════════

    function test_DistributeReward_Success() public {
        uint256 amount = 100 * 10 ** 18;
        bytes32 activityId = keccak256("referral_001");

        vm.prank(rewardManager);
        token.distributeReward(alice, amount, activityId);

        assertEq(token.balanceOf(alice), amount);
    }

    function test_DistributeReward_EmitsEvent() public {
        uint256 amount = 100 * 10 ** 18;
        bytes32 activityId = keccak256("referral_001");

        vm.prank(rewardManager);
        vm.expectEmit(true, true, true, true);
        emit IACTXToken.RewardDistributed(alice, amount, activityId, block.timestamp);
        token.distributeReward(alice, amount, activityId);
    }

    function test_DistributeReward_NoTax() public {
        uint256 amount = 100 * 10 ** 18;
        bytes32 activityId = keccak256("referral_001");

        uint256 reservoirBefore = token.balanceOf(reservoir);

        vm.prank(rewardManager);
        token.distributeReward(alice, amount, activityId);

        // No tax collected (contract is exempt)
        assertEq(token.balanceOf(reservoir), reservoirBefore);
    }

    function test_DistributeReward_RevertZeroAddress() public {
        vm.prank(rewardManager);
        vm.expectRevert(IACTXToken.ZeroAddressNotAllowed.selector);
        token.distributeReward(address(0), 100, keccak256("test"));
    }

    function test_DistributeReward_RevertZeroAmount() public {
        vm.prank(rewardManager);
        vm.expectRevert(IACTXToken.ZeroAmountNotAllowed.selector);
        token.distributeReward(alice, 0, keccak256("test"));
    }

    function test_DistributeReward_RevertInsufficientPool() public {
        uint256 poolBalance = token.rewardPoolBalance();

        vm.prank(rewardManager);
        vm.expectRevert(
            abi.encodeWithSelector(
                IACTXToken.InsufficientRewardPool.selector,
                poolBalance + 1,
                poolBalance
            )
        );
        token.distributeReward(alice, poolBalance + 1, keccak256("test"));
    }

    function test_DistributeReward_RevertUnauthorized() public {
        vm.prank(alice);
        vm.expectRevert();
        token.distributeReward(bob, 100, keccak256("test"));
    }

    function test_BatchDistributeRewards_Success() public {
        address[] memory recipients = new address[](3);
        recipients[0] = alice;
        recipients[1] = bob;
        recipients[2] = charlie;

        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 100 * 10 ** 18;
        amounts[1] = 200 * 10 ** 18;
        amounts[2] = 300 * 10 ** 18;

        bytes32[] memory activityIds = new bytes32[](3);
        activityIds[0] = keccak256("activity_1");
        activityIds[1] = keccak256("activity_2");
        activityIds[2] = keccak256("activity_3");

        vm.prank(rewardManager);
        token.batchDistributeRewards(recipients, amounts, activityIds);

        assertEq(token.balanceOf(alice), amounts[0]);
        assertEq(token.balanceOf(bob), amounts[1]);
        assertEq(token.balanceOf(charlie), amounts[2]);
    }

    function test_RewardPoolBalance() public view {
        uint256 expectedPool = 30_000_000 * 10 ** 18;
        assertEq(token.rewardPoolBalance(), expectedPool);
    }

    function test_CirculatingSupply() public view {
        uint256 poolBalance = token.rewardPoolBalance();
        uint256 expectedCirculating = TOTAL_SUPPLY - poolBalance;
        assertEq(token.circulatingSupply(), expectedCirculating);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // 5. ACCESS CONTROL TESTS
    // ═══════════════════════════════════════════════════════════════════════════

    function test_GrantRole_Success() public {
        address newManager = makeAddr("newManager");

        vm.prank(admin);
        token.grantRole(REWARD_MANAGER_ROLE, newManager);

        assertTrue(token.hasRole(REWARD_MANAGER_ROLE, newManager));
    }

    function test_RevokeRole_Success() public {
        vm.prank(admin);
        token.revokeRole(REWARD_MANAGER_ROLE, rewardManager);

        assertFalse(token.hasRole(REWARD_MANAGER_ROLE, rewardManager));
    }

    function test_RenounceRole_Success() public {
        vm.prank(rewardManager);
        token.renounceRole(REWARD_MANAGER_ROLE, rewardManager);

        assertFalse(token.hasRole(REWARD_MANAGER_ROLE, rewardManager));
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // 6. UPGRADEABILITY TESTS
    // ═══════════════════════════════════════════════════════════════════════════

    function test_Upgrade_AuthorizedUpgrader() public {
        ACTXToken newImpl = new ACTXToken();

        vm.prank(upgrader);
        token.upgradeToAndCall(address(newImpl), "");

        // Verify state preserved
        assertEq(token.totalSupply(), TOTAL_SUPPLY);
        assertEq(token.taxRateBps(), INITIAL_TAX_RATE);
    }

    function test_Upgrade_RevertUnauthorized() public {
        ACTXToken newImpl = new ACTXToken();

        vm.prank(alice);
        vm.expectRevert();
        token.upgradeToAndCall(address(newImpl), "");
    }

    function test_Version() public view {
        assertEq(token.version(), "1.0.0");
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // 7. PAUSABILITY TESTS
    // ═══════════════════════════════════════════════════════════════════════════

    function test_Pause_Success() public {
        vm.prank(admin);
        token.pause();

        assertTrue(token.paused());
    }

    function test_Unpause_Success() public {
        vm.prank(admin);
        token.pause();

        vm.prank(admin);
        token.unpause();

        assertFalse(token.paused());
    }

    function test_Transfer_RevertWhenPaused() public {
        vm.prank(admin);
        token.pause();

        vm.prank(treasury);
        vm.expectRevert();
        token.transfer(alice, 100);
    }

    function test_DistributeReward_RevertWhenPaused() public {
        vm.prank(admin);
        token.pause();

        vm.prank(rewardManager);
        vm.expectRevert();
        token.distributeReward(alice, 100, keccak256("test"));
    }

    function test_Pause_RevertUnauthorized() public {
        vm.prank(alice);
        vm.expectRevert();
        token.pause();
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // 8. EDGE CASES & CONSTANTS
    // ═══════════════════════════════════════════════════════════════════════════

    function test_TotalSupply_Constant() public view {
        assertEq(token.TOTAL_SUPPLY(), TOTAL_SUPPLY);
    }

    function test_MaxTaxRate_Constant() public view {
        assertEq(token.MAX_TAX_RATE_BPS(), MAX_TAX_RATE);
    }

    function test_Transfer_EntireBalance() public {
        uint256 amount = 1000 * 10 ** 18;

        vm.prank(treasury);
        token.transfer(alice, amount);

        uint256 aliceBalance = token.balanceOf(alice);
        uint256 taxAmount = (aliceBalance * INITIAL_TAX_RATE) / BPS_DENOMINATOR;
        uint256 netAmount = aliceBalance - taxAmount;

        vm.prank(alice);
        token.transfer(bob, aliceBalance);

        assertEq(token.balanceOf(alice), 0);
        assertEq(token.balanceOf(bob), netAmount);
    }

    function test_TaxCollection_AccumulatesInReservoir() public {
        uint256 amount = 1000 * 10 ** 18;
        uint256 taxPerTransfer = (amount * INITIAL_TAX_RATE) / BPS_DENOMINATOR;

        // Fund multiple users
        vm.startPrank(treasury);
        token.transfer(alice, amount);
        token.transfer(bob, amount);
        token.transfer(charlie, amount);
        vm.stopPrank();

        // Each makes a transfer
        vm.prank(alice);
        token.transfer(makeAddr("user1"), amount);

        vm.prank(bob);
        token.transfer(makeAddr("user2"), amount);

        vm.prank(charlie);
        token.transfer(makeAddr("user3"), amount);

        // Reservoir should have accumulated all taxes
        assertEq(token.balanceOf(reservoir), taxPerTransfer * 3);
    }
}

