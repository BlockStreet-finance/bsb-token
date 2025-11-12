// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import "../src/BSTTokenMultiVesting.sol";

/**
 * @title Deploy BSTTokenMultiVesting Script
 * @notice Simple script to deploy BSTTokenMultiVesting contract
 * @dev Usage:
 *   1. Set .env file:
 *      PRIVATE_KEY=your_private_key
 *      RPC_URL=your_rpc_url
 *      BST_TOKEN_ADDRESS=0x...  (existing token address)
 *
 *   2. Run:
 *      forge script script/DeployBSTTokenMultiVesting.s.sol --rpc-url $RPC_URL --broadcast
 */
contract DeployBSTTokenMultiVesting is Script {

    function run() external {
        // Load config
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        address tokenAddress = vm.envAddress("BST_TOKEN_ADDRESS");

        require(tokenAddress != address(0), "BST_TOKEN_ADDRESS not set");

        console.log("=== Deploying BSTTokenMultiVesting ===");
        console.log("Deployer:", deployer);
        console.log("Token:", tokenAddress);
        console.log("");

        // Deploy
        vm.startBroadcast(deployerPrivateKey);

        BSTTokenMultiVesting vesting = new BSTTokenMultiVesting(
            IERC20(tokenAddress),
            deployer  // owner is deployer
        );

        vm.stopBroadcast();

        // Output
        console.log("=== Deployment Successful ===");
        console.log("Vesting Contract:", address(vesting));
        console.log("Owner:", vesting.owner());
        console.log("");

        // Save to file
        string memory info = string.concat(
            "BST_TOKEN_ADDRESS=", vm.toString(tokenAddress), "\n",
            "VESTING_CONTRACT=", vm.toString(address(vesting)), "\n",
            "OWNER=", vm.toString(deployer), "\n"
        );

        vm.writeFile("deployments/multi-vesting.env", info);
        console.log("Saved to: deployments/multi-vesting.env");
    }
}
