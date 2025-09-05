// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19 <=0.8.30;

import {IERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "./PriceOracle.sol";

interface IERC20Decimals is IERC20 {
    function decimals() external view returns (uint8);
}

contract LendingPool {
    // Libraries
    using SafeERC20 for IERC20;

    //State Variables
    PriceOracle public priceOracle;
    address public owner;
    mapping(address => bool) public supportedTokens;
    mapping(address => uint256) public collateralFactors; // in basis points (e.g., 7500 = 75%)
    address[] public tokenList;
    mapping(address => mapping(address => uint256)) public deposits; // user => token => amount
    mapping(address => mapping(address => uint256)) public borrows; // user => token => amount
    mapping(address => uint256) public availableLiquidity; // token => available amount

    //Events
    event Deposit(address indexed user, address indexed token, uint256 amount);
    event Withdraw(address indexed user, address indexed token, uint256 amount);
    event Borrow(address indexed user, address indexed token, uint256 amount);
    event Repay(address indexed user, address indexed token, uint256 amount);
    event TokenAdded(address indexed token, uint256 collateralFactor);
    event TokenRemoved(address indexed token);
    event CollateralFactorUpdated(
        address indexed token,
        uint256 oldFactor,
        uint256 newFactor
    );

    //Custom Errors
    error DepositBelowMinimum(uint256 sent, uint256 minimum);
    error InsufficientBalance(uint256 balance, uint256 requested);
    error RepayAmountExceedsBorrowed(uint256 requested, uint256 available);
    error InsufficientCollateral(uint256 required, uint256 available);
    error TokenNotSupported(address token);
    error OnlyOwner();
    error InvalidCollateralFactor();
    error HealthFactorTooLow();

    constructor(address _priceOracle) {
        priceOracle = PriceOracle(_priceOracle);
        owner = msg.sender;
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert OnlyOwner();
        _;
    }

    modifier onlySupportedToken(address token) {
        if (!supportedTokens[token]) revert TokenNotSupported(token);
        _;
    }

    function addSupportedToken(
        address token,
        uint256 collateralFactor
    ) external onlyOwner {
        if (token == address(0)) revert InvalidCollateralFactor();
        if (collateralFactor > 9500) revert InvalidCollateralFactor();
        require(!supportedTokens[token], "Token already supported");
        supportedTokens[token] = true;
        collateralFactors[token] = collateralFactor;
        tokenList.push(token);

        availableLiquidity[token] = IERC20(token).balanceOf(address(this));

        emit TokenAdded(token, collateralFactor);
    }

    function removeSupportedToken(address token) external onlyOwner {
        if (!supportedTokens[token]) revert TokenNotSupported(token);
        supportedTokens[token] = false;
        // remove from tokenList array
        for (uint i = 0; i < tokenList.length; i++) {
            if (tokenList[i] == token) {
                tokenList[i] = tokenList[tokenList.length - 1];
                tokenList.pop();
                break;
            }
        }
        emit TokenRemoved(token);
    }

    function getTotalCollateralValue(
        address user
    ) public view returns (uint256) {
        address[] memory tokensCopy = tokenList; // ✅ Gas optimization
        uint256 totalValue = 0;
        for (uint i = 0; i < tokensCopy.length; i++) {
            address token = tokensCopy[i];
            uint256 depositedAmount = deposits[user][token];
            if (depositedAmount > 0) {
                uint256 price = priceOracle.getPrice(token);
                uint256 decimals = IERC20Decimals(token).decimals();
                uint256 value = (depositedAmount * price) / (10 ** decimals);
                uint256 collateralValue = (value * collateralFactors[token]) /
                    10000;
                totalValue += collateralValue;
            }
        }
        return totalValue;
    }

    function getTotalBorrowValue(address user) public view returns (uint256) {
        address[] memory tokensCopy = tokenList; // ✅ Gas optimization
        uint256 totalBorrow = 0;

        for (uint256 i = 0; i < tokensCopy.length; i++) {
            address tokenAddress = tokensCopy[i];
            uint256 borrowedAmount = borrows[user][tokenAddress];

            if (borrowedAmount > 0 && supportedTokens[tokenAddress]) {
                uint256 price = priceOracle.getPrice(tokenAddress);
                uint256 decimals = IERC20Decimals(tokenAddress).decimals();
                uint256 value = (borrowedAmount * price) / (10 ** decimals);

                totalBorrow += value;
            }
        }
        return totalBorrow;
    }

    function getHealthFactor(address user) public view returns (uint256) {
        uint256 totalBorrowValue = getTotalBorrowValue(user);
        uint256 totalCollateralValue = getTotalCollateralValue(user);
        if (totalBorrowValue == 0) {
            return type(uint256).max;
        }
        uint256 healthfactor = (totalCollateralValue * 10000) /
            totalBorrowValue;
        return healthfactor;
    }

    function getAvailableLiquidity(
        address token
    ) external view returns (uint256) {
        return availableLiquidity[token];
    }

    function getTotalLiquidityValue() external view returns (uint256) {
    uint256 totalLiquidity = 0;
    for(uint256 i = 0; i < tokenList.length; i++) {
        address token = tokenList[i];
        uint256 liquidity = availableLiquidity[token];
        if(liquidity > 0) {
            uint256 price = priceOracle.getPrice(token);
            uint256 decimals = IERC20Decimals(token).decimals();
            uint256 value = (liquidity * price) / (10 ** decimals);
            totalLiquidity += value;
        }
    }
    return totalLiquidity;
}

    function deposit(
        address token,
        uint256 amount
    ) external onlySupportedToken(token) {
        uint256 tokenDecimals = IERC20Decimals(token).decimals();
        uint256 minDeposit = 10 ** tokenDecimals; // 1 unit of the token

        if (amount < minDeposit) {
            revert DepositBelowMinimum(amount, minDeposit);
        }

        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        deposits[msg.sender][token] += amount;
        availableLiquidity[token] += amount;

        emit Deposit(msg.sender, token, amount);
    }

    function withdraw(address token, uint256 amount) external onlySupportedToken(token) {
        uint256 userbalance = deposits[msg.sender][token];
        if (userbalance < amount) {
            revert InsufficientBalance(userbalance, amount);
        }
        deposits[msg.sender][token] -= amount;
        availableLiquidity[token] -= amount;
        uint256 healthFactor = getHealthFactor(msg.sender);

        if (healthFactor < 10000) {
            deposits[msg.sender][token] += amount; // Restore deposit
            revert HealthFactorTooLow();
        }

        IERC20(token).safeTransfer(msg.sender, amount);
        emit Withdraw(msg.sender, token, amount);
    }

    function borrow(
        address token,
        uint256 amount
    ) external onlySupportedToken(token) {
        uint256 totalCollateralValue = getTotalCollateralValue(msg.sender);
        uint256 totalBorrowValue = getTotalBorrowValue(msg.sender);

        // Calculate new borrow value
        uint256 price = priceOracle.getPrice(token);
        uint256 decimals = IERC20Decimals(token).decimals();
        uint256 newBorrowValue = (amount * price) / (10 ** decimals);

        if (totalBorrowValue + newBorrowValue > totalCollateralValue) {
            revert InsufficientCollateral(
                totalBorrowValue + newBorrowValue,
                totalCollateralValue
            );
        }

        uint256 poolBalance = IERC20(token).balanceOf(address(this));
        if (amount > poolBalance) {
            revert InsufficientBalance(poolBalance, amount);
        }

        // Execute borrow
        IERC20(token).safeTransfer(msg.sender, amount);
        borrows[msg.sender][token] += amount;
        availableLiquidity[token] -= amount;

        emit Borrow(msg.sender, token, amount);
    }

    function repay(
        address token,
        uint256 amount
    ) external onlySupportedToken(token) {
        uint256 borrowedAmount = borrows[msg.sender][token];
        if (amount > borrowedAmount) {
            revert RepayAmountExceedsBorrowed(amount, borrowedAmount);
        }
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        borrows[msg.sender][token] -= amount;
        availableLiquidity[token] += amount;

        emit Repay(msg.sender, token, amount);
    }
}
