# ACT.X Token - Video Demo Production Guide

**For:** Rishi Rawat  
**Duration:** 3-5 minutes  
**Objective:** Demonstrate development environment, deployment, testing, and share technical insights

---

## Pre-Production Checklist

### Tools Needed
- [ ] Screen recording software (OBS Studio, Loom, or QuickTime)
- [ ] Terminal/Command Prompt ready
- [ ] VS Code or your preferred IDE open
- [ ] GitHub repository open in browser
- [ ] BaseScan explorer ready (for contract verification)
- [ ] `.env` file configured (hide sensitive data in recording)

### Preparation Steps
1. **Clean Terminal**: Clear terminal history, start fresh
2. **Test Run**: Run `forge test` once to ensure everything works
3. **Browser Tabs**: Open GitHub repo, BaseScan, and Foundry docs
4. **Script Ready**: Have this guide open on a second monitor/device
5. **Audio Check**: Test microphone, ensure clear audio

---

## Video Structure (3-5 Minutes)

### Segment 1: Introduction & Development Environment (30-45 seconds)
### Segment 2: Smart Contract Architecture Walkthrough (60-90 seconds)
### Segment 3: Test Execution & Results (45-60 seconds)
### Segment 4: Deployment Process (45-60 seconds)
### Segment 5: Security & Optimization Insights (60-90 seconds)
### Segment 6: Closing & Repository (15-30 seconds)

---

## Detailed Script & Screen Actions

### SEGMENT 1: Introduction & Development Environment (30-45 seconds)

**Screen Action:** Show VS Code with project open, terminal visible

**What to Say:**
> "Hi, I'm Rishi Rawat, and I'm excited to walk you through the ACT.X Token implementation—a UUPS-upgradeable ERC-20 rewards token for the BlessUP ecosystem. Let me start by showing you the development environment."

**Screen Action:** 
- Show project structure in VS Code
- Highlight key folders: `src/`, `test/`, `script/`
- Show `foundry.toml` configuration

**What to Say:**
> "I built this using Foundry—a fast, modern Solidity development framework. The project structure is clean: smart contracts in `src/`, comprehensive tests in `test/`, and deployment scripts in `script/`. Notice the `foundry.toml` configuration—we're using Solidity 0.8.26 with the Shanghai EVM, optimizer set to 1000 runs for gas efficiency, and via-IR compilation enabled."

**Screen Action:** Run `forge --version` to show Foundry version

**What to Say:**
> "Foundry gives us blazing-fast compilation and testing, which was crucial for iterating on the contract design."

---

### SEGMENT 2: Smart Contract Architecture Walkthrough (60-90 seconds)

**Screen Action:** Open `src/ACTXToken.sol` in VS Code

**What to Say:**
> "Let's dive into the core contract. ACTXToken is a UUPS-upgradeable ERC-20 with a fixed supply of 100 million tokens. Here's why I made key architectural decisions:"

**Screen Action:** Scroll to storage slot definition (around line 50-60)

**What to Say:**
> "First, I used ERC-7201 namespaced storage. This prevents storage collisions during upgrades—a critical security feature. The storage slot is a keccak256 hash, ensuring it's unique and won't conflict with future implementations."

**Screen Action:** Show the `_update` function override

**What to Say:**
> "The transaction tax mechanism is implemented in the `_update` hook. I chose to override this instead of `transfer` because it catches all token movements—transfers, approvals, and even future integrations. The tax is calculated as a basis point percentage, defaulting to 2%, and sent to a reservoir address that refills the reward pool."

**Screen Action:** Show tax exemption logic

**What to Say:**
> "I added tax exemptions for critical addresses—the treasury, reservoir, and contract itself. This prevents circular taxation and ensures the reward distribution mechanism works correctly."

**Screen Action:** Show `distributeReward` function

**What to Say:**
> "Reward distribution uses role-based access control. Only addresses with the REWARD_MANAGER_ROLE can distribute rewards. I added reentrancy protection here because this function handles external calls and could be vulnerable to reentrancy attacks."

**Screen Action:** Show the upgrade function

**What to Say:**
> "For upgradeability, I chose UUPS over Transparent Proxy because it's more gas-efficient. The upgrade logic lives in the implementation contract, not the proxy, saving gas on every call. However, this requires careful access control—only UPGRADER_ROLE can upgrade, and I've disabled initializers to prevent initialization attacks."

---

### SEGMENT 3: Test Execution & Results (45-60 seconds)

**Screen Action:** Open terminal, run `forge test -vv`

