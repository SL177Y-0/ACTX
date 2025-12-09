// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {ACTXToken} from "../src/ACTXToken.sol";
import {Vesting} from "../src/Vesting.sol";
import {Airdrop} from "../src/Airdrop.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @title Deploy
 * @author BlessUP Team
 * @notice Deployment script for ACT.X Token ecosystem
 * @dev Deploys: ACTXToken (via proxy), Vesting, Airdrop contracts
 *
 * ╔═══════════════════════════════════════════════════════════════════════════════╗
 * ║                           DEPLOYMENT SEQUENCE                                  ║
 * ╠═══════════════════════════════════════════════════════════════════════════════╣
 * ║  1. Deploy ACTXToken Implementation                                           ║
 * ║  2. Deploy ERC1967Proxy with initialization                                   ║
 * ║  3. (Optional) Deploy Vesting contract                                        ║
 * ║  4. (Optional) Deploy Airdrop contract                                        ║
 * ║  5. Grant roles to appropriate addresses                                      ║
 * ║  6. Transfer tokens to reward pool                                            ║
 * ╚═══════════════════════════════════════════════════════════════════════════════╝
 *
 * USAGE:
 * ──────
 * # Dry run (simulation)
 * forge script script/Deploy.s.sol --rpc-url $RPC_URL
 *
 * # Deploy to Sepolia
 * forge script script/Deploy.s.sol --rpc-url $SEPOLIA_RPC_URL --broadcast --verify
 *
 * # Deploy to Base Sepolia
 * forge script script/Deploy.s.sol --rpc-url $BASE_SEPOLIA_RPC_URL --broadcast --verify
 */
