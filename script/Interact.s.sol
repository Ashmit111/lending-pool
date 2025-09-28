// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19 <=0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {LendingPool} from "../src/LendingPool.sol";
import {PriceOracle} from "../src/PriceOracle.sol";
import {IERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract InteractScript is Script {
    address constant LENDING_POOL_ADDRESS = 0xBE5b948c6a3C7727c63E3EAEA799E4593a31dAaA; 
    address constant PRICE_ORACLE_ADDRESS = 0x5c9d5Bd2dC14ED356399f9364ceb0987A5DB2814;

    address constant WETH_ADDRESS = 0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9;
    address constant USDC_ADDRESS = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238; // Sepolia USDC (example)
    
    // Price feed addresses for Chainlink oracles (Sepolia testnet examples)
    address constant ETH_USD_PRICE_FEED = 0x694AA1769357215DE4FAC081bf1f309aDC325306; // ETH/USD on Sepolia
    address constant USDC_USD_PRICE_FEED = 0xA2F78ab2355fe2f984D808B5CeE7FD0A93D5270E; // USDC/USD on Sepolia

    function run() external {
        LendingPool lendingPool = LendingPool(LENDING_POOL_ADDRESS);
        PriceOracle priceOracle = PriceOracle(PRICE_ORACLE_ADDRESS);

        console.log("=== Starting Lending Pool Interaction ===");
        console.log("LendingPool address:", LENDING_POOL_ADDRESS);
        console.log("PriceOracle address:", PRICE_ORACLE_ADDRESS);
        console.log("User address:", msg.sender);

        vm.startBroadcast();

        setupPriceFeeds(priceOracle);

        setupSupportedTokens(lendingPool);

        demonstrateUserFlow(lendingPool);

        vm.stopBroadcast();

        console.log("=== Interaction Complete ===");
    }

    function setupPriceFeeds(PriceOracle priceOracle) internal {
        console.log("Setting up price feeds...");

        priceOracle.setPriceFeed(WETH_ADDRESS, ETH_USD_PRICE_FEED);
        priceOracle.setPriceFeed(USDC_ADDRESS, USDC_USD_PRICE_FEED);
        console.log("Price feeds set for WETH and USDC");

        try priceOracle.getPrice(WETH_ADDRESS) returns (uint256 price) {
            console.log("WETH Price (USD):", price);
        } catch {
            console.log("Failed to fetch WETH price");
        }

        try priceOracle.getPrice(USDC_ADDRESS) returns (uint256 price) {
            console.log("USDC Price (USD):", price);
        } catch {
            console.log("Failed to fetch USDC price");
        }
    }

    function setupSupportedTokens(LendingPool lendingPool) internal {
        console.log("Setting up supported tokens...");

        lendingPool.addSupportedToken(WETH_ADDRESS, 7500); // 
        lendingPool.addSupportedToken(USDC_ADDRESS, 8500); // 
        console.log("Supported tokens added: WETH and USDC");
    }

    function demonstrateUserFlow(LendingPool lendingPool) internal {
        console.log("Demonstrating user flow...");

        IERC20 weth = IERC20(WETH_ADDRESS);
        IERC20 usdc = IERC20(USDC_ADDRESS);

        uint256 userWethBalance = weth.balanceOf(msg.sender);
        uint256 userUsdcBalance = usdc.balanceOf(msg.sender);

        console.log(userWethBalance);
        console.log(userUsdcBalance);

        if(userWethBalance > 0){
            depositTokens(lendingPool, weth, userWethBalance/2);
        }
        if(userUsdcBalance > 0){
            depositTokens(lendingPool, usdc, userUsdcBalance/4);
        }

        showUserPosition(lendingPool, msg.sender);

        uint256 collateralValue = lendingPool.getTotalCollateralValue(msg.sender);
        if(collateralValue > 0){
            attemptBorrow(lendingPool, USDC_ADDRESS, 1000 * 1e6);
        }

        showUserPosition(lendingPool, msg.sender);
    }

    function depositTokens(LendingPool  lendingPool, IERC20 token, uint256 amount) internal {
        console.log("Depositing tokens...");

        token.approve(address(lendingPool), amount);

        try lendingPool.deposit(address(token), amount) {
            console.log("Deposited", amount, "of token", address(token));
        } catch Error(string memory reason) {
            console.log("Deposit failed for token", reason);
        }
    }

    function attemptBorrow(LendingPool lendingPool, address tokenAddress, uint256 amount) internal {
        console.log("Attempting to borrow...");
        console.log("Trying to borrow", amount, "of token", tokenAddress);

        try lendingPool.borrow(tokenAddress, amount) {
            console.log("Successfully borrowed", amount, "of token", tokenAddress);
        } catch Error(string memory reason) {
            console.log("Borrow failed:", reason);
        }
    }

    function showUserPosition(LendingPool lendingPool, address user) internal {
        uint256 totalCollateral = lendingPool.getTotalCollateralValue(user);
        uint256 totalBorrow = lendingPool.getTotalBorrowValue(user);
        uint256 healthFactor = lendingPool.getHealthFactor(user);

        console.log("User Position:");
        console.log("Total Collateral (USD):", totalCollateral);
        console.log("Total Borrow (USD):", totalBorrow);
        console.log("Health Factor:", healthFactor);
    }

    function showPoolState(LendingPool lendingPool) internal view {
        try lendingPool.getTotalLiquidityValue() returns (uint256 totalLiquidity) {
            console.log("Total Liquidity in Pool (USD):", totalLiquidity);
        } catch {
            console.log("Failed to fetch total liquidity");
        }

        try lendingPool.getAvailableLiquidity(WETH_ADDRESS) returns (uint256 wethLiquidity) {
            console.log("Available WETH Liquidity:", wethLiquidity);
        } catch {
            console.log("Failed to fetch WETH liquidity");
        }

        try lendingPool.getAvailableLiquidity(USDC_ADDRESS) returns (uint256 usdcLiquidity) {
            console.log("Available USDC Liquidity:", usdcLiquidity);
        } catch {
            console.log("Failed to fetch USDC liquidity");
        }
    }
}
