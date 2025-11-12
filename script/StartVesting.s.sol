// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import "../src/BSTTokenMultiVesting.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title Start Vesting Script
 * @notice Start the vesting period for the contract
 * @dev Usage:
 *   1. Set .env file:
 *      PRIVATE_KEY=your_private_key
 *      RPC_URL=your_rpc_url
 *      VESTING_CONTRACT=0x...
 *      BST_TOKEN_ADDRESS=0x...
 *
 *   2. Run:
 *      forge script script/StartVesting.s.sol --rpc-url $RPC_URL --broadcast
 */
contract StartVesting is Script {

    function run() external {
        // Load config
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address vestingAddress = vm.envAddress("VESTING_CONTRACT");
        address tokenAddress = vm.envAddress("BST_TOKEN_ADDRESS");

        require(vestingAddress != address(0), "VESTING_CONTRACT not set");
        require(tokenAddress != address(0), "BST_TOKEN_ADDRESS not set");

        BSTTokenMultiVesting vesting = BSTTokenMultiVesting(vestingAddress);
        IERC20 token = IERC20(tokenAddress);

        console.log("=== Starting Vesting ===");
        console.log("Vesting Contract:", vestingAddress);
        console.log("Token:", tokenAddress);
        console.log("");

        // Check current state
        uint256 totalAllocated = vesting.totalAllocatedAmount();
        uint256 contractBalance = token.balanceOf(vestingAddress);
        bool isStarted = vesting.isStarted();

        console.log("Current state:");
        console.log("  Total allocated:", totalAllocated / 1e18, "tokens");
        console.log("  Contract balance:", contractBalance / 1e18, "tokens");
        console.log("  Is started:", isStarted);
        console.log("");

        require(!isStarted, "Vesting already started");
        require(contractBalance >= totalAllocated, "Insufficient balance in contract");

        vm.startBroadcast(deployerPrivateKey);

        vesting.startVesting();
        uint256 startTime = vesting.startTime();

        vm.stopBroadcast();

        console.log("=== Vesting Started ===");
        console.log("Start time:", startTime);
        console.log("Start date:", vm.toString(startTime));
        console.log("");
        console.log("Vesting is now active!");
    }
}