**What to Say:**
> "Now let's run the test suite. I've written 79 comprehensive tests covering unit tests, fuzz tests, and invariant tests."

**Screen Action:** Let tests run, show the output

**What to Say:**
> "We have 58 unit tests covering initialization, ERC-20 functions, tax mechanism, reward distribution, access control, upgradeability, and edge cases. Then 9 fuzz tests that throw random inputs at the contract to find unexpected edge cases. Finally, 12 invariant tests that prove critical properties—like total supply conservation and tax rate limits—hold true across arbitrary operation sequences."

**Screen Action:** Show test results summary

**What to Say:**
> "All 79 tests pass. The fuzz tests ran over 1000 iterations each, and the invariant tests verified properties across thousands of random operations. This gives me high confidence in the contract's correctness and security."

**Screen Action:** Optionally show a specific test file

**What to Say:**
> "For example, this invariant test ensures the reservoir balance only increases—never decreases—which is critical for the recycling mechanism's integrity."

---

### SEGMENT 4: Deployment Process (45-60 seconds)

**Screen Action:** Show `script/Deploy.s.sol`

**What to Say:**
> "Deployment is automated using Foundry scripts. The script handles deploying the implementation, proxy, and optional bonus contracts like Vesting and Airdrop."

**Screen Action:** Show `.env.example` (hide actual `.env`)

**What to Say:**
> "I've configured environment variables for private keys, RPC URLs, and API keys. For security, I'm using a dedicated deployer wallet with minimal permissions."

**Screen Action:** Run deployment command (or show previous deployment output)

**What to Say:**
> "Let's deploy to Base Sepolia testnet. The script will deploy the implementation contract first, then the ERC1967Proxy pointing to it, and finally initialize the contract with roles and initial state."

**Screen Action:** Show deployment transaction on BaseScan

**What to Say:**
> "Here's the deployed contract on BaseScan. The proxy address is what users interact with, while the implementation can be upgraded without changing the proxy address. This maintains address consistency for integrations."

**Screen Action:** Show contract verification

**What to Say:**
> "I've verified the contract source code on BaseScan, so anyone can inspect the implementation and verify its security."

---

### SEGMENT 5: Security & Optimization Insights (60-90 seconds)

**Screen Action:** Show security features in code

**What to Say:**
> "Let me share key security and optimization insights from this implementation:"

**Screen Action:** Highlight ReentrancyGuard usage

**What to Say:**
> "First, security. I used ReentrancyGuard on reward distribution because it handles external calls. The contract is also Pausable, allowing emergency stops if vulnerabilities are discovered. Access control is granular—separate roles for rewards, tax management, and upgrades prevent single points of failure."

**Screen Action:** Show tax rate maximum

**What to Say:**
> "The tax rate is hard-capped at 10% to prevent accidental or malicious rate changes. This is a critical safety measure."

**Screen Action:** Show gas optimization techniques

**What to Say:**
> "For gas optimization, I made several decisions. UUPS saves gas compared to Transparent Proxy because upgrade logic isn't checked on every call. I used custom errors instead of strings for revert messages, saving gas. The storage layout is optimized—frequently accessed variables are packed into single storage slots. And I implemented batch reward distribution to reduce transaction costs when rewarding multiple users."

**Screen Action:** Show upgrade safety measures

**What to Say:**
> "For upgradeability, I disabled initializers in the constructor to prevent initialization attacks. The upgrade function checks for the UPGRADER_ROLE and uses ERC-7201 storage to prevent storage collisions. However, upgrades should always be tested on testnets first and controlled by a multi-sig wallet in production."

**Screen Action:** Show test coverage

**What to Say:**
> "The comprehensive test suite—unit, fuzz, and invariant tests—caught several edge cases during development. For example, the invariant tests revealed that I needed to protect critical addresses from having their tax exemptions removed, which could break the recycling mechanism."

---

### SEGMENT 6: Closing & Repository (15-30 seconds)

**Screen Action:** Show GitHub repository in browser

**What to Say:**
> "The complete implementation, including all contracts, tests, deployment scripts, and documentation, is available on GitHub. The README provides comprehensive architecture documentation, security analysis, and integration guides."

**Screen Action:** Show README sections

**What to Say:**
> "I've documented the RPC node integration plan, which is critical for high-frequency micro-rewards. The architecture supports multiple RPC providers with failover capabilities to ensure low latency and high availability."

**Screen Action:** Final project overview

**What to Say:**
> "This implementation demonstrates production-ready smart contract development with a focus on security, gas efficiency, and upgradeability. Thank you for watching, and I'm happy to answer any questions!"

