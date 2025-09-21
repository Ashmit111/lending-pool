// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19 <=0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {LendingPool} from "../src/LendingPool.sol";
import {PriceOracle} from "../src/PriceOracle.sol";

contract DeployScript is Script {
    function run() external {

        if(block.chainid == 31337) {
            console.log("Using Anvil account");
        } else if(block.chainid == 11155111) {
            console.log("Using Sepolia account");
        } else if(block.chainid == 1) {
            console.log("Using Mainnet account");
        } else {
            revert("Unsupported chain");
        }

        vm.startBroadcast();

        PriceOracle priceOracle = new PriceOracle();
        console.log("PriceOracle deployed at:", address(priceOracle));

        LendingPool lendingPool = new LendingPool(address(priceOracle));
        console.log("LendingPool deployed at:", address(lendingPool));

        vm.stopBroadcast();

        console.log("Deployment complete");
        console.log("Deploer address:", msg.sender);
    }
}