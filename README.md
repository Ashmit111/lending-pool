# DeFi Lending Pool

A decentralized lending and borrowing protocol built with Solidity using the Foundry framework. This project implements a collateralized lending pool where users can deposit assets as collateral and borrow other supported tokens based on their collateral value.

## 📋 Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Architecture](#architecture)
- [Smart Contracts](#smart-contracts)
- [Installation](#installation)
- [Usage](#usage)
- [Testing](#testing)
- [Deployment](#deployment)
- [Security Considerations](#security-considerations)
- [License](#license)

## 🎯 Overview

This lending pool protocol enables users to:
- **Deposit** ERC20 tokens as collateral
- **Borrow** supported tokens against their collateral
- **Repay** borrowed amounts
- **Withdraw** deposited collateral (if health factor allows)

The protocol uses **Chainlink Price Feeds** for accurate price data and implements a health factor mechanism to ensure protocol solvency.

## ✨ Features

### Core Functionality
- **Multi-Token Support**: Support for multiple ERC20 tokens with configurable collateral factors
- **Collateralized Borrowing**: Borrow tokens based on deposited collateral value
- **Health Factor Protection**: Prevents under-collateralized positions
- **Real-Time Price Feeds**: Integration with Chainlink oracles for accurate asset pricing
- **Dynamic Liquidity Tracking**: Real-time tracking of available liquidity per token

### Safety Features
- **Collateral Factors**: Customizable loan-to-value (LTV) ratios per token (in basis points)
- **Health Factor Checks**: Ensures users maintain adequate collateral (health factor ≥ 1.0 = 10000 basis points)
- **Stale Price Protection**: Rejects price data older than 1 hour
- **Secure Token Transfers**: Uses OpenZeppelin's `SafeERC20` library

### Administrative Features
- **Owner-Only Controls**: Token management restricted to contract owner
- **Flexible Configuration**: Add/remove supported tokens dynamically
- **Collateral Factor Updates**: Adjust risk parameters as needed

## 🏗 Architecture

### System Flow

```
┌─────────────┐          ┌──────────────┐          ┌────────────────┐
│   User      │◄────────►│ LendingPool  │◄────────►│  PriceOracle   │
└─────────────┘          └──────────────┘          └────────────────┘
                                │                           │
                                │                           │
                                ▼                           ▼
                         ┌──────────────┐          ┌────────────────┐
                         │  ERC20 Tokens│          │ Chainlink Feeds│
                         └──────────────┘          └────────────────┘
```

### Key Calculations

**Total Collateral Value**:
```
For each deposited token:
  value = (amount × price) / (10^decimals)
  collateral_value = value × (collateralFactor / 10000)
Total = Sum of all collateral values
```

**Total Borrow Value**:
```
For each borrowed token:
  value = (amount × price) / (10^decimals)
Total = Sum of all borrow values
```

**Health Factor**:
```
health_factor = (totalCollateralValue × 10000) / totalBorrowValue

If health_factor < 10000 (i.e., < 1.0), position is under-collateralized
```

## 📦 Smart Contracts

### 1. LendingPool.sol

The main contract handling all lending operations.

**Key State Variables:**
```solidity
PriceOracle public priceOracle;              // Price feed oracle
mapping(address => bool) public supportedTokens;  // Whitelisted tokens
mapping(address => uint256) public collateralFactors;  // LTV ratios (basis points)
mapping(address => mapping(address => uint256)) public deposits;  // User deposits
mapping(address => mapping(address => uint256)) public borrows;   // User borrows
mapping(address => uint256) public availableLiquidity;  // Pool liquidity
```

**Main Functions:**

| Function | Description | Access |
|----------|-------------|--------|
| `deposit(address token, uint256 amount)` | Deposit tokens as collateral | Public |
| `withdraw(address token, uint256 amount)` | Withdraw deposited tokens | Public |
| `borrow(address token, uint256 amount)` | Borrow tokens against collateral | Public |
| `repay(address token, uint256 amount)` | Repay borrowed tokens | Public |
| `addSupportedToken(address token, uint256 collateralFactor)` | Add new supported token | Owner Only |
| `removeSupportedToken(address token)` | Remove token support | Owner Only |
| `getTotalCollateralValue(address user)` | Calculate user's total collateral in USD | View |
| `getTotalBorrowValue(address user)` | Calculate user's total borrow in USD | View |
| `getHealthFactor(address user)` | Calculate user's health factor | View |
| `getTotalLiquidityValue()` | Get total pool liquidity in USD | View |

### 2. PriceOracle.sol

Chainlink-based price oracle for accurate asset pricing.

**Key Features:**
- Supports multiple price feeds
- Normalizes all prices to 8 decimals
- Validates price freshness (< 1 hour old)
- Validates price sanity (> 0)

**Main Functions:**

| Function | Description | Access |
|----------|-------------|--------|
| `setPriceFeed(address token, address priceFeed)` | Configure price feed for token | Owner Only |
| `removePriceFeed(address token)` | Remove price feed | Owner Only |
| `getPrice(address token)` | Get current token price (8 decimals) | Public |

**Price Normalization:**
```solidity
// All prices normalized to 8 decimals for consistency
if (feedDecimals < 8) {
    adjustedPrice = price × 10^(8 - feedDecimals)
} else if (feedDecimals > 8) {
    adjustedPrice = price / 10^(feedDecimals - 8)
}
```

## 🚀 Installation

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- Git

### Setup

1. Clone the repository:
```bash
git clone <repository-url>
cd lending-pool
```

2. Install dependencies:
```bash
forge install
```

3. Build the project:
```bash
forge build
```

## 💻 Usage

### Build

Compile the smart contracts:
```bash
forge build
```

### Format Code

Format Solidity files:
```bash
forge fmt
```

### Gas Snapshots

Generate gas usage reports:
```bash
forge snapshot
```

### Local Development

1. Start a local Anvil node:
```bash
anvil
```

2. Deploy to local network:
```bash
forge script script/Lending.s.sol:DeployScript --rpc-url http://127.0.0.1:8545 --broadcast
```

3. Interact with deployed contracts:
```bash
forge script script/Interact.s.sol:InteractScript --rpc-url http://127.0.0.1:8545 --broadcast
```

## 🧪 Testing

The project includes comprehensive unit tests covering:

✅ **Access Control**
- Only owner can add supported tokens
- Non-owners cannot modify protocol settings

✅ **Deposit Functionality**
- Successful deposits to supported tokens
- Rejection of unsupported tokens
- Minimum deposit enforcement
- Liquidity tracking

✅ **Withdrawal Functionality**
- Successful withdrawals
- Insufficient balance checks
- Health factor validation after withdrawal

✅ **Borrow Functionality**
- Borrowing with sufficient collateral
- Insufficient collateral rejection
- Liquidity availability checks

✅ **Repay Functionality**
- Full and partial repayment
- Over-repayment prevention

### Run Tests

Run all tests:
```bash
forge test
```

Run tests with verbosity:
```bash
forge test -vvv
```

Run specific test:
```bash
forge test --match-test testDeposit -vvv
```

Run tests with gas report:
```bash
forge test --gas-report
```

## 🌐 Deployment

### Supported Networks

- **Anvil** (Local): Chain ID 31337
- **Sepolia** (Testnet): Chain ID 11155111
- **Ethereum Mainnet**: Chain ID 1

### Deploy to Sepolia

1. Set up environment variables:
```bash
export PRIVATE_KEY=<your_private_key>
export SEPOLIA_RPC_URL=<your_sepolia_rpc_url>
```

2. Deploy contracts:
```bash
forge script script/Lending.s.sol:DeployScript \
  --rpc-url $SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --verify
```

### Deployment Process

The `Lending.s.sol` script deploys:
1. **PriceOracle** contract
2. **LendingPool** contract (with PriceOracle address)

### Post-Deployment Setup

After deployment, use `Interact.s.sol` to:
1. Set up Chainlink price feeds
2. Add supported tokens with collateral factors
3. Demonstrate user flows (deposit, borrow, repay)

**Example Collateral Factors:**
- WETH: 7500 (75% LTV)
- USDC: 8500 (85% LTV)

## 🔐 Security Considerations

### Implemented Safeguards

1. **SafeERC20**: Protects against non-standard token implementations
2. **Health Factor Checks**: Prevents under-collateralized positions
3. **Price Validation**: 
   - Rejects negative/zero prices
   - Rejects stale data (>1 hour old)
4. **Access Control**: Owner-only functions for critical operations
5. **Reentrancy Protection**: Uses checks-effects-interactions pattern

### Known Limitations

⚠️ **Important Notes:**
- No interest rate mechanism implemented
- No liquidation system (positions can become under-collateralized over time)
- No flash loan protection
- No pause mechanism for emergencies
- Collateral factors are static (no dynamic risk adjustment)

### Recommendations for Production

Before deploying to mainnet:
1. ✅ Add comprehensive liquidation mechanism
2. ✅ Implement interest accrual for borrows and deposits
3. ✅ Add emergency pause functionality
4. ✅ Implement timelock for administrative functions
5. ✅ Add events for all state changes
6. ✅ Conduct professional security audit
7. ✅ Implement governance mechanism
8. ✅ Add flash loan protection
9. ✅ Consider upgradeability patterns

## 📁 Project Structure

```
lending-pool/
├── src/
│   ├── LendingPool.sol      # Main lending pool contract
│   └── PriceOracle.sol       # Chainlink price oracle wrapper
├── script/
│   ├── Lending.s.sol         # Deployment script
│   └── Interact.s.sol        # Interaction script
├── test/
│   └── Lending.t.sol         # Unit tests
├── lib/
│   ├── forge-std/            # Foundry testing utilities
│   ├── openzeppelin-contracts/  # OpenZeppelin libraries
│   └── chainlink-evm/        # Chainlink contracts
├── foundry.toml              # Foundry configuration
└── README.md                 # This file
```

## 🛠 Technologies Used

- **Solidity** ^0.8.19-0.8.30
- **Foundry** - Development framework
- **OpenZeppelin** - Secure smart contract libraries
- **Chainlink** - Decentralized price feeds
- **Forge** - Testing and deployment

## 📊 Example Usage Flow

```solidity
// 1. Owner adds supported tokens
lendingPool.addSupportedToken(WETH, 7500);  // 75% LTV
lendingPool.addSupportedToken(USDC, 8500);  // 85% LTV

// 2. User deposits collateral
WETH.approve(lendingPool, 10 ether);
lendingPool.deposit(WETH, 10 ether);

// 3. User checks borrowing power
uint256 collateral = lendingPool.getTotalCollateralValue(user);
// collateral = 10 ETH × $2000 × 0.75 = $15,000

// 4. User borrows
lendingPool.borrow(USDC, 10000 * 1e6);  // Borrow 10,000 USDC

// 5. Check health factor
uint256 healthFactor = lendingPool.getHealthFactor(user);
// healthFactor = 15000 / 10000 × 10000 = 15000 (1.5)

// 6. Repay loan
USDC.approve(lendingPool, 10000 * 1e6);
lendingPool.repay(USDC, 10000 * 1e6);

// 7. Withdraw collateral
lendingPool.withdraw(WETH, 10 ether);
```

## 📝 License

This project is licensed under the MIT License.

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📧 Contact

For questions or support, please open an issue in the repository.

---

**Disclaimer**: This is an educational project. Do not use in production without proper auditing and implementing additional safety mechanisms.
