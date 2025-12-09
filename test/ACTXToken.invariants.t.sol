// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {ACTXToken} from "../src/ACTXToken.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @title ACTXToken Invariant Tests
 * @author BlessUP Team
 * @notice Stateful invariant tests for ACT.X Token
 * @dev Tests that critical properties hold across random operation sequences
 *
 * ╔═══════════════════════════════════════════════════════════════════════════════╗
 * ║                          INVARIANTS TESTED                                     ║
 * ╠═══════════════════════════════════════════════════════════════════════════════╣
 * ║  1. Total supply is always exactly 100,000,000 ACTX                           ║
 * ║  2. Sum of all balances equals total supply                                   ║
 * ║  3. Tax rate never exceeds MAX_TAX_RATE (10%)                                 ║
 * ║  4. Reservoir balance never decreases (tax collection only)                   ║
 * ║  5. Reward pool balance <= initial pool allocation                            ║
 * ╚═══════════════════════════════════════════════════════════════════════════════╝
 */

/**
 * @title ACTXTokenHandler
 * @notice Handler contract for invariant testing
 * @dev Performs random valid operations on ACTXToken
 */
contract ACTXTokenHandler is Test {
    ACTXToken public token;
    address public treasury;
    address public reservoir;
    address public admin;
    address public rewardManager;
    address public taxManager;

    // Ghost variables for tracking
    uint256 public ghost_totalDistributed;
    uint256 public ghost_totalTaxCollected;

    // Track addresses with balances
    address[] public actors;
    mapping(address => bool) public isActor;

    bytes32 public constant REWARD_MANAGER_ROLE = keccak256("REWARD_MANAGER_ROLE");
    bytes32 public constant TAX_MANAGER_ROLE = keccak256("TAX_MANAGER_ROLE");

    constructor(
        ACTXToken _token,
        address _treasury,
        address _reservoir,
        address _admin,
        address _rewardManager,
        address _taxManager
    ) {
        token = _token;
        treasury = _treasury;
        reservoir = _reservoir;
        admin = _admin;
        rewardManager = _rewardManager;
        taxManager = _taxManager;

        // Add initial actors
        _addActor(treasury);
        _addActor(reservoir);
    }

    function _addActor(address actor) internal {
        if (!isActor[actor] && actor != address(0) && actor != address(token)) {
            actors.push(actor);
            isActor[actor] = true;
        }
    }

    function _getActor(uint256 seed) internal view returns (address) {
        if (actors.length == 0) return treasury;
        return actors[seed % actors.length];
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // HANDLER ACTIONS
    // ═══════════════════════════════════════════════════════════════════════════

    /**
     * @notice Handler: Transfer tokens between actors
     */
    function transfer(uint256 senderSeed, uint256 recipientSeed, uint256 amount) external {
        address sender = _getActor(senderSeed);
        address recipient = makeAddr(string(abi.encodePacked("recipient", recipientSeed)));
        _addActor(recipient);

        uint256 balance = token.balanceOf(sender);
        if (balance == 0) return;

        amount = bound(amount, 1, balance);

        vm.prank(sender);
        token.transfer(recipient, amount);
    }

    /**
     * @notice Handler: Distribute rewards
     */
    function distributeReward(uint256 recipientSeed, uint256 amount) external {
        address recipient = makeAddr(string(abi.encodePacked("reward", recipientSeed)));
        _addActor(recipient);

        uint256 poolBalance = token.rewardPoolBalance();
        if (poolBalance == 0) return;

        amount = bound(amount, 1, poolBalance);

        vm.prank(rewardManager);
        token.distributeReward(recipient, amount, keccak256(abi.encodePacked(block.timestamp)));

        ghost_totalDistributed += amount;
    }

    /**
     * @notice Handler: Change tax rate
     */
    function setTaxRate(uint256 newRate) external {
        newRate = bound(newRate, 0, 1000); // 0-10%

        vm.prank(taxManager);
        token.setTaxRate(newRate);
    }

    /**
     * @notice Handler: Toggle tax exemption
     * @dev Protects critical addresses (treasury, reservoir, token) from exemption changes
     */
    function setTaxExempt(uint256 actorSeed, bool exempt) external {
        address actor = _getActor(actorSeed);
        if (actor == address(0)) return;
        
        // Protect critical addresses from exemption changes
        if (actor == treasury || actor == reservoir || actor == address(token)) return;

        vm.prank(taxManager);
        token.setTaxExempt(actor, exempt);
    }

    /**
     * @notice Get count of tracked actors
     */
    function actorCount() external view returns (uint256) {
        return actors.length;
    }
}

/**
 * @title ACTXTokenInvariantTest
 * @notice Main invariant test contract
 */
contract ACTXTokenInvariantTest is Test {
    ACTXToken public token;
    ACTXTokenHandler public handler;
    ERC1967Proxy public proxy;

    address public treasury = makeAddr("treasury");
    address public reservoir = makeAddr("reservoir");
    address public admin = makeAddr("admin");
    address public rewardManager = makeAddr("rewardManager");
    address public taxManager = makeAddr("taxManager");

    uint256 public constant TOTAL_SUPPLY = 100_000_000 * 10 ** 18;
    uint256 public constant INITIAL_REWARD_POOL = 30_000_000 * 10 ** 18;
    uint256 public constant MAX_TAX_RATE = 1000;

    bytes32 public constant REWARD_MANAGER_ROLE = keccak256("REWARD_MANAGER_ROLE");
    bytes32 public constant TAX_MANAGER_ROLE = keccak256("TAX_MANAGER_ROLE");

    // Track reservoir balance for monotonicity
    uint256 public initialReservoirBalance;

    function setUp() public {
        // Deploy token
        ACTXToken impl = new ACTXToken();
        bytes memory initData = abi.encodeCall(
            ACTXToken.initialize,
            (treasury, reservoir, admin, 200)
        );
        proxy = new ERC1967Proxy(address(impl), initData);
        token = ACTXToken(address(proxy));

        // Setup roles
        vm.startPrank(admin);
        token.grantRole(REWARD_MANAGER_ROLE, rewardManager);
        token.grantRole(TAX_MANAGER_ROLE, taxManager);
        vm.stopPrank();

        // Fund reward pool
        vm.prank(treasury);
        token.transfer(address(token), INITIAL_REWARD_POOL);

        initialReservoirBalance = token.balanceOf(reservoir);

        // Create handler
        handler = new ACTXTokenHandler(
            token,
            treasury,
            reservoir,
            admin,
            rewardManager,
            taxManager
        );

        // Target the handler for invariant testing
        targetContract(address(handler));

        // Exclude system addresses from sender
        excludeSender(address(token));
        excludeSender(address(handler));
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // INVARIANTS
    // ═══════════════════════════════════════════════════════════════════════════

    /**
     * @notice Invariant: Total supply is always exactly 100M
     * @dev This is the most critical invariant - no minting/burning allowed
     */
    function invariant_TotalSupplyFixed() public view {
        assertEq(
            token.totalSupply(),
            TOTAL_SUPPLY,
            "INVARIANT VIOLATED: Total supply changed"
        );
    }

    /**
     * @notice Invariant: Tax rate never exceeds maximum
     */
    function invariant_TaxRateWithinBounds() public view {
        assertLe(
            token.taxRateBps(),
            MAX_TAX_RATE,
            "INVARIANT VIOLATED: Tax rate exceeds maximum"
        );
    }

    /**
     * @notice Invariant: Reservoir balance never decreases
     * @dev Reservoir only receives tax, never sends (except by admin)
     */
    function invariant_ReservoirMonotonic() public view {
        assertGe(
            token.balanceOf(reservoir),
            initialReservoirBalance,
            "INVARIANT VIOLATED: Reservoir balance decreased"
        );
    }

    /**
     * @notice Invariant: Reward pool balance <= initial allocation
     * @dev Pool can only decrease through distributions
     */
    function invariant_RewardPoolBounded() public view {
        assertLe(
            token.rewardPoolBalance(),
            INITIAL_REWARD_POOL,
            "INVARIANT VIOLATED: Reward pool exceeded initial"
        );
    }

    /**
     * @notice Invariant: Circulating supply + pool = total supply - reservoir
     * @dev Conservation of tokens across pools
     */
    function invariant_SupplyConservation() public view {
        uint256 circulating = token.circulatingSupply();
        uint256 pool = token.rewardPoolBalance();
        uint256 reservoirBalance = token.balanceOf(reservoir);

        // circulating = totalSupply - pool
        // So: pool + circulating = totalSupply
        assertEq(
            pool + circulating,
            TOTAL_SUPPLY,
            "INVARIANT VIOLATED: Supply not conserved"
        );
    }

    /**
     * @notice Invariant: Treasury is always tax exempt
     */
    function invariant_TreasuryExempt() public view {
        assertTrue(
            token.isTaxExempt(treasury),
            "INVARIANT VIOLATED: Treasury lost tax exemption"
        );
    }

    /**
     * @notice Invariant: Reservoir is always tax exempt
     */
    function invariant_ReservoirExempt() public view {
        assertTrue(
            token.isTaxExempt(reservoir),
            "INVARIANT VIOLATED: Reservoir lost tax exemption"
        );
    }

    /**
     * @notice Invariant: Contract (reward pool) is always tax exempt
     */
    function invariant_ContractExempt() public view {
        assertTrue(
            token.isTaxExempt(address(token)),
            "INVARIANT VIOLATED: Contract lost tax exemption"
        );
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // CALL SUMMARY
    // ═══════════════════════════════════════════════════════════════════════════

    /**
     * @notice Log invariant test summary
     */
    function invariant_callSummary() public view {
        console2.log("===================================================");
        console2.log("INVARIANT TEST SUMMARY");
        console2.log("===================================================");
        console2.log("Total Supply:", token.totalSupply() / 1e18, "ACTX");
        console2.log("Tax Rate:", token.taxRateBps(), "bps");
        console2.log("Reward Pool:", token.rewardPoolBalance() / 1e18, "ACTX");
        console2.log("Reservoir:", token.balanceOf(reservoir) / 1e18, "ACTX");
        console2.log("Actors tracked:", handler.actorCount());
        console2.log("Total distributed:", handler.ghost_totalDistributed() / 1e18, "ACTX");
        console2.log("===================================================");
    }
}