contract DeployScript is Script {
    // ═══════════════════════════════════════════════════════════════════════════
    // CONFIGURATION
    // ═══════════════════════════════════════════════════════════════════════════

    // Deployment addresses (set via environment or modify here for testing)
    address public treasury;
    address public reservoir;
    address public admin;
    address public rewardManager;

    // Token configuration
    uint256 public constant INITIAL_TAX_RATE = 200; // 2%
    uint256 public constant REWARD_POOL_AMOUNT = 30_000_000 * 10 ** 18; // 30M tokens

    // Deployed contract addresses
    ACTXToken public tokenImpl;
    ERC1967Proxy public proxy;
    ACTXToken public token;
    Vesting public vesting;
    Airdrop public airdrop;

    // Roles
    bytes32 public constant REWARD_MANAGER_ROLE = keccak256("REWARD_MANAGER_ROLE");
    bytes32 public constant TAX_MANAGER_ROLE = keccak256("TAX_MANAGER_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    // ═══════════════════════════════════════════════════════════════════════════
    // MAIN DEPLOYMENT
    // ═══════════════════════════════════════════════════════════════════════════

    function run() external {
        // Load configuration from environment
        _loadConfig();

        // Start broadcast
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console2.log("===========================================================");
        console2.log("ACT.X TOKEN DEPLOYMENT");
        console2.log("===========================================================");
        console2.log("Deployer:", deployer);
        console2.log("Treasury:", treasury);
        console2.log("Reservoir:", reservoir);
        console2.log("Admin:", admin);
        console2.log("Reward Manager:", rewardManager);
        console2.log("Initial Tax Rate:", INITIAL_TAX_RATE, "bps");
        console2.log("===========================================================");

        vm.startBroadcast(deployerPrivateKey);

        // Step 1: Deploy ACTXToken Implementation
        tokenImpl = new ACTXToken();
        console2.log("[1/6] Implementation deployed:", address(tokenImpl));

        // Step 2: Deploy Proxy with initialization
        bytes memory initData = abi.encodeCall(
            ACTXToken.initialize,
            (treasury, reservoir, admin, INITIAL_TAX_RATE)
        );
        proxy = new ERC1967Proxy(address(tokenImpl), initData);
        token = ACTXToken(address(proxy));
        console2.log("[2/6] Proxy deployed:", address(proxy));

        // Step 3: Deploy Vesting contract
        vesting = new Vesting(address(token), treasury);
        console2.log("[3/6] Vesting deployed:", address(vesting));

        // Step 4: Deploy Airdrop contract
        airdrop = new Airdrop(address(token), treasury);
        console2.log("[4/6] Airdrop deployed:", address(airdrop));

        // Step 5: Grant REWARD_MANAGER_ROLE
        // Note: This requires deployer to have admin role, or admin to do this separately
        // For testnet, deployer might be admin
        if (deployer == admin) {
            token.grantRole(REWARD_MANAGER_ROLE, rewardManager);
            console2.log("[5/6] REWARD_MANAGER_ROLE granted to:", rewardManager);
        } else {
            console2.log("[5/6] SKIPPED: Deployer is not admin, grant roles manually");
        }

        // Step 6: Fund reward pool (requires treasury to call this)
        // For testnet where deployer might be treasury
        if (deployer == treasury) {
            token.transfer(address(token), REWARD_POOL_AMOUNT);
            console2.log("[6/6] Reward pool funded:", REWARD_POOL_AMOUNT / 1e18, "ACTX");
        } else {
            console2.log("[6/6] SKIPPED: Treasury must fund reward pool manually");
        }

        vm.stopBroadcast();

        // Print summary
        _printSummary();
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // CONFIGURATION LOADING
    // ═══════════════════════════════════════════════════════════════════════════

    function _loadConfig() internal {
        // Try to load from environment, fallback to deployer address
        try vm.envAddress("TREASURY_ADDRESS") returns (address addr) {
            treasury = addr;
        } catch {
            treasury = vm.addr(vm.envUint("PRIVATE_KEY"));
            console2.log("WARNING: Using deployer as treasury");
        }

        try vm.envAddress("RESERVOIR_ADDRESS") returns (address addr) {
            reservoir = addr;
        } catch {
            reservoir = vm.addr(vm.envUint("PRIVATE_KEY"));
            console2.log("WARNING: Using deployer as reservoir");
        }

        try vm.envAddress("ADMIN_ADDRESS") returns (address addr) {
            admin = addr;
        } catch {
            admin = vm.addr(vm.envUint("PRIVATE_KEY"));
            console2.log("WARNING: Using deployer as admin");
        }

        try vm.envAddress("REWARD_MANAGER_ADDRESS") returns (address addr) {
            rewardManager = addr;
        } catch {
            rewardManager = vm.addr(vm.envUint("PRIVATE_KEY"));
            console2.log("WARNING: Using deployer as reward manager");
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // SUMMARY
    // ═══════════════════════════════════════════════════════════════════════════

    function _printSummary() internal view {
        console2.log("");
        console2.log("===========================================================");
        console2.log("DEPLOYMENT COMPLETE");
        console2.log("===========================================================");
        console2.log("");
        console2.log("Contract Addresses:");
        console2.log("  ACTXToken Implementation:", address(tokenImpl));
        console2.log("  ACTXToken Proxy:", address(proxy));
        console2.log("  Vesting:", address(vesting));
        console2.log("  Airdrop:", address(airdrop));
        console2.log("");
        console2.log("Token Info:");
        console2.log("  Name:", token.name());
        console2.log("  Symbol:", token.symbol());
        console2.log("  Total Supply:", token.totalSupply() / 1e18, "ACTX");
        console2.log("  Tax Rate:", token.taxRateBps(), "bps");
        console2.log("");
        console2.log("Next Steps:");
        console2.log("  1. Verify contracts on block explorer");
        console2.log("  2. Grant roles to appropriate addresses (if not done)");
        console2.log("  3. Fund reward pool from treasury (if not done)");
        console2.log("  4. Setup vesting schedules for team/advisors");
        console2.log("  5. Initialize airdrop with merkle root");
        console2.log("");
        console2.log("===========================================================");
    }
}

/**
 * @title DeployTestnet
 * @notice Simplified deployment for testnet testing
 * @dev Uses deployer address for all roles
 */
contract DeployTestnet is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console2.log("===========================================================");
        console2.log("ACT.X TESTNET DEPLOYMENT");
        console2.log("===========================================================");
        console2.log("Deployer (all roles):", deployer);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy implementation
        ACTXToken impl = new ACTXToken();
        console2.log("Implementation:", address(impl));

        // Deploy proxy
        bytes memory initData = abi.encodeCall(
            ACTXToken.initialize,
            (deployer, deployer, deployer, 200) // All roles to deployer
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), initData);
        ACTXToken token = ACTXToken(address(proxy));
        console2.log("Proxy:", address(proxy));

        // Grant reward manager role to deployer
        token.grantRole(keccak256("REWARD_MANAGER_ROLE"), deployer);

        // Fund reward pool
        token.transfer(address(token), 30_000_000 * 10 ** 18);
        console2.log("Reward pool funded: 30,000,000 ACTX");

        vm.stopBroadcast();

        console2.log("");
        console2.log("DEPLOYMENT COMPLETE!");
        console2.log("Proxy Address:", address(proxy));
        console2.log("Total Supply:", token.totalSupply() / 1e18, "ACTX");
        console2.log("Reward Pool:", token.rewardPoolBalance() / 1e18, "ACTX");
        console2.log("===========================================================");
    }
}

