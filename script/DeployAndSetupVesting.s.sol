// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import "../src/BSTTokenMultiVesting.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title Deploy and Setup BSTTokenMultiVesting Script
 * @notice Deploy vesting contract and add initial schedules
 * @dev Usage:
 *   1. Set .env file:
 *      PRIVATE_KEY=your_private_key
 *      RPC_URL=your_rpc_url
 *      BST_TOKEN_ADDRESS=0x...
 *
 *   2. Edit the schedules in setupSchedules() function below
 *
 *   3. Run:
 *      forge script script/DeployAndSetupVesting.s.sol --rpc-url $RPC_URL --broadcast
 */
contract DeployAndSetupVesting is Script {

    struct ScheduleConfig {
        address beneficiary;
        uint256 cliffDuration;     // in days
        uint256 numberOfPeriods;   // number of 30-day periods
        uint256 amountPerPeriod;   // amount per period (in wei)
    }

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
            deployer
        );

        console.log("Vesting Contract Deployed:", address(vesting));
        console.log("");

        // Add schedules
        ScheduleConfig[] memory schedules = setupSchedules();

        console.log("=== Adding Schedules ===");
        console.log("Number of schedules:", schedules.length);

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
        console.log("=== Deployment Summary ===");
        console.log("Vesting Contract:", address(vesting));
        console.log("Owner:", vesting.owner());
        console.log("Total schedules:", schedules.length);
        console.log("Total allocated:", totalAllocation / 1e18, "tokens");
        console.log("");
        console.log("IMPORTANT: Transfer", totalAllocation / 1e18, "tokens to", address(vesting));
        console.log("Then call startVesting() to begin vesting");
        console.log("");

        // Save to file
        string memory info = string.concat(
            "BST_TOKEN_ADDRESS=", vm.toString(tokenAddress), "\n",
            "VESTING_CONTRACT=", vm.toString(address(vesting)), "\n",
            "OWNER=", vm.toString(deployer), "\n",
            "TOTAL_ALLOCATED=", vm.toString(totalAllocation), "\n"
        );

        vm.writeFile("deployments/vesting-setup.env", info);
        console.log("Saved to: deployments/vesting-setup.env");
    }

    /**
     * @notice Configure your vesting schedules here
     * @dev Edit this function to add your beneficiaries and schedules
     */
    function setupSchedules() internal pure returns (ScheduleConfig[] memory) {
        // Example schedules - EDIT THIS SECTION
        ScheduleConfig[] memory schedules = new ScheduleConfig[](3);

        // Schedule 1: No cliff, 12 periods, 1000 tokens per period
        schedules[0] = ScheduleConfig({
            beneficiary: 0x1111111111111111111111111111111111111111,
            cliffDuration: 0,           // 0 days cliff
            numberOfPeriods: 12,        // 12 periods (12 months)
            amountPerPeriod: 1000 * 1e18  // 1000 tokens per period
        });

        // Schedule 2: 90-day cliff, 24 periods, 500 tokens per period
        schedules[1] = ScheduleConfig({
            beneficiary: 0x2222222222222222222222222222222222222222,
            cliffDuration: 90,          // 90 days cliff
            numberOfPeriods: 24,        // 24 periods (24 months)
            amountPerPeriod: 500 * 1e18   // 500 tokens per period
        });

        // Schedule 3: 180-day cliff, 36 periods, 250 tokens per period
        schedules[2] = ScheduleConfig({
            beneficiary: 0x3333333333333333333333333333333333333333,
            cliffDuration: 180,         // 180 days cliff
            numberOfPeriods: 36,        // 36 periods (36 months)
            amountPerPeriod: 250 * 1e18   // 250 tokens per period
        });

        return schedules;
    }
}
