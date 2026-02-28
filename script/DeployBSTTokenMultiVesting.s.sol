// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import "../src/BSTTokenMultiVesting.sol";

/**
 * @title Deploy BSTTokenMultiVesting Script
 * @notice Simple script to deploy BSTTokenMultiVesting contract
 * @dev Usage:
 *   1. Set .env file:
 *      BST_TOKEN_ADDRESS=0x...  (existing token address)
 *
 *   2. Run:
 *      forge script script/DeployBSTTokenMultiVesting.s.sol --rpc-url $RPC_URL --broadcast --account iost
 */
contract DeployBSTTokenMultiVesting is Script {

    function run() external {
        // Load config
        address tokenAddress = vm.envAddress("BST_TOKEN_ADDRESS");

        require(tokenAddress != address(0), "BST_TOKEN_ADDRESS not set");

        console.log("=== Deploying BSTTokenMultiVesting ===");
        console.log("Token:", tokenAddress);
        console.log("");

        // Deploy
        vm.startBroadcast();

        BSTTokenMultiVesting vesting = new BSTTokenMultiVesting(
            IERC20(tokenAddress),
            msg.sender
        );

        vm.stopBroadcast();

        // Output
        console.log("=== Deployment Successful ===");
        console.log("Vesting Contract:", address(vesting));
        console.log("Owner:", vesting.owner());
        console.log("");

    }
}
