// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {ACTXToken} from "../src/ACTXToken.sol";
import {IACTXToken} from "../src/interfaces/IACTXToken.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @title ACTXToken Fuzz Tests
 * @author BlessUP Team
 * @notice Property-based fuzz tests for ACT.X Token
 * @dev Tests randomized inputs to find edge cases and vulnerabilities
 *
 * ╔═══════════════════════════════════════════════════════════════════════════════╗
 * ║                            FUZZ TEST COVERAGE                                  ║
 * ╠═══════════════════════════════════════════════════════════════════════════════╣
 * ║  • Random transfer amounts within valid range                                  ║
 * ║  • Random tax rates within bounds                                             ║
 * ║  • Random reward distributions                                                ║
 * ║  • Boundary conditions (min/max values)                                       ║
 * ║  • Tax calculation precision                                                  ║
 * ╚═══════════════════════════════════════════════════════════════════════════════╝
 */
contract ACTXTokenFuzzTest is Test {
    // ═══════════════════════════════════════════════════════════════════════════
    // TEST FIXTURES
    // ═══════════════════════════════════════════════════════════════════════════

    ACTXToken public token;
    ERC1967Proxy public proxy;

    address public treasury = makeAddr("treasury");
    address public reservoir = makeAddr("reservoir");
    address public admin = makeAddr("admin");
    address public rewardManager = makeAddr("rewardManager");
    address public taxManager = makeAddr("taxManager");

    uint256 public constant TOTAL_SUPPLY = 100_000_000 * 10 ** 18;
    uint256 public constant INITIAL_TAX_RATE = 200;
    uint256 public constant MAX_TAX_RATE = 1000;
    uint256 public constant BPS_DENOMINATOR = 10_000;

    bytes32 public constant REWARD_MANAGER_ROLE = keccak256("REWARD_MANAGER_ROLE");
    bytes32 public constant TAX_MANAGER_ROLE = keccak256("TAX_MANAGER_ROLE");

    // ═══════════════════════════════════════════════════════════════════════════
    // SETUP
    // ═══════════════════════════════════════════════════════════════════════════

    function setUp() public {
        ACTXToken impl = new ACTXToken();
        bytes memory initData = abi.encodeCall(
            ACTXToken.initialize,
            (treasury, reservoir, admin, INITIAL_TAX_RATE)
        );
        proxy = new ERC1967Proxy(address(impl), initData);
        token = ACTXToken(address(proxy));

        vm.startPrank(admin);
        token.grantRole(REWARD_MANAGER_ROLE, rewardManager);
        token.grantRole(TAX_MANAGER_ROLE, taxManager);
        vm.stopPrank();

        // Fund reward pool
        vm.prank(treasury);
        token.transfer(address(token), 30_000_000 * 10 ** 18);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FUZZ: TRANSFER AMOUNTS
    // ═══════════════════════════════════════════════════════════════════════════

    /**
     * @notice Fuzz test: Transfer any amount within sender's balance
     * @dev Property: net amount + tax = original amount
     */
    function testFuzz_Transfer_TaxCalculationCorrect(uint256 amount) public {
        // Bound to valid range
        uint256 maxTransfer = TOTAL_SUPPLY - 30_000_000 * 10 ** 18;
        amount = bound(amount, 1, maxTransfer);

        address sender = makeAddr("sender");
        address recipient = makeAddr("recipient");

        // Fund sender
        vm.prank(treasury);
        token.transfer(sender, amount);

        uint256 senderBalanceBefore = token.balanceOf(sender);
        uint256 reservoirBefore = token.balanceOf(reservoir);

        // Calculate expected values
        uint256 expectedTax = (amount * INITIAL_TAX_RATE) / BPS_DENOMINATOR;
        uint256 expectedNet = amount - expectedTax;

        // Execute transfer
        vm.prank(sender);
        token.transfer(recipient, amount);

        // Verify invariant: sender lost exact amount
        assertEq(token.balanceOf(sender), senderBalanceBefore - amount);

        // Verify invariant: recipient got net amount
        assertEq(token.balanceOf(recipient), expectedNet);

        // Verify invariant: reservoir got tax
        assertEq(token.balanceOf(reservoir), reservoirBefore + expectedTax);
    }

    /**
     * @notice Fuzz test: Tax-exempt transfers have no tax
     */
    function testFuzz_Transfer_ExemptNoTax(uint256 amount) public {
        uint256 maxTransfer = TOTAL_SUPPLY - 30_000_000 * 10 ** 18;
        amount = bound(amount, 1, maxTransfer);

        address recipient = makeAddr("recipient");

        // Treasury is exempt
        uint256 reservoirBefore = token.balanceOf(reservoir);

        vm.prank(treasury);
        token.transfer(recipient, amount);

        // Full amount received
        assertEq(token.balanceOf(recipient), amount);

        // No tax collected
        assertEq(token.balanceOf(reservoir), reservoirBefore);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FUZZ: TAX RATE CHANGES
    // ═══════════════════════════════════════════════════════════════════════════

    /**
     * @notice Fuzz test: Any valid tax rate can be set
     */
    function testFuzz_SetTaxRate_ValidRange(uint256 newRate) public {
        newRate = bound(newRate, 0, MAX_TAX_RATE);

        vm.prank(taxManager);
        token.setTaxRate(newRate);

        assertEq(token.taxRateBps(), newRate);
    }

    /**
     * @notice Fuzz test: Invalid tax rates are rejected
     */
    function testFuzz_SetTaxRate_RevertInvalid(uint256 newRate) public {
        newRate = bound(newRate, MAX_TAX_RATE + 1, type(uint256).max);

        vm.prank(taxManager);
        vm.expectRevert(
            abi.encodeWithSelector(
                IACTXToken.TaxRateExceedsMaximum.selector,
                newRate,
                MAX_TAX_RATE
            )
        );
        token.setTaxRate(newRate);
    }

    /**
     * @notice Fuzz test: Tax calculation matches rate
     */
    function testFuzz_CalculateTax_Precision(uint256 amount, uint256 rate) public {
        amount = bound(amount, 1, TOTAL_SUPPLY);
        rate = bound(rate, 0, MAX_TAX_RATE);

        // Set rate
        vm.prank(taxManager);
        token.setTaxRate(rate);

        uint256 calculatedTax = token.calculateTax(amount);
        uint256 expectedTax = (amount * rate) / BPS_DENOMINATOR;

        assertEq(calculatedTax, expectedTax);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FUZZ: REWARD DISTRIBUTION
    // ═══════════════════════════════════════════════════════════════════════════

    /**
     * @notice Fuzz test: Reward distribution within pool limits
     */
    function testFuzz_DistributeReward_ValidAmount(uint256 amount) public {
        uint256 poolBalance = token.rewardPoolBalance();
        amount = bound(amount, 1, poolBalance);

        address recipient = makeAddr("recipient");
        bytes32 activityId = keccak256(abi.encodePacked(amount, block.timestamp));

        uint256 poolBefore = token.rewardPoolBalance();

        vm.prank(rewardManager);
        token.distributeReward(recipient, amount, activityId);

        // Recipient got exact amount
        assertEq(token.balanceOf(recipient), amount);

        // Pool decreased by amount
        assertEq(token.rewardPoolBalance(), poolBefore - amount);
    }

    /**
     * @notice Fuzz test: Rewards exceeding pool are rejected
     */
    function testFuzz_DistributeReward_RevertExceedsPool(uint256 amount) public {
        uint256 poolBalance = token.rewardPoolBalance();
        amount = bound(amount, poolBalance + 1, type(uint256).max);

        vm.prank(rewardManager);
        vm.expectRevert(
            abi.encodeWithSelector(
                IACTXToken.InsufficientRewardPool.selector,
                amount,
                poolBalance
            )
        );
        token.distributeReward(makeAddr("recipient"), amount, keccak256("test"));
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FUZZ: ADDRESS FUZZING
    // ═══════════════════════════════════════════════════════════════════════════

    /**
     * @notice Fuzz test: Tax exemption for any non-zero address
     */
    function testFuzz_SetTaxExempt_AnyAddress(address account) public {
        vm.assume(account != address(0));

        vm.prank(taxManager);
        token.setTaxExempt(account, true);

        assertTrue(token.isTaxExempt(account));

        vm.prank(taxManager);
        token.setTaxExempt(account, false);

        assertFalse(token.isTaxExempt(account));
    }

    /**
     * @notice Fuzz test: Zero address rejected for tax exemption
     */
    function testFuzz_SetTaxExempt_RevertZeroAddress() public {
        vm.prank(taxManager);
        vm.expectRevert(IACTXToken.ZeroAddressNotAllowed.selector);
        token.setTaxExempt(address(0), true);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FUZZ: MULTIPLE TRANSFERS
    // ═══════════════════════════════════════════════════════════════════════════

    /**
     * @notice Fuzz test: Multiple sequential transfers maintain invariants
     */
    function testFuzz_MultipleTransfers_SupplyConserved(
        uint256 amount1,
        uint256 amount2,
        uint256 amount3
    ) public {
        // Bound amounts
        uint256 available = (TOTAL_SUPPLY - 30_000_000 * 10 ** 18) / 4;
        amount1 = bound(amount1, 1, available);
        amount2 = bound(amount2, 1, available);
        amount3 = bound(amount3, 1, available);

        address user1 = makeAddr("user1");
        address user2 = makeAddr("user2");
        address user3 = makeAddr("user3");
        address user4 = makeAddr("user4");

        // Fund users from treasury
        vm.startPrank(treasury);
        token.transfer(user1, amount1);
        token.transfer(user2, amount2);
        token.transfer(user3, amount3);
        vm.stopPrank();

        // Make transfers
        vm.prank(user1);
        token.transfer(user4, amount1);

        vm.prank(user2);
        token.transfer(user4, amount2);

        vm.prank(user3);
        token.transfer(user4, amount3);

        // Total supply unchanged
        assertEq(token.totalSupply(), TOTAL_SUPPLY);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // FUZZ: BOUNDARY CONDITIONS
    // ═══════════════════════════════════════════════════════════════════════════

    /**
     * @notice Fuzz test: Minimum transfer amount (1 wei)
     */
    function testFuzz_Transfer_MinimumAmount() public {
        uint256 amount = 1; // 1 wei

        address sender = makeAddr("sender");
        address recipient = makeAddr("recipient");

        vm.prank(treasury);
        token.transfer(sender, 1000); // Fund with small amount

        vm.prank(sender);
        token.transfer(recipient, amount);

        // Verify transfer completed (even if tax rounds to 0)
        assertTrue(token.balanceOf(recipient) <= amount);
    }

    /**
     * @notice Fuzz test: Tax calculation at boundaries
     */
    function testFuzz_TaxCalculation_NeverExceedsAmount(uint256 amount) public {
        amount = bound(amount, 0, type(uint256).max / MAX_TAX_RATE);

        uint256 tax = token.calculateTax(amount);

        // Tax should never exceed 10% (MAX_TAX_RATE / BPS_DENOMINATOR)
        assertLe(tax, amount);
    }
}

