// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "../src/BSTTokenMultiVesting.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("Mock Token", "MOCK") {
        _mint(msg.sender, 1000000 * 10**18);
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract BSTTokenMultiVestingTest is Test {
    BSTTokenMultiVesting public vesting;
    MockERC20 public token;

    address public owner = address(1);
    address public user1 = address(2);
    address public user2 = address(3);
    address public user3 = address(4);

    uint256 constant PERIOD_DURATION = 30 days;

    event VestingStarted(uint256 startTime);
    event ScheduleAdded(address indexed beneficiary, uint256 indexed scheduleId, uint256 totalAmount, uint256 cliffDuration, uint256 numberOfPeriods);
    event ScheduleUpdated(address indexed beneficiary, uint256 scheduleIndex, uint256 indexed scheduleId, uint256 totalAmount);
    event ScheduleRemoved(address indexed beneficiary, uint256 scheduleIndex, uint256 indexed scheduleId);
    event TokensClaimed(address indexed beneficiary, uint256 scheduleIndex, uint256 amount, uint256 totalClaimed);
    event TokensClaimedAll(address indexed beneficiary, uint256 totalAmount, uint256 scheduleCount);
    event BeneficiaryChanged(address indexed oldBeneficiary, address indexed newBeneficiary, uint256 scheduleCount);

    function setUp() public {
        vm.startPrank(owner);

        token = new MockERC20();
        vesting = new BSTTokenMultiVesting(token, owner);

        // Transfer tokens to vesting contract
        token.transfer(address(vesting), 500000 * 10**18);

        vm.stopPrank();
    }

    // ========== Constructor Tests ==========

    function testConstructor() public view {
        assertEq(address(vesting.token()), address(token));
        assertEq(vesting.owner(), owner);
        assertFalse(vesting.isStarted());
        assertEq(vesting.PERIOD_DURATION(), PERIOD_DURATION);
    }

    function testConstructorInvalidToken() public {
        vm.prank(owner);
        vm.expectRevert("Invalid token address");
        new BSTTokenMultiVesting(IERC20(address(0)), owner);
    }

    // ========== Add Schedule Tests ==========

    function testAddSchedule() public {
        vm.startPrank(owner);

        uint256 cliffDuration = 90 days;
        uint256 numberOfPeriods = 12;
        uint256 amountPerPeriod = 1000 * 10**18;
        uint256 expectedTotal = numberOfPeriods * amountPerPeriod;

        vm.expectEmit(true, true, false, true);
        emit ScheduleAdded(user1, 0, expectedTotal, cliffDuration, numberOfPeriods);

        uint256 scheduleId = vesting.addSchedule(user1, cliffDuration, numberOfPeriods, amountPerPeriod);

        assertEq(scheduleId, 0);
        assertEq(vesting.getUserScheduleCount(user1), 1);
        assertEq(vesting.totalAllocatedAmount(), expectedTotal);
        assertEq(vesting.totalScheduleCount(), 1);
        assertEq(vesting.activeScheduleCount(), 1);

        vm.stopPrank();
    }

    function testAddMultipleSchedulesToSameUser() public {
        vm.startPrank(owner);

        uint256 scheduleId1 = vesting.addSchedule(user1, 0, 12, 1000 * 10**18);
        uint256 scheduleId2 = vesting.addSchedule(user1, 90 days, 24, 500 * 10**18);

        assertEq(scheduleId1, 0);
        assertEq(scheduleId2, 1);
        assertEq(vesting.getUserScheduleCount(user1), 2);

        vm.stopPrank();
    }

    function testAddScheduleInsufficientBalance() public {
        vm.startPrank(owner);

        // Add schedule that exceeds contract balance (will succeed)
        vesting.addSchedule(user1, 0, 1000, 1000 * 10**18); // 1,000,000 tokens

        // Starting vesting should revert due to insufficient balance
        vm.expectRevert("Insufficient contract balance");
        vesting.startVesting();

        vm.stopPrank();
    }

    function testAddScheduleInvalidParams() public {
        vm.startPrank(owner);

        vm.expectRevert("Invalid beneficiary address");
        vesting.addSchedule(address(0), 0, 12, 1000 * 10**18);

        vm.expectRevert("Number of periods must be positive");
        vesting.addSchedule(user1, 0, 0, 1000 * 10**18);

        vm.expectRevert("Amount per period must be positive");
        vesting.addSchedule(user1, 0, 12, 0);

        vm.stopPrank();
    }

    function testBatchAddSchedules() public {
        vm.startPrank(owner);

        address[] memory beneficiaries = new address[](3);
        beneficiaries[0] = user1;
        beneficiaries[1] = user2;
        beneficiaries[2] = user3;

        uint256[] memory cliffDurations = new uint256[](3);
        cliffDurations[0] = 0;
        cliffDurations[1] = 90 days;
        cliffDurations[2] = 180 days;

        uint256[] memory periodsArray = new uint256[](3);
        periodsArray[0] = 12;
        periodsArray[1] = 24;
        periodsArray[2] = 36;

        uint256[] memory amountsPerPeriod = new uint256[](3);
        amountsPerPeriod[0] = 1000 * 10**18;
        amountsPerPeriod[1] = 500 * 10**18;
        amountsPerPeriod[2] = 300 * 10**18;

        uint256[] memory scheduleIds = vesting.batchAddSchedules(
            beneficiaries,
            cliffDurations,
            periodsArray,
            amountsPerPeriod
        );

        assertEq(scheduleIds.length, 3);
        assertEq(vesting.getUserScheduleCount(user1), 1);
        assertEq(vesting.getUserScheduleCount(user2), 1);
        assertEq(vesting.getUserScheduleCount(user3), 1);
        assertEq(vesting.totalScheduleCount(), 3);

        vm.stopPrank();
    }

    // ========== Update Schedule Tests ==========

    function testUpdateSchedule() public {
        vm.startPrank(owner);

        vesting.addSchedule(user1, 90 days, 12, 1000 * 10**18);

        uint256 oldTotal = vesting.totalAllocatedAmount();

        // Update schedule
        vesting.updateSchedule(user1, 0, 60 days, 24, 500 * 10**18);

        (
            ,
            uint256 totalAmount,
            uint256 cliffDuration,
            ,
            uint256 amountPerPeriod,
            uint256 numberOfPeriods,
            ,
            ,
            ,
            bool isActive
        ) = vesting.getSchedule(user1, 0);

        assertEq(totalAmount, 24 * 500 * 10**18);
        assertEq(cliffDuration, 60 days);
        assertEq(amountPerPeriod, 500 * 10**18);
        assertEq(numberOfPeriods, 24);
        assertTrue(isActive);

        vm.stopPrank();
    }

    function testUpdateScheduleAfterStart() public {
        vm.startPrank(owner);

        vesting.addSchedule(user1, 0, 12, 1000 * 10**18);
        vesting.startVesting();

        vm.expectRevert("Vesting already started");
        vesting.updateSchedule(user1, 0, 0, 24, 500 * 10**18);

        vm.stopPrank();
    }

    // ========== Remove Schedule Tests ==========

    function testRemoveSchedule() public {
        vm.startPrank(owner);

        vesting.addSchedule(user1, 0, 12, 1000 * 10**18);
        uint256 totalBefore = vesting.totalAllocatedAmount();
        uint256 activeBefore = vesting.activeScheduleCount();

        vesting.removeSchedule(user1, 0);

        (
            ,
            ,
            ,
            ,
            ,
            ,
            ,
            ,
            ,
            bool isActive
        ) = vesting.getSchedule(user1, 0);

        assertFalse(isActive);
        assertEq(vesting.totalAllocatedAmount(), 0);
        assertEq(vesting.activeScheduleCount(), activeBefore - 1);

        vm.stopPrank();
    }

    function testRemoveScheduleAfterStart() public {
        vm.startPrank(owner);

        vesting.addSchedule(user1, 0, 12, 1000 * 10**18);
        vesting.startVesting();

        vm.expectRevert("Vesting already started");
        vesting.removeSchedule(user1, 0);

        vm.stopPrank();
    }

    // ========== Start Vesting Tests ==========

    function testStartVesting() public {
        vm.startPrank(owner);

        vesting.addSchedule(user1, 0, 12, 1000 * 10**18);

        vm.expectEmit(false, false, false, false);
        emit VestingStarted(block.timestamp);

        vesting.startVesting();

        assertTrue(vesting.isStarted());
        assertEq(vesting.startTime(), block.timestamp);

        vm.stopPrank();
    }

    function testStartVestingNoSchedules() public {
        vm.startPrank(owner);

        vm.expectRevert("No schedules created");
        vesting.startVesting();

        vm.stopPrank();
    }

    function testStartVestingTwice() public {
        vm.startPrank(owner);

        vesting.addSchedule(user1, 0, 12, 1000 * 10**18);
        vesting.startVesting();

        vm.expectRevert("Vesting already started");
        vesting.startVesting();

        vm.stopPrank();
    }

    function testSetStartTime() public {
        vm.startPrank(owner);

        vesting.addSchedule(user1, 0, 12, 1000 * 10**18);

        uint256 futureTime = block.timestamp + 30 days;
        vesting.setStartTime(futureTime);

        assertEq(vesting.startTime(), futureTime);

        vm.stopPrank();
    }

    function testSetStartTimeModifyBeforeStart() public {
        vm.startPrank(owner);

        vesting.addSchedule(user1, 0, 12, 1000 * 10**18);

        // Set start time
        uint256 futureTime = block.timestamp + 30 days;
        vesting.setStartTime(futureTime);

        // Modify start time before starting
        uint256 newTime = block.timestamp + 60 days;
        vesting.setStartTime(newTime);

        assertEq(vesting.startTime(), newTime);

        vm.stopPrank();
    }

    function testSetStartTimeAfterStart() public {
        vm.startPrank(owner);

        vesting.addSchedule(user1, 0, 12, 1000 * 10**18);
        vesting.startVesting();

        uint256 futureTime = block.timestamp + 30 days;

        vm.expectRevert("Vesting already started");
        vesting.setStartTime(futureTime);

        vm.stopPrank();
    }

    function testStartVestingWithPresetTime() public {
        vm.startPrank(owner);

        vesting.addSchedule(user1, 0, 12, 1000 * 10**18);

        uint256 futureTime = block.timestamp + 30 days;
        vesting.setStartTime(futureTime);
        vesting.startVesting();

        assertEq(vesting.startTime(), futureTime);
        assertTrue(vesting.isStarted());

        vm.stopPrank();
    }

    function testClaimWithPresetStartTime() public {
        vm.startPrank(owner);

        vesting.addSchedule(user1, 0, 12, 1000 * 10**18);

        uint256 futureTime = block.timestamp + 30 days;
        vesting.setStartTime(futureTime);
        vesting.startVesting();

        vm.stopPrank();

        // Move to futureTime + 90 days (3 periods)
        // First period unlocks immediately, then 3 more = 4 total
        vm.warp(futureTime + 90 days);

        uint256 balanceBefore = token.balanceOf(user1);

        vm.prank(user1);
        vesting.claimFromSchedule(0);

        uint256 balanceAfter = token.balanceOf(user1);
        assertEq(balanceAfter - balanceBefore, 4 * 1000 * 10**18);
    }

    // ========== Vesting Calculation Tests ==========

    function testCalculateVestedAmountBeforeStart() public {
        vm.startPrank(owner);

        vesting.addSchedule(user1, 0, 12, 1000 * 10**18);

        assertEq(vesting.calculateVestedAmount(user1, 0), 0);

        vm.stopPrank();
    }

    function testCalculateVestedAmountDuringCliff() public {
        vm.startPrank(owner);

        vesting.addSchedule(user1, 90 days, 12, 1000 * 10**18);
        vesting.startVesting();

        vm.stopPrank();

        // Move to middle of cliff
        vm.warp(block.timestamp + 45 days);

        assertEq(vesting.calculateVestedAmount(user1, 0), 0);
    }

    function testCalculateVestedAmountAfterCliff() public {
        vm.startPrank(owner);

        vesting.addSchedule(user1, 90 days, 12, 1000 * 10**18);
        vesting.startVesting();

        vm.stopPrank();

        // Move past cliff + 3 periods (90 days)
        // After cliff, first period unlocks immediately, then 3 more periods = 4 total
        vm.warp(block.timestamp + 90 days + 90 days);

        uint256 vested = vesting.calculateVestedAmount(user1, 0);
        assertEq(vested, 4 * 1000 * 10**18); // 4 periods vested (1 immediate + 3 after 90 days)
    }

    function testCalculateVestedAmountFullyVested() public {
        vm.startPrank(owner);

        vesting.addSchedule(user1, 0, 12, 1000 * 10**18);
        vesting.startVesting();

        vm.stopPrank();

        // Move past all periods
        vm.warp(block.timestamp + 365 days);

        uint256 vested = vesting.calculateVestedAmount(user1, 0);
        assertEq(vested, 12 * 1000 * 10**18); // Fully vested
    }

    // ========== Claim Tests ==========

    function testClaimFromSchedule() public {
        vm.startPrank(owner);

        vesting.addSchedule(user1, 0, 12, 1000 * 10**18);
        vesting.startVesting();

        vm.stopPrank();

        // Move forward 3 periods (90 days)
        // First period unlocks immediately, then 3 more periods = 4 total
        vm.warp(block.timestamp + 90 days);

        uint256 balanceBefore = token.balanceOf(user1);

        vm.prank(user1);
        vesting.claimFromSchedule(0);

        uint256 balanceAfter = token.balanceOf(user1);
        assertEq(balanceAfter - balanceBefore, 4 * 1000 * 10**18);
    }

    function testClaimFromScheduleMultipleTimes() public {
        vm.startPrank(owner);

        vesting.addSchedule(user1, 0, 12, 1000 * 10**18);
        vesting.startVesting();
        uint256 vestingStart = vesting.startTime();

        vm.stopPrank();

        // First claim after 3 periods (90 days)
        // First period unlocks immediately, then 3 more periods = 4 total
        vm.warp(vestingStart + 90 days);
        vm.prank(user1);
        vesting.claimFromSchedule(0);

        uint256 balance1 = token.balanceOf(user1);
        assertEq(balance1, 4 * 1000 * 10**18);

        // Second claim after 3 more periods (total 6 periods elapsed, 7 periods unlocked with immediate first)
        vm.warp(vestingStart + 180 days);
        vm.prank(user1);
        vesting.claimFromSchedule(0);

        uint256 balance2 = token.balanceOf(user1);
        // Total balance should be 7 periods (1 immediate + 6 periods)
        assertEq(balance2, 7 * 1000 * 10**18);
    }

    function testClaimAll() public {
        vm.startPrank(owner);

        vesting.addSchedule(user1, 0, 12, 1000 * 10**18);
        vesting.addSchedule(user1, 0, 24, 500 * 10**18);
        vesting.startVesting();

        vm.stopPrank();

        // Move forward 3 periods (90 days)
        // Each schedule: first period unlocks immediately, then 3 more = 4 total
        vm.warp(block.timestamp + 90 days);

        uint256 balanceBefore = token.balanceOf(user1);

        vm.prank(user1);
        vesting.claimAll();

        uint256 balanceAfter = token.balanceOf(user1);
        // 4 periods from schedule 1 (4000) + 4 periods from schedule 2 (2000)
        assertEq(balanceAfter - balanceBefore, (4 * 1000 * 10**18) + (4 * 500 * 10**18));
    }

    function testClaimBeforeStart() public {
        vm.startPrank(owner);

        vesting.addSchedule(user1, 0, 12, 1000 * 10**18);

        vm.stopPrank();

        vm.prank(user1);
        vm.expectRevert("Vesting not started");
        vesting.claimFromSchedule(0);
    }

    function testClaimNothingAvailable() public {
        vm.startPrank(owner);

        vesting.addSchedule(user1, 90 days, 12, 1000 * 10**18);
        vesting.startVesting();

        vm.stopPrank();

        // Still in cliff period
        vm.warp(block.timestamp + 30 days);

        vm.prank(user1);
        vm.expectRevert("No tokens to claim");
        vesting.claimFromSchedule(0);
    }

    // ========== Change Beneficiary Tests ==========

    function testChangeBeneficiary() public {
        vm.startPrank(owner);

        vesting.addSchedule(user1, 0, 12, 1000 * 10**18);
        vesting.addSchedule(user1, 90 days, 24, 500 * 10**18);

        vm.stopPrank();

        assertEq(vesting.getUserScheduleCount(user1), 2);
        assertEq(vesting.getUserScheduleCount(user2), 0);

        vm.prank(user1);
        vesting.changeBeneficiary(user2);

        assertEq(vesting.getUserScheduleCount(user1), 0);
        assertEq(vesting.getUserScheduleCount(user2), 2);
    }

    function testChangeBeneficiaryInvalidAddress() public {
        vm.startPrank(owner);

        vesting.addSchedule(user1, 0, 12, 1000 * 10**18);

        vm.stopPrank();

        vm.startPrank(user1);

        vm.expectRevert("Invalid new beneficiary address");
        vesting.changeBeneficiary(address(0));

        vm.expectRevert("New beneficiary must be different");
        vesting.changeBeneficiary(user1);

        vm.stopPrank();
    }

    function testChangeBeneficiaryAlreadyHasSchedules() public {
        vm.startPrank(owner);

        vesting.addSchedule(user1, 0, 12, 1000 * 10**18);
        vesting.addSchedule(user2, 0, 12, 1000 * 10**18);

        vm.stopPrank();

        vm.prank(user1);
        vm.expectRevert("New beneficiary already has schedules");
        vesting.changeBeneficiary(user2);
    }

    // ========== Query Function Tests ==========

    function testGetUserSummary() public {
        vm.startPrank(owner);

        vesting.addSchedule(user1, 0, 12, 1000 * 10**18);
        vesting.addSchedule(user1, 90 days, 24, 500 * 10**18);
        vesting.startVesting();
        uint256 vestingStart = vesting.startTime();

        vm.stopPrank();

        // Move forward 3 periods (90 days)
        // Schedule 1: 4 periods vested (no cliff, first period immediate + 3 periods)
        // Schedule 2: 1 period vested (90-day cliff just ended, first period immediate)
        vm.warp(vestingStart + 90 days);

        (
            uint256 totalAllocated,
            uint256 totalVested,
            uint256 totalClaimed,
            uint256 totalClaimable,
            uint256 scheduleCount
        ) = vesting.getUserSummary(user1);

        assertEq(scheduleCount, 2);
        assertEq(totalAllocated, (12 * 1000 * 10**18) + (24 * 500 * 10**18));
        assertEq(totalVested, (4 * 1000 * 10**18) + (1 * 500 * 10**18)); // Schedule 1: 4 periods, Schedule 2: 1 period
        assertEq(totalClaimed, 0);
        assertEq(totalClaimable, (4 * 1000 * 10**18) + (1 * 500 * 10**18));
    }

    function testGetGlobalStatistics() public {
        vm.startPrank(owner);

        vesting.addSchedule(user1, 0, 12, 1000 * 10**18);
        vesting.addSchedule(user2, 0, 24, 500 * 10**18);
        vesting.startVesting();

        vm.stopPrank();

        // Move forward 3 periods
        vm.warp(block.timestamp + 90 days);

        address[] memory beneficiaries = new address[](2);
        beneficiaries[0] = user1;
        beneficiaries[1] = user2;

        (
            uint256 totalAllocated,
            uint256 totalVested,
            uint256 totalClaimed,
            uint256 totalClaimable,
            uint256 totalLocked,
            uint256 contractBalance,
            uint256 totalSchedules,
            uint256 activeSchedules
        ) = vesting.getGlobalStatistics(beneficiaries);

        assertEq(totalSchedules, 2);
        assertEq(activeSchedules, 2);
        assertEq(totalAllocated, (12 * 1000 * 10**18) + (24 * 500 * 10**18));
        // First period unlocks immediately for both schedules, then 3 more = 4 total each
        assertEq(totalVested, (4 * 1000 * 10**18) + (4 * 500 * 10**18));
        assertEq(totalClaimed, 0);
    }

    function testGetProjectedVestingAt() public {
        vm.startPrank(owner);

        vesting.addSchedule(user1, 0, 12, 1000 * 10**18);
        vesting.startVesting();

        vm.stopPrank();

        uint256 futureTime = block.timestamp + 180 days; // 6 periods

        address[] memory beneficiaries = new address[](1);
        beneficiaries[0] = user1;

        (
            uint256 projectedVested,
            uint256 projectedLocked,
            uint256 percentageVested
        ) = vesting.getProjectedVestingAt(futureTime, beneficiaries);

        assertEq(projectedVested, 6 * 1000 * 10**18);
        assertEq(projectedLocked, 6 * 1000 * 10**18);
        assertEq(percentageVested, 5000); // 50% (basis 10000)
    }

    function testExportAllSchedules() public {
        vm.startPrank(owner);

        vesting.addSchedule(user1, 0, 12, 1000 * 10**18);
        vesting.addSchedule(user2, 90 days, 24, 500 * 10**18);

        vm.stopPrank();

        address[] memory beneficiaries = new address[](2);
        beneficiaries[0] = user1;
        beneficiaries[1] = user2;

        (
            address[] memory addrs,
            uint256[] memory indexes,
            uint256[] memory ids,
            uint256[] memory amounts,
            ,
            uint256[] memory periods,
            ,
            ,
            bool[] memory active
        ) = vesting.exportAllSchedules(beneficiaries);

        assertEq(addrs.length, 2);
        assertEq(addrs[0], user1);
        assertEq(addrs[1], user2);
        assertEq(amounts[0], 12 * 1000 * 10**18);
        assertEq(amounts[1], 24 * 500 * 10**18);
        assertEq(periods[0], 12);
        assertEq(periods[1], 24);
        assertTrue(active[0]);
        assertTrue(active[1]);
    }

    function testExportUserSchedules() public {
        vm.startPrank(owner);

        vesting.addSchedule(user1, 0, 12, 1000 * 10**18);
        vesting.addSchedule(user1, 90 days, 24, 500 * 10**18);
        vesting.startVesting();

        vm.stopPrank();

        (
            uint256[] memory scheduleIds,
            uint256[] memory totalAmounts,
            uint256[] memory cliffDurations,
            uint256[] memory numberOfPeriods,
            uint256[] memory amountsPerPeriod,
            uint256[] memory claimedAmounts,
            uint256[] memory vestedAmounts,
            uint256[] memory claimableAmounts,
            uint256[] memory cliffEndTimes,
            uint256[] memory vestingEndTimes,
            bool[] memory isActive
        ) = vesting.exportUserSchedules(user1);

        assertEq(scheduleIds.length, 2);
        assertEq(totalAmounts[0], 12 * 1000 * 10**18);
        assertEq(totalAmounts[1], 24 * 500 * 10**18);
        assertEq(numberOfPeriods[0], 12);
        assertEq(numberOfPeriods[1], 24);
        assertTrue(isActive[0]);
        assertTrue(isActive[1]);
    }

    function testHealthCheck() public {
        vm.startPrank(owner);

        vesting.addSchedule(user1, 0, 12, 1000 * 10**18);

        (
            bool isHealthy,
            string memory message,
            uint256 requiredBalance,
            uint256 currentBalance,
            uint256 shortfall
        ) = vesting.healthCheck();

        assertTrue(isHealthy);
        assertEq(shortfall, 0);
        assertEq(requiredBalance, 12 * 1000 * 10**18);

        vm.stopPrank();
    }

    function testHealthCheckInsufficientBalance() public {
        vm.startPrank(owner);

        vesting.addSchedule(user1, 0, 12, 1000 * 10**18);
        vesting.startVesting();

        vm.stopPrank();

        // User claims some tokens
        vm.warp(block.timestamp + 90 days);
        vm.prank(user1);
        vesting.claimFromSchedule(0);

        // Simulate a critical situation: set vesting contract balance to 0
        // This represents a loss of funds scenario
        deal(address(token), address(vesting), 0);

        (
            bool isHealthy,
            ,
            ,
            ,
            uint256 shortfall
        ) = vesting.healthCheck();

        assertFalse(isHealthy);
        assertGt(shortfall, 0);
    }

    // ========== Edge Case Tests ==========

    function testAddScheduleAfterVestingStarts() public {
        vm.startPrank(owner);

        vesting.addSchedule(user1, 0, 12, 1000 * 10**18);
        vesting.startVesting();

        // Should still be able to add new schedules after starting
        uint256 scheduleId = vesting.addSchedule(user2, 0, 24, 500 * 10**18);

        assertEq(scheduleId, 1);
        assertEq(vesting.getUserScheduleCount(user2), 1);

        vm.stopPrank();
    }

    function testInactiveScheduleNotCounted() public {
        vm.startPrank(owner);

        vesting.addSchedule(user1, 0, 12, 1000 * 10**18);
        vesting.addSchedule(user1, 0, 24, 500 * 10**18);
        vesting.removeSchedule(user1, 0);
        vesting.startVesting();

        vm.stopPrank();

        vm.warp(block.timestamp + 90 days);

        (
            uint256 totalAllocated,
            uint256 totalVested,
            ,
            ,

        ) = vesting.getUserSummary(user1);

        // Only second schedule should be counted (first period immediate + 3 periods = 4 total)
        assertEq(totalAllocated, 24 * 500 * 10**18);
        assertEq(totalVested, 4 * 500 * 10**18);
    }

    function testMultipleUsersIndependentVesting() public {
        vm.startPrank(owner);

        vesting.addSchedule(user1, 0, 12, 1000 * 10**18);
        vesting.addSchedule(user2, 90 days, 24, 500 * 10**18);
        vesting.startVesting();

        vm.stopPrank();

        // Move forward 120 days (4 periods)
        vm.warp(block.timestamp + 120 days);

        // User1 should have 5 periods vested (no cliff: first period immediate + 4 periods)
        assertEq(vesting.calculateVestedAmount(user1, 0), 5 * 1000 * 10**18);

        // User2 should have 2 periods vested (90 day cliff passed, then first period immediate + 1 period after 30 days)
        assertEq(vesting.calculateVestedAmount(user2, 0), 2 * 500 * 10**18);
    }
}
