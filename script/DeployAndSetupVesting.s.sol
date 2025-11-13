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

        // Schedule 1: BS-Community Airdrop
        schedules[0] = ScheduleConfig({
            beneficiary: 0x324F7049c098D682f644903eb9bcfd9b20937426,
            cliffDuration: 0,           // 0 days cliff
            numberOfPeriods: 3,        // 12 periods (12 months)
            amountPerPeriod: 8333333 * 1e18  // 8333333 tokens per period
        });

        // Schedule 2: BS-Ecosystem Airdrop
        schedules[1] = ScheduleConfig({
            beneficiary: 0x3E038AA6E022d90e75f8C4f0251513E37B772B4C,
            cliffDuration: 0,          // 0 days cliff
            numberOfPeriods: 3,        // 3 periods (3 months)
            amountPerPeriod: 10000000 * 1e18   // 10000000 tokens per period
        });

        // Schedule 3: BS-Community & User Incentives
        schedules[2] = ScheduleConfig({
            beneficiary: 0x1Fe4574B84362fb3a00Ea3c4E18F58Da513C427e,
            cliffDuration: 30*5,         // 150 days cliff
            numberOfPeriods: 60,        // 60 periods (60 months)
            amountPerPeriod: 4150000 * 1e18   // 4150000 tokens per period
        });

        // Schedule 4: BS-Ecosystem Partners
        schedules[3] = ScheduleConfig({
            beneficiary: 0x3119DBF448F8e8AD6d5a2996316816AE36386Ef3,
            cliffDuration: 30*5,         // 150 days cliff
            numberOfPeriods: 60,        // 60 periods (36 months)
            amountPerPeriod: 3775000 * 1e18   // 3775000 tokens per period
        });

        // Schedule 5: BS-Treasury
        schedules[4] = ScheduleConfig({
            beneficiary: 0x816264560049544913998877E5E1B1e5058e028a,
            cliffDuration: 30*5,         // 150 days cliff
            numberOfPeriods: 60,        // 60 periods (60 months)
            amountPerPeriod: 941667 * 1e18   // 941667 tokens per period
        });

        // Schedule 6: BS-Team & Advisors
        schedules[5] = ScheduleConfig({
            beneficiary: 0xd399adca52C8Ae65ea3E063b5F771523522C4AC7,
            cliffDuration: 30*12,         // 360 days cliff
            numberOfPeriods: 48,         // 48 periods (36 months)
            amountPerPeriod: 3604167 * 1e18   // 3604167 tokens per period
        });

        // Schedule 7: BS-Core Investors
        schedules[6] = ScheduleConfig({
            beneficiary: 0xB399C3D339ac7255F2af68558f4B8B25C73FD648,
            cliffDuration: 30*12,         // 360 days cliff
            numberOfPeriods: 36,        // 36 periods (36 months)
            amountPerPeriod: 4361111 * 1e18   // 4361111 tokens per period
        });

        // Schedule 8: BS-Strategic investors
        schedules[7] = ScheduleConfig({
            beneficiary: 0xa892Ec8068FEffc79532724F22A4f3FF1FB30e0D,
            cliffDuration: 30*12,         // 360 days cliff
            numberOfPeriods: 36,        // 36 periods (36 months)
            amountPerPeriod: 833333 * 1e18   // 833333 tokens per period
        });

        // Schedule 9: BS-liquidity & lisintg
        schedules[8] = ScheduleConfig({
            beneficiary: 0xad3C3Ce07a03E3cE19218299dDD37aC0e11D1dbd,
            cliffDuration: 0,         // 0 days cliff
            numberOfPeriods: 1,        // 0 periods (36 months)
            amountPerPeriod: 53000000 * 1e18   // 53000000 tokens per period
        });

        return schedules;
    }
}