---

## Key Talking Points to Emphasize

### Security Decisions
1. **ERC-7201 Storage**: Prevents storage collisions during upgrades
2. **ReentrancyGuard**: Protects reward distribution function
3. **Role-Based Access Control**: Granular permissions prevent single points of failure
4. **Tax Rate Cap**: Hard-coded 10% maximum prevents abuse
5. **Initializer Protection**: `_disableInitializers()` prevents initialization attacks

### Gas Optimization
1. **UUPS Pattern**: More gas-efficient than Transparent Proxy
2. **Custom Errors**: Save gas compared to string error messages
3. **Storage Packing**: Optimized variable layout
4. **Batch Operations**: `batchDistributeRewards` reduces transaction costs
5. **Efficient Tax Calculation**: Basis points avoid division operations

### Upgradeability
1. **UUPS Benefits**: Upgrade logic in implementation, not proxy
2. **Access Control**: Only UPGRADER_ROLE can upgrade
3. **Storage Safety**: ERC-7201 prevents collisions
4. **Testing**: Comprehensive upgrade tests ensure safety
5. **Multi-sig Recommendation**: Production upgrades should use multi-sig

---

## Recording Tips

### Technical Setup
1. **Resolution**: Record at 1920x1080 or higher
2. **Frame Rate**: 30 FPS minimum (60 FPS preferred for smooth terminal scrolling)
3. **Audio**: Use a good microphone, minimize background noise
4. **Screen Layout**: 
   - Terminal: Bottom half
   - VS Code: Top half or side-by-side
   - Browser: Switch when needed

### Presentation Tips
1. **Pace**: Speak clearly, don't rush. Pause briefly between sections
2. **Enthusiasm**: Show genuine interest in the technical decisions
3. **Clarity**: Explain technical terms briefly (e.g., "UUPS stands for Universal Upgradeable Proxy Standard")
4. **Eye Contact**: Look at camera occasionally, not just screen
5. **Practice**: Run through the script once before recording

### Editing Tips
1. **Cuts**: Remove long pauses, "umms", and mistakes
2. **Zoom**: Zoom in on code sections when explaining specific functions
3. **Annotations**: Add text overlays for contract addresses or key numbers
4. **Transitions**: Smooth transitions between segments
5. **Music**: Optional light background music (keep it subtle)

---

## Alternative: Live Coding Approach

If you prefer a more dynamic approach, you can:

1. **Start Fresh**: Show a clean terminal, run tests live
2. **Explain as You Go**: Walk through code while scrolling
3. **Interactive**: Show deployment happening in real-time
4. **Debugging**: If something fails, show how you'd debug it

This approach feels more authentic but requires more practice to stay within the 3-5 minute limit.

---

## Post-Production Checklist

- [ ] Video is 3-5 minutes long
- [ ] Audio is clear and consistent
- [ ] Screen text is readable (zoom if needed)
- [ ] All technical demonstrations work correctly
- [ ] GitHub repository link is visible/shown
- [ ] Contract addresses are visible (if showing deployment)
- [ ] No sensitive information (private keys, etc.) is visible
- [ ] Video is exported in high quality (1080p minimum)
- [ ] Upload to YouTube, Vimeo, or preferred platform
- [ ] Add description with GitHub link and key timestamps

---

## Sample Video Description Template

```
ACT.X Token - Smart Contract Implementation Demo

This video demonstrates the development, testing, and deployment of ACT.X Token—a UUPS-upgradeable ERC-20 rewards token for the BlessUP ecosystem.

Timestamps:
0:00 - Introduction & Development Environment
0:45 - Smart Contract Architecture Walkthrough
2:15 - Test Execution & Results
3:00 - Deployment Process
3:45 - Security & Optimization Insights
4:45 - Closing & Repository

Key Features:
- UUPS Upgradeable ERC-20 Token
- Transaction Tax (Recycling Mechanism)
- Role-Based Reward Distribution
- Comprehensive Test Suite (79 tests)
- Gas-Optimized Design

GitHub Repository: https://github.com/SL177Y-0/ACTX

Technologies:
- Solidity 0.8.26
- Foundry Framework
- OpenZeppelin Contracts
- Base Sepolia Testnet

#Solidity #SmartContracts #Blockchain #Foundry #ERC20 #UpgradeableContracts
```

---

## Final Notes

Remember: The goal is to demonstrate your technical skills, decision-making process, and understanding of security and optimization. Be confident, speak clearly, and show your passion for building secure, efficient smart contracts.

Good luck with your video, Rishi!

