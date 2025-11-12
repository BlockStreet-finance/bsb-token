// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import "../src/BSTTokenMultiVesting.sol";

/**
 * @title Add Schedules to Existing Vesting Contract
 * @notice Add schedules to an already deployed vesting contract
 * @dev Usage:
 *   1. Set .env file:
 *      PRIVATE_KEY=your_private_key
 *      RPC_URL=your_rpc_url
 *      VESTING_CONTRACT=0x...  (existing vesting contract address)
 *
 *   2. Edit the schedules in setupSchedules() function below
 *
 *   3. Run:
 *      forge script script/AddSchedules.s.sol --rpc-url $RPC_URL --broadcast
 */
contract AddSchedules is Script {

    struct ScheduleConfig {
        address beneficiary;
        uint256 cliffDuration;     // in days
        uint256 numberOfPeriods;   // number of 30-day periods
        uint256 amountPerPeriod;   // amount per period (in wei)
    }

    function run() external {
        // Load config
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address vestingAddress = vm.envAddress("VESTING_CONTRACT");

        require(vestingAddress != address(0), "VESTING_CONTRACT not set");

        BSTTokenMultiVesting vesting = BSTTokenMultiVesting(vestingAddress);

        console.log("=== Adding Schedules ===");
        console.log("Vesting Contract:", vestingAddress);
        console.log("Owner:", vesting.owner());
        console.log("Is Started:", vesting.isStarted());
        console.log("");

        // Get schedules
        ScheduleConfig[] memory schedules = setupSchedules();
        console.log("Number of schedules to add:", schedules.length);

        vm.startBroadcast(deployerPrivateKey);

        uint256 totalAllocation = 0;
        for (uint256 i = 0; i < schedules.length; i++) {
            ScheduleConfig memory config = schedules[i];

            uint256 scheduleId = vesting.addSchedule(
                config.beneficiary,
                config.cliffDuration * 1 days,
                config.numberOfPeriods,
                config.amountPerPeriod
            );

            uint256 totalAmount = config.numberOfPeriods * config.amountPerPeriod;
            totalAllocation += totalAmount;

            console.log("");
            console.log("Schedule", i + 1, "added:");
            console.log("  ID:", scheduleId);
            console.log("  Beneficiary:", config.beneficiary);
            console.log("  Cliff:", config.cliffDuration, "days");
            console.log("  Periods:", config.numberOfPeriods);
            console.log("  Amount per period:", config.amountPerPeriod / 1e18, "tokens");
            console.log("  Total amount:", totalAmount / 1e18, "tokens");
        }

        vm.stopBroadcast();

        // Output summary
        console.log("");
        console.log("=== Summary ===");
        console.log("Schedules added:", schedules.length);
        console.log("Total new allocation:", totalAllocation / 1e18, "tokens");
        console.log("Total allocated in contract:", vesting.totalAllocatedAmount() / 1e18, "tokens");
        console.log("");

        if (!vesting.isStarted()) {
            console.log("NOTE: Vesting has not started yet.");
            console.log("Make sure contract has enough tokens, then call startVesting()");
        }
    }

    /**
     * @notice Configure your vesting schedules here
     * @dev Edit this function to add your beneficiaries and schedules
     */
    function setupSchedules() internal pure returns (ScheduleConfig[] memory) {
        // Example schedules - EDIT THIS SECTION
        ScheduleConfig[] memory schedules = new ScheduleConfig[](2);

        // Schedule 1
        schedules[0] = ScheduleConfig({
            beneficiary: 0x4444444444444444444444444444444444444444,
            cliffDuration: 0,           // 0 days cliff
            numberOfPeriods: 12,        // 12 periods
            amountPerPeriod: 800 * 1e18   // 800 tokens per period
        });

        // Schedule 2
        schedules[1] = ScheduleConfig({
            beneficiary: 0x5555555555555555555555555555555555555555,
            cliffDuration: 60,          // 60 days cliff
            numberOfPeriods: 18,        // 18 periods
            amountPerPeriod: 600 * 1e18   // 600 tokens per period
        });

        return schedules;
    }
}
