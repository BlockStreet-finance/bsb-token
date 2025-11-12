// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import "../src/BSTTokenMultiVesting.sol";

/**
 * @title Set Start Time Script
 * @notice Set or modify the vesting start time (before vesting starts)
 * @dev Usage:
 *   1. Set .env file:
 *      PRIVATE_KEY=your_private_key
 *      RPC_URL=your_rpc_url
 *      VESTING_CONTRACT=0x...
 *      START_TIMESTAMP=1234567890  (Unix timestamp)
 *
 *   2. Run:
 *      forge script script/SetStartTime.s.sol --rpc-url $RPC_URL --broadcast
 */
contract SetStartTime is Script {

    function run() external {
        // Load config
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address vestingAddress = vm.envAddress("VESTING_CONTRACT");
        uint256 startTimestamp = vm.envUint("START_TIMESTAMP");

        require(vestingAddress != address(0), "VESTING_CONTRACT not set");
        require(startTimestamp > 0, "START_TIMESTAMP not set");

        BSTTokenMultiVesting vesting = BSTTokenMultiVesting(vestingAddress);

        console.log("=== Setting Start Time ===");
        console.log("Vesting Contract:", vestingAddress);
        console.log("New start time:", startTimestamp);
        console.log("New start date:", vm.toString(startTimestamp));
        console.log("");

        // Check current state
        bool isStarted = vesting.isStarted();
        uint256 currentStartTime = vesting.startTime();

        console.log("Current state:");
        console.log("  Is started:", isStarted);
        console.log("  Current start time:", currentStartTime);
        console.log("");

        require(!isStarted, "Cannot change start time after vesting started");
        require(startTimestamp > block.timestamp, "Start time must be in the future");

        vm.startBroadcast(deployerPrivateKey);

        vesting.setStartTime(startTimestamp);

        vm.stopBroadcast();

        console.log("=== Start Time Updated ===");
        console.log("New start time:", vesting.startTime());
        console.log("");
        console.log("Start time has been set successfully!");
        console.log("Call startVesting() when ready to begin vesting at this time.");
    }
}
