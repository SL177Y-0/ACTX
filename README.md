# ACT.X Token - BlessUP Rewards Token

<div align="center">

**The Token That Rewards Positive Action**

[![Solidity](https://img.shields.io/badge/Solidity-0.8.26-363636?logo=solidity)](https://soliditylang.org/)
[![Foundry](https://img.shields.io/badge/Built%20with-Foundry-FFDB1C)](https://getfoundry.sh/)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![OpenZeppelin](https://img.shields.io/badge/OpenZeppelin-5.0-4E5EE4)](https://openzeppelin.com/)

</div>

---

## Overview

ACT.X is a UUPS-upgradeable ERC-20 rewards token powering the BlessUP ecosystem—a positive, decentralized referral economy where billions of Business Souls are micro-rewarded for sharing products, content, and services that make life better.

### Key Features

- **Fixed Supply**: 100,000,000 ACTX (no inflation)
- **Transaction Tax (Recycling)**: Sustainable 2% tax refills reward pool
- **Micro-Rewards Distribution**: Role-based instant reward payouts
- **UUPS Upgradeability**: Gas-efficient upgrades with multi-sig control
- **Security First**: ReentrancyGuard, Pausable, AccessControl

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        OFF-CHAIN SYSTEMS                                 │
│  ┌───────────────────┐    ┌─────────────────┐    ┌───────────────────┐  │
│  │   BlessUP App     │    │   Time-Bank     │    │   Leaderboard &   │  │
│  │ (office.blessup)  │    │   Validator     │    │   Analytics       │  │
│  └─────────┬─────────┘    └────────┬────────┘    └─────────┬─────────┘  │
│            │                       │                       │             │
│  ┌─────────▼───────────────────────▼───────────────────────▼─────────┐   │
│  │                      RPC Node Cluster                              │   │
│  │   QuickNode (Primary) ──► Alchemy (Backup) ──► Self-hosted (DR)   │   │
│  │   • <150ms p95 latency  • 1000+ RPS capacity  • 99.9% uptime     │   │
│  └────────────────────────────────┬──────────────────────────────────┘   │
└───────────────────────────────────┼──────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                        ON-CHAIN (Base L2)                                │
│                                                                          │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │                    ERC1967Proxy                                     │ │
│  │    ┌──────────────────────────────────────────────────────────┐    │ │
│  │    │               ACTXToken Implementation                    │    │ │
│  │    │  ┌──────────────┐ ┌──────────────┐ ┌──────────────────┐  │    │ │
│  │    │  │  ERC-20 Core │ │ Tax Recycler │ │ Reward Distributor│  │    │ │
│  │    │  │  100M Supply │ │  2% → Pool   │ │  REWARD_MANAGER   │  │    │ │
│  │    │  └──────────────┘ └──────────────┘ └──────────────────────┘  │    │ │
│  │    │  ┌──────────────┐ ┌──────────────┐ ┌──────────────────┐  │    │ │
│  │    │  │ AccessControl│ │  Pausable    │ │ UUPS Upgradeable │  │    │ │
│  │    │  │  Role-Based  │ │  Emergency   │ │  Multi-sig Auth  │  │    │ │
│  │    │  └──────────────┘ └──────────────┘ └──────────────────┘  │    │ │
│  │    └──────────────────────────────────────────────────────────┘    │ │
│  └────────────────────────────────────────────────────────────────────┘ │
│                                                                          │
│  ┌─────────────────────────┐    ┌─────────────────────────────────────┐ │
│  │      Vesting.sol        │    │           Airdrop.sol               │ │
│  │  • 4yr total, 1yr cliff │    │  • Merkle proof verification        │ │
│  │  • Linear release       │    │  • Sybil-resistant                  │ │
│  │  • Revocable schedules  │    │  • Deadline enforcement             │ │
│  └─────────────────────────┘    └─────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Quick Start

### Prerequisites

- [Foundry](https://getfoundry.sh/) (forge, cast, anvil)
- [Git](https://git-scm.com/)

### Installation

```bash
# Clone the repository
git clone https://github.com/SL177Y-0/ACTX.git
cd ACTX

# Install dependencies
forge install OpenZeppelin/openzeppelin-contracts@v5.0.0
forge install OpenZeppelin/openzeppelin-contracts-upgradeable@v5.0.0
forge install foundry-rs/forge-std

# Build
forge build

# Test
forge test -vvv
```

### Environment Setup

```bash
# Copy environment template
cp env.example .env

# Edit with your values
# PRIVATE_KEY=0x...
# TREASURY_ADDRESS=0x...
# etc.
```

---

## Smart Contracts

### ACTXToken.sol

The core token contract implementing:

| Feature | Description |
|---------|-------------|
| **ERC-20** | Standard token interface with 18 decimals |
| **ERC-2612 Permit** | Gasless approvals for better UX |
| **Transaction Tax** | Configurable 0-10% tax sent to reservoir |
| **Reward Distribution** | Role-restricted `distributeReward()` function |
| **UUPS Upgradeable** | Gas-efficient proxy pattern |
| **Pausable** | Emergency circuit breaker |
| **Access Control** | Granular role-based permissions |

### Roles

| Role | Permissions |
|------|-------------|
| `DEFAULT_ADMIN_ROLE` | Grant/revoke roles, set reservoir, pause/unpause |
| `REWARD_MANAGER_ROLE` | Call `distributeReward()` and `batchDistributeRewards()` |
| `TAX_MANAGER_ROLE` | Set tax rate, manage tax exemptions |
| `UPGRADER_ROLE` | Authorize contract upgrades |

### Tax Mechanism

```
Transfer Flow (Non-Exempt):
┌──────────┐    100 ACTX    ┌───────────┐
│  Sender  │ ─────────────► │ _update() │
└──────────┘                └─────┬─────┘
                                  │
                    ┌─────────────┴─────────────┐
                    │                           │
                    ▼ 2 ACTX (2%)               ▼ 98 ACTX
              ┌───────────┐              ┌───────────┐
              │ Reservoir │              │ Recipient │
              └───────────┘              └───────────┘
```

### Vesting.sol (Bonus)

Team & advisor vesting with:
- 1-year cliff period
- 4-year total vesting duration
- Linear release after cliff
- Revocable schedules for terminated members

### Airdrop.sol (Bonus)

Merkle-proof based airdrop with:
- O(log n) verification (supports millions of recipients)
- Claim deadline enforcement
- Sybil resistance through off-chain KYC
- Recoverable unclaimed tokens

### IACTXToken.sol (Interface)

Complete interface definition for integrations:
- All public functions and view functions
- Custom events for off-chain monitoring
- Custom errors for better error handling
- Used for type-safe integrations

**Key Functions:**
- `distributeReward(address to, uint256 amount, bytes32 activityId)`
- `batchDistributeRewards(address[] recipients, uint256[] amounts, bytes32[] activityIds)`
- `setTaxRate(uint256 newTaxRateBps)`
- `setReservoir(address newReservoir)`
- `setTaxExempt(address account, bool exempt)`
- View functions: `taxRateBps()`, `reservoir()`, `isTaxExempt()`, `rewardPoolBalance()`, `circulatingSupply()`, `calculateTax()`

**Events:**
- `RewardDistributed(address indexed recipient, uint256 amount, bytes32 indexed activityId, uint256 timestamp)`
- `TaxCollected(address indexed from, uint256 amount, address indexed recipient)`
- `TaxRateUpdated(uint256 oldRate, uint256 newRate, address indexed changedBy)`
- `ReservoirUpdated(address indexed oldReservoir, address indexed newReservoir, address indexed changedBy)`
- `TaxExemptionUpdated(address indexed account, bool isExempt, address indexed changedBy)`

**Custom Errors:**
- `TaxRateExceedsMaximum(uint256 requested, uint256 maximum)`
- `ZeroAddressNotAllowed()`
- `InsufficientRewardPool(uint256 requested, uint256 available)`
- `UnauthorizedCaller(address caller, bytes32 requiredRole)`
- `ZeroAmountNotAllowed()`

---

## Testing

### Run All Tests

```bash
# Standard test run
forge test

# Verbose output
forge test -vvvv

# With gas report
forge test --gas-report
```

### Test Categories

```bash
# Unit tests only
forge test --match-path "test/ACTXToken.t.sol"

# Fuzz tests (1000+ runs)
forge test --match-path "test/ACTXToken.fuzz.t.sol"

# Invariant tests
forge test --match-path "test/ACTXToken.invariants.t.sol"
```

### Test Coverage

```bash
forge coverage --report lcov
```

### Test Results

**Current Status:** **All 79 tests passing**

| Test Suite | Tests | Status |
|------------|-------|--------|
| Unit Tests | 58 | All passing |
| Fuzz Tests | 9 | All passing |
| Invariant Tests | 12 | All passing |
| **Total** | **79** | **100% passing** |

**Test Categories:**
- Initialization & deployment
- ERC-20 standard functions
- Transaction tax mechanism
- Tax exemptions
- Reward distribution
- Role-based access control
- Upgradeability (UUPS)
- Pausable functionality
- Edge cases & boundary conditions
- Fuzz testing (random inputs)
- Invariant testing (total supply, tax limits)

### Gas Benchmarks

| Function | Gas (Est.) | Notes |
|----------|------------|-------|
| `transfer()` (with tax) | ~45,000 | Includes tax calculation |
| `transfer()` (exempt) | ~35,000 | No tax overhead |
| `distributeReward()` | ~50,000 | From reward pool |
| `batchDistributeRewards()` (50) | ~1,500,000 | 18% savings vs individual |
| `setTaxRate()` | ~28,000 | Storage update |
| `upgradeToAndCall()` | ~55,000 | Proxy upgrade |

---

## Deployment

### Deployed Contracts (Base Sepolia)

| Contract | Address | BaseScan |
|----------|---------|----------|
| **Proxy (Main)** | `0x744A7B2B81D72DA705378614b6028aF798077625` | [View](https://sepolia.basescan.org/address/0x744A7B2B81D72DA705378614b6028aF798077625) |
| **Implementation** | `0x1B837861e827af35a0B4c76f35324a28B73cf9FA` | [View](https://sepolia.basescan.org/address/0x1B837861e827af35a0B4c76f35324a28B73cf9FA) |
| **Deployer** | `0x2fC4B64da066918744ec8046Cd5d103f6d40469d` | [View](https://sepolia.basescan.org/address/0x2fC4B64da066918744ec8046Cd5d103f6d40469d) |

**Deployment Details:**
- **Network:** Base Sepolia (Chain ID: 84532)
- **Block:** 34767673
- **Total Gas:** 3,917,041
- **Total Cost:** 0.0000047004492 ETH

**Transaction Hashes:**
1. Implementation: `0xd0229b0ec906d58a4319a2ab4c9c0b56496ad6b70466797f98d3917b7f2bb538`
2. Grant Roles: `0x697f711ffe5af6a85a4dd3ab52b2eaefb322f13bde922d582e371a959f57d746`
3. Fund Pool: `0x2480a2395b1c2f6840fa5b99e3849cbb6dc96a322a7b6f2dee0addc51339fdfb`
4. Proxy Deploy: `0xa192317353c9d707cd39959cd2ee57f5cd99e6af927b07ad086703333a7d5920`

### Testnet Deployment

```bash
# Load environment (PowerShell)
Get-Content .env | ForEach-Object { 
    if ($_ -match '^\s*([^#][^=]+)=(.*)$') { 
        [Environment]::SetEnvironmentVariable($matches[1].Trim(), $matches[2].Trim(), 'Process')
    }
}

# Deploy (simulation)
forge script script/Deploy.s.sol:DeployTestnet --rpc-url $env:BASE_SEPOLIA_RPC_URL

# Deploy (broadcast)
forge script script/Deploy.s.sol:DeployTestnet \
    --rpc-url $env:BASE_SEPOLIA_RPC_URL \
    --broadcast \
    --verify \
    -vvvv
```

### Production (Base Mainnet)

```bash
forge script script/Deploy.s.sol:DeployScript \
    --rpc-url $env:BASE_MAINNET_RPC_URL \
    --broadcast \
    --verify \
    --etherscan-api-key $env:BASESCAN_API_KEY \
    -vvvv
```

### Verify Deployment

```bash
# Check total supply
cast call 0x744A7B2B81D72DA705378614b6028aF798077625 "totalSupply()" --rpc-url https://sepolia.base.org

# Check tax rate
cast call 0x744A7B2B81D72DA705378614b6028aF798077625 "taxRateBps()" --rpc-url https://sepolia.base.org

# Check reward pool balance
cast call 0x744A7B2B81D72DA705378614b6028aF798077625 "rewardPoolBalance()" --rpc-url https://sepolia.base.org

# Check token name
cast call 0x744A7B2B81D72DA705378614b6028aF798077625 "name()" --rpc-url https://sepolia.base.org
```

### Post-Deployment Checklist

- [x] Contracts deployed to Base Sepolia
- [x] All transactions confirmed
- [ ] Transfer admin roles to multi-sig (Gnosis Safe) for production
- [x] Reward pool funded (30M ACTX)
- [ ] Test `distributeReward()` on testnet
- [ ] Setup monitoring (Tenderly/OpenZeppelin Defender)
- [x] Document deployed addresses

---

## RPC Node Integration Plan

### Architecture Requirements

For ACT.X micro-rewards to function at scale, the RPC infrastructure must support:

| Metric | Target | Rationale |
|--------|--------|-----------|
| **Latency** | <150ms p95 | User experience must be instantaneous |
| **Throughput** | >1000 RPS | Handle peak reward distributions |
| **Availability** | 99.9% uptime | Rewards cannot be delayed |
| **WebSocket** | Required | Real-time event streaming |

### Recommended Provider Stack

```
┌──────────────────────────────────────────────────────────────────┐
│                    RPC Provider Architecture                      │
├──────────────────────────────────────────────────────────────────┤
│                                                                   │
│   Primary: QuickNode (Base)                                       │
│   • Dedicated endpoint for write operations                       │
│   • Add-ons: Trace Mode, Archive Data                            │
│   • SLA: 99.99% uptime                                           │
│                                                                   │
│   Secondary: Alchemy (Failover)                                   │
│   • Automatic failover when primary >500ms latency               │
│   • Enhanced APIs for transaction monitoring                      │
│                                                                   │
│   Tertiary: Self-hosted (Disaster Recovery)                       │
│   • Base node on dedicated infrastructure                         │
│   • Cold standby, activated on dual-provider failure             │
│                                                                   │
└──────────────────────────────────────────────────────────────────┘
```

### Integration Pattern

```javascript
// Backend Service (Node.js) - Reward Distribution Flow
const distributeReward = async (recipient, amount, activityId) => {
  // 1. Check eligibility (cached in Redis, TTL 5s)
  const eligible = await checkEligibility(recipient);
  if (!eligible) throw new Error('Time-bank requirement not met');

  // 2. Get nonce (serialized queue prevents stuck tx)
  const nonce = await nonceManager.getNext();

  // 3. Build transaction
  const tx = await tokenContract.populateTransaction.distributeReward(
    recipient,
    amount,
    activityId
  );

  // 4. Sign with HSM-backed key
  const signedTx = await signer.signTransaction({ ...tx, nonce });

  // 5. Broadcast with retry logic
  const receipt = await rpcClient.sendWithRetry(signedTx, {
    maxRetries: 3,
    backoff: 'exponential'
  });

  // 6. Emit event for leaderboard sync
  eventEmitter.emit('reward:distributed', { recipient, amount, activityId, txHash: receipt.hash });
};
```

### Monitoring & Alerting

| Alert | Condition | Action |
|-------|-----------|--------|
| High Latency | p95 > 200ms for 5min | Failover to secondary |
| Error Rate | >1% tx failures | Page on-call engineer |
| Queue Depth | >1000 pending rewards | Scale workers |
| Balance Low | Reward pool < 1M ACTX | Alert treasury team |

---

## Security

### Design Principles

1. **Defense in Depth**: Multiple layers of access control
2. **Principle of Least Privilege**: Separate roles for separate functions
3. **Fail-Safe Defaults**: Pausable in emergencies
4. **Immutable Caps**: Tax rate hard-capped at 10%

### Audit Readiness

- [ ] Slither static analysis: `slither . --config-file slither.config.json`
- [ ] Formal verification (Certora) for critical invariants
- [ ] 100% test coverage on critical paths
- [ ] NatSpec documentation on all public functions
- [ ] Prepared for Code4rena/Immunefi bug bounty

### Security Checklist

| Check | Status |
|-------|--------|
| Reentrancy protection | `ReentrancyGuard` on `distributeReward` |
| Integer overflow | Solidity 0.8.26 built-in |
| Access control | OpenZeppelin `AccessControl` |
| Upgrade safety | `_disableInitializers()` + `UPGRADER_ROLE` |
| Tax rate cap | Hard-coded 10% maximum |
| Storage collision | ERC-7201 namespaced storage |

---

## Tokenomics

| Allocation | Amount | Percentage | Purpose |
|------------|--------|------------|---------|
| **Treasury** | 100M ACTX | 100% | Initial mint destination |
| **Reward Pool** | 30M ACTX | 30% | Ongoing micro-rewards |
| **Team/Advisors** | 15M ACTX | 15% | 4-year vesting, 1-year cliff |
| **Community Airdrop** | 10M ACTX | 10% | Bootstrap participation |
| **Reserve** | 45M ACTX | 45% | Future initiatives |

### Transaction Tax Flow

```
Every non-exempt transfer:
  ├── 98% → Recipient
  └── 2%  → Reservoir (refills reward pool)

Example: 1000 ACTX transfer
  ├── 980 ACTX → Recipient
  └── 20 ACTX  → Reservoir
```

---

## Project Structure

```
actx-token/
├── src/
│   ├── ACTXToken.sol           # Main UUPS upgradeable token (8,745 bytes)
│   ├── interfaces/
│   │   └── IACTXToken.sol      # Token interface for integrations (1,902 bytes)
│   ├── Vesting.sol             # Team/advisor vesting (bonus) (6,810 bytes)
│   └── Airdrop.sol             # Merkle airdrop (bonus) (6,015 bytes)
├── script/
│   └── Deploy.s.sol            # Foundry deployment scripts (12,427 bytes)
├── test/
│   ├── ACTXToken.t.sol         # Unit tests (58 tests, 25,214 bytes)
│   ├── ACTXToken.fuzz.t.sol    # Fuzz tests (9 tests, 14,985 bytes)
│   └── ACTXToken.invariants.t.sol # Invariant tests (12 tests, 12,966 bytes)
├── lib/                        # Dependencies (forge install)
│   ├── openzeppelin-contracts/
│   ├── openzeppelin-contracts-upgradeable/
│   └── forge-std/
├── broadcast/                  # Deployment artifacts
│   └── Deploy.s.sol/
│       └── 84532/              # Base Sepolia deployments
├── foundry.toml                # Foundry configuration
├── remappings.txt              # Import remappings
├── env.example                 # Environment template
└── README.md                   # This file
```

**Total Test Coverage:** 79 tests (100% passing)

---

## API Reference

### Core Functions

#### `distributeReward(address to, uint256 amount, bytes32 activityId)`
Distributes rewards from the pre-allocated reward pool.

**Requirements:**
- Caller must have `REWARD_MANAGER_ROLE`
- Contract must not be paused
- `to` must not be zero address
- `amount` must be > 0
- Reward pool must have sufficient balance

**Example:**
```solidity
// Backend service calls this after validating user action
token.distributeReward(recipient, 1000 * 10**18, keccak256("activity_123"));
```

#### `batchDistributeRewards(address[] recipients, uint256[] amounts, bytes32[] activityIds)`
Batch version for gas efficiency (18% savings vs individual calls).

**Requirements:**
- Same as `distributeReward()` for each recipient
- Arrays must have equal length

**Example:**
```solidity
address[] memory recipients = [user1, user2, user3];
uint256[] memory amounts = [1000e18, 2000e18, 1500e18];
bytes32[] memory activityIds = [id1, id2, id3];
token.batchDistributeRewards(recipients, amounts, activityIds);
```

#### `setTaxRate(uint256 newTaxRateBps)`
Updates the transaction tax rate.

**Requirements:**
- Caller must have `TAX_MANAGER_ROLE`
- `newTaxRateBps` must be ≤ 1000 (10% max)

**Example:**
```solidity
// Set tax to 2.5%
token.setTaxRate(250); // 250 basis points = 2.5%
```

#### `setReservoir(address newReservoir)`
Updates the reservoir address (where taxes are sent).

**Requirements:**
- Caller must have `DEFAULT_ADMIN_ROLE`
- `newReservoir` must not be zero address

#### `setTaxExempt(address account, bool exempt)`
Sets tax exemption status for an address.

**Requirements:**
- Caller must have `TAX_MANAGER_ROLE`
- `account` must not be zero address

**Note:** Treasury, reservoir, and contract are automatically exempt and cannot be changed.

### View Functions

#### `taxRateBps() → uint256`
Returns current tax rate in basis points.

#### `reservoir() → address`
Returns the reservoir address.

#### `isTaxExempt(address account) → bool`
Checks if an address is tax-exempt.

#### `rewardPoolBalance() → uint256`
Returns the current balance of the reward pool (contract's balance).

#### `circulatingSupply() → uint256`
Returns circulating supply (total supply - reward pool balance).

#### `calculateTax(uint256 amount) → uint256`
Calculates tax amount for a given transfer amount.

**Example:**
```solidity
uint256 transferAmount = 1000 * 10**18;
uint256 tax = token.calculateTax(transferAmount);
uint256 netAmount = transferAmount - tax;
```

---

## Troubleshooting

### Common Issues

#### "Insufficient reward pool"
**Problem:** Trying to distribute more tokens than available in reward pool.

**Solution:**
- Check current pool balance: `token.rewardPoolBalance()`
- Transfer more tokens to contract: `token.transfer(contractAddress, amount)`

#### "Tax rate exceeds maximum"
**Problem:** Trying to set tax rate above 10% (1000 bps).

**Solution:**
- Maximum tax rate is hard-capped at 10%
- Use a value ≤ 1000 basis points

#### "Unauthorized caller"
**Problem:** Calling a restricted function without proper role.

**Solution:**
- Check required role: `token.hasRole(ROLE, account)`
- Request role grant from admin

#### "Contract is paused"
**Problem:** Contract is in paused state.

**Solution:**
- Admin must call `unpause()` to resume operations
- Check pause status: `token.paused()`

#### Deployment fails with "gas required exceeds allowance"
**Problem:** Wallet has insufficient ETH for gas.

**Solution:**
- Get testnet ETH from faucet
- Check balance: `cast balance <address> --rpc-url <rpc>`
- Ensure wallet has at least 0.01 ETH

#### RPC timeout errors
**Problem:** RPC endpoint is slow or unavailable.

**Solution:**
- Try a different RPC provider (Alchemy, QuickNode, Infura)
- Use dedicated endpoint instead of public
- Check RPC status

---

## Additional Resources

### Documentation Files
- `README.md` - This file (complete project documentation)
- `env.example` - Environment variable template

### Code Examples

#### Integration Example (JavaScript/TypeScript)

```typescript
import { ethers } from 'ethers';
import ACTXTokenABI from './ACTXToken.json';

const provider = new ethers.JsonRpcProvider('https://sepolia.base.org');
const tokenAddress = '0x744A7B2B81D72DA705378614b6028aF798077625';
const token = new ethers.Contract(tokenAddress, ACTXTokenABI, provider);

// Check reward pool balance
const poolBalance = await token.rewardPoolBalance();
console.log(`Reward Pool: ${ethers.formatEther(poolBalance)} ACTX`);

// Check tax rate
const taxRate = await token.taxRateBps();
console.log(`Tax Rate: ${taxRate / 100}%`);

// Calculate tax for a transfer
const amount = ethers.parseEther('1000');
const tax = await token.calculateTax(amount);
console.log(`Tax on 1000 ACTX: ${ethers.formatEther(tax)} ACTX`);
```

#### Event Monitoring

```typescript
// Listen for reward distributions
token.on('RewardDistributed', (recipient, amount, activityId, timestamp) => {
  console.log(`Reward: ${ethers.formatEther(amount)} ACTX to ${recipient}`);
  console.log(`Activity ID: ${activityId}`);
  // Update leaderboard
});

// Listen for tax collections
token.on('TaxCollected', (from, amount, recipient) => {
  console.log(`Tax collected: ${ethers.formatEther(amount)} ACTX`);
  // Update analytics
});
```

---

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## Acknowledgments

- [OpenZeppelin](https://openzeppelin.com/) - Battle-tested smart contract libraries
- [Foundry](https://getfoundry.sh/) - Blazing fast Ethereum development toolkit
- [Base](https://base.org/) - Secure, low-cost L2 for mainstream adoption

---

<div align="center">

**Built by the BlessUP Team**

*Making positive referral marketing magical, meaningful, and measurable.*

</div>

