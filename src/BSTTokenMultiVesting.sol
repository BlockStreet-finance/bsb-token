// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title BST Token Multi-Schedule Vesting Contract
 * @dev Token vesting contract supporting multiple vesting schedules per beneficiary
 * - 30-day period releases
 * - Configurable cliff period
 * - Can add/modify schedules before vesting starts
 * - Can only add new schedules after vesting starts
 * - Beneficiaries can change their address
 * - Comprehensive query functions
 */
contract BSTTokenMultiVesting is Ownable, ReentrancyGuard {
    IERC20 public immutable token;

    uint256 public constant PERIOD_DURATION = 30 days; // Fixed 30-day period

    // Global state
    bool public isStarted;           // Whether vesting has started
    uint256 public startTime;        // Vesting start time
    uint256 public nextScheduleId;   // Next schedule ID

    // Statistics
    uint256 public totalAllocatedAmount;  // Total allocated tokens
    uint256 public totalClaimedAmount;    // Total claimed tokens
    uint256 public totalScheduleCount;    // Total number of schedules
    uint256 public activeScheduleCount;   // Number of active schedules

    struct VestingSchedule {
        uint256 scheduleId;           // Unique schedule ID
        uint256 totalAmount;          // Total allocation amount
        uint256 cliffDuration;        // Cliff period in seconds
        uint256 amountPerPeriod;      // Amount released per period
        uint256 numberOfPeriods;      // Total number of periods
        uint256 claimedAmount;        // Amount already claimed
        uint256 createdAt;            // Creation timestamp
        bool isActive;                // Whether the schedule is active
    }

    // User address => array of vesting schedules
    mapping(address => VestingSchedule[]) public userSchedules;

    // Events
    event StartTimeSet(uint256 startTime);
    event VestingStarted(uint256 startTime);
    event ScheduleAdded(address indexed beneficiary, uint256 indexed scheduleId, uint256 totalAmount, uint256 cliffDuration, uint256 numberOfPeriods);
    event ScheduleUpdated(address indexed beneficiary, uint256 scheduleIndex, uint256 indexed scheduleId, uint256 totalAmount);
    event ScheduleRemoved(address indexed beneficiary, uint256 scheduleIndex, uint256 indexed scheduleId);
    event TokensClaimed(address indexed beneficiary, uint256 scheduleIndex, uint256 amount, uint256 totalClaimed);
    event TokensClaimedAll(address indexed beneficiary, uint256 totalAmount, uint256 scheduleCount);
    event BeneficiaryChanged(address indexed oldBeneficiary, address indexed newBeneficiary, uint256 scheduleCount);

    constructor(IERC20 _token, address _owner) Ownable(_owner) {
        require(address(_token) != address(0), "Invalid token address");
        token = _token;
    }

    // ========== Modifiers ==========

    modifier whenNotStarted() {
        require(!isStarted, "Vesting already started");
        _;
    }

    modifier whenStarted() {
        require(isStarted, "Vesting not started");
        _;
    }

    // ========== Owner Functions ==========

    /**
     * @notice Add a new vesting schedule for a beneficiary
     * @param beneficiary Address of the beneficiary
     * @param cliffDuration Cliff period in seconds
     * @param numberOfPeriods Total number of 30-day periods
     * @param amountPerPeriod Amount released per period
     * @return scheduleId The ID of the created schedule
     */
    function addSchedule(
        address beneficiary,
        uint256 cliffDuration,
        uint256 numberOfPeriods,
        uint256 amountPerPeriod
    ) external onlyOwner returns (uint256 scheduleId) {
        return _addScheduleInternal(beneficiary, cliffDuration, numberOfPeriods, amountPerPeriod);
    }

    /**
     * @notice Batch add vesting schedules
     */
    function batchAddSchedules(
        address[] calldata beneficiaries,
        uint256[] calldata cliffDurations,
        uint256[] calldata periodsArray,
        uint256[] calldata amountsPerPeriod
    ) external onlyOwner returns (uint256[] memory scheduleIds) {
        require(beneficiaries.length == cliffDurations.length, "Length mismatch: beneficiaries and cliffDurations");
        require(beneficiaries.length == periodsArray.length, "Length mismatch: beneficiaries and periodsArray");
        require(beneficiaries.length == amountsPerPeriod.length, "Length mismatch: beneficiaries and amountsPerPeriod");
        require(beneficiaries.length > 0, "Empty arrays");

        scheduleIds = new uint256[](beneficiaries.length);

        for (uint256 i = 0; i < beneficiaries.length; i++) {
            scheduleIds[i] = _addScheduleInternal(
                beneficiaries[i],
                cliffDurations[i],
                periodsArray[i],
                amountsPerPeriod[i]
            );
        }

        return scheduleIds;
    }

    /**
     * @notice Internal function to add a schedule
     */
    function _addScheduleInternal(
        address beneficiary,
        uint256 cliffDuration,
        uint256 numberOfPeriods,
        uint256 amountPerPeriod
    ) internal returns (uint256 scheduleId) {
        require(beneficiary != address(0), "Invalid beneficiary address");
        require(numberOfPeriods > 0, "Number of periods must be positive");
        require(amountPerPeriod > 0, "Amount per period must be positive");

        uint256 totalAmount = numberOfPeriods * amountPerPeriod;

        scheduleId = nextScheduleId++;

        VestingSchedule memory schedule = VestingSchedule({
            scheduleId: scheduleId,
            totalAmount: totalAmount,
            cliffDuration: cliffDuration,
            amountPerPeriod: amountPerPeriod,
            numberOfPeriods: numberOfPeriods,
            claimedAmount: 0,
            createdAt: block.timestamp,
            isActive: true
        });

        userSchedules[beneficiary].push(schedule);

        totalAllocatedAmount += totalAmount;
        totalScheduleCount++;
        activeScheduleCount++;

        emit ScheduleAdded(beneficiary, scheduleId, totalAmount, cliffDuration, numberOfPeriods);

        return scheduleId;
    }

    /**
     * @notice Update an existing vesting schedule (only before vesting starts)
     */
    function updateSchedule(
        address beneficiary,
        uint256 scheduleIndex,
        uint256 cliffDuration,
        uint256 numberOfPeriods,
        uint256 amountPerPeriod
    ) external onlyOwner whenNotStarted {
        require(beneficiary != address(0), "Invalid beneficiary address");
        require(scheduleIndex < userSchedules[beneficiary].length, "Invalid schedule index");
        require(numberOfPeriods > 0, "Number of periods must be positive");
        require(amountPerPeriod > 0, "Amount per period must be positive");

        VestingSchedule storage schedule = userSchedules[beneficiary][scheduleIndex];
        require(schedule.isActive, "Schedule is not active");

        uint256 oldTotalAmount = schedule.totalAmount;
        uint256 newTotalAmount = numberOfPeriods * amountPerPeriod;

        // Update schedule
        schedule.totalAmount = newTotalAmount;
        schedule.cliffDuration = cliffDuration;
        schedule.amountPerPeriod = amountPerPeriod;
        schedule.numberOfPeriods = numberOfPeriods;

        // Update total allocated amount
        if (newTotalAmount > oldTotalAmount) {
            totalAllocatedAmount += (newTotalAmount - oldTotalAmount);
        } else {
            totalAllocatedAmount -= (oldTotalAmount - newTotalAmount);
        }

        emit ScheduleUpdated(beneficiary, scheduleIndex, schedule.scheduleId, newTotalAmount);
    }

    /**
     * @notice Remove a vesting schedule (only before vesting starts)
     */
    function removeSchedule(
        address beneficiary,
        uint256 scheduleIndex
    ) external onlyOwner whenNotStarted {
        require(beneficiary != address(0), "Invalid beneficiary address");
        require(scheduleIndex < userSchedules[beneficiary].length, "Invalid schedule index");

        VestingSchedule storage schedule = userSchedules[beneficiary][scheduleIndex];
        require(schedule.isActive, "Schedule already inactive");

        uint256 scheduleId = schedule.scheduleId;
        uint256 totalAmount = schedule.totalAmount;

        // Mark as inactive
        schedule.isActive = false;

        // Update statistics
        totalAllocatedAmount -= totalAmount;
        activeScheduleCount--;

        emit ScheduleRemoved(beneficiary, scheduleIndex, scheduleId);
    }

    /**
     * @notice Set the vesting start time (can be modified before vesting starts)
     * @param _startTime The vesting start timestamp
     */
    function setStartTime(uint256 _startTime) external onlyOwner whenNotStarted {
        require(_startTime > 0, "Invalid start time");
        startTime = _startTime;
        emit StartTimeSet(_startTime);
    }

    /**
     * @notice Start the vesting period (one-time operation)
     * @dev If startTime is not set, it will be set to current block timestamp
     */
    function startVesting() external onlyOwner whenNotStarted {
        require(totalAllocatedAmount > 0, "No schedules created");

        // Check contract has enough balance
        uint256 contractBalance = token.balanceOf(address(this));
        require(contractBalance >= totalAllocatedAmount, "Insufficient contract balance");

        // If startTime not set, use current timestamp
        if (startTime == 0) {
            startTime = block.timestamp;
        }

        isStarted = true;

        emit VestingStarted(startTime);
    }

    // ========== User Functions ==========

    /**
     * @notice Change beneficiary address (transfers all schedules to new address)
     */
    function changeBeneficiary(address newBeneficiary) external {
        require(newBeneficiary != address(0), "Invalid new beneficiary address");
        require(newBeneficiary != msg.sender, "New beneficiary must be different");
        require(userSchedules[newBeneficiary].length == 0, "New beneficiary already has schedules");

        address oldBeneficiary = msg.sender;
        require(userSchedules[oldBeneficiary].length > 0, "No schedules to transfer");

        // Transfer all schedules
        userSchedules[newBeneficiary] = userSchedules[oldBeneficiary];
        delete userSchedules[oldBeneficiary];

        emit BeneficiaryChanged(oldBeneficiary, newBeneficiary, userSchedules[newBeneficiary].length);
    }

    /**
     * @notice Claim tokens from a specific schedule
     */
    function claimFromSchedule(uint256 scheduleIndex) external nonReentrant whenStarted {
        address beneficiary = msg.sender;
        require(scheduleIndex < userSchedules[beneficiary].length, "Invalid schedule index");

        VestingSchedule storage schedule = userSchedules[beneficiary][scheduleIndex];
        require(schedule.isActive, "Schedule is not active");

        uint256 claimableAmount = calculateClaimableAmount(beneficiary, scheduleIndex);
        require(claimableAmount > 0, "No tokens to claim");
        schedule.claimedAmount += claimableAmount;
        totalClaimedAmount += claimableAmount;

        require(token.transfer(beneficiary, claimableAmount), "Token transfer failed");

        emit TokensClaimed(beneficiary, scheduleIndex, claimableAmount, schedule.claimedAmount);
    }

    /**
     * @notice Claim all available tokens from all schedules
     */
    function claimAll() external nonReentrant whenStarted {
        address beneficiary = msg.sender;
        uint256 scheduleCount = userSchedules[beneficiary].length;
        require(scheduleCount > 0, "No schedules found");

        uint256 totalClaimable = 0;
        uint256 claimedSchedules = 0;

        for (uint256 i = 0; i < scheduleCount; i++) {
            VestingSchedule storage schedule = userSchedules[beneficiary][i];
            if (!schedule.isActive) continue;

            uint256 claimableAmount = calculateClaimableAmount(beneficiary, i);
            if (claimableAmount > 0) {
                schedule.claimedAmount += claimableAmount;
                totalClaimable += claimableAmount;
                claimedSchedules++;

                emit TokensClaimed(beneficiary, i, claimableAmount, schedule.claimedAmount);
            }
        }

        require(totalClaimable > 0, "No tokens to claim");

        totalClaimedAmount += totalClaimable;

        require(token.transfer(beneficiary, totalClaimable), "Token transfer failed");

        emit TokensClaimedAll(beneficiary, totalClaimable, claimedSchedules);
    }

    // ========== Vesting Calculation Functions ==========

    /**
     * @notice Calculate vested amount for a specific schedule
     */
    function calculateVestedAmount(
        address user,
        uint256 scheduleIndex
    ) public view returns (uint256) {
        if (scheduleIndex >= userSchedules[user].length) {
            return 0;
        }

        VestingSchedule memory schedule = userSchedules[user][scheduleIndex];

        // Not active or vesting not started
        if (!schedule.isActive || !isStarted) {
            return 0;
        }

        uint256 currentTime = block.timestamp;

        // Still in cliff period
        if (currentTime < startTime + schedule.cliffDuration) {
            return 0;
        }

        // Calculate periods completed after cliff (first period unlocks immediately after cliff)
        uint256 timeAfterCliff = currentTime - (startTime + schedule.cliffDuration);
        uint256 periodsCompleted = (timeAfterCliff / PERIOD_DURATION) + 1;

        // Fully vested
        if (periodsCompleted >= schedule.numberOfPeriods) {
            return schedule.totalAmount;
        }

        // Calculate vested amount based on completed periods
        return periodsCompleted * schedule.amountPerPeriod;
    }

    /**
     * @notice Calculate claimable amount for a specific schedule
     */
    function calculateClaimableAmount(
        address user,
        uint256 scheduleIndex
    ) public view returns (uint256) {
        uint256 vested = calculateVestedAmount(user, scheduleIndex);
        if (vested == 0 || scheduleIndex >= userSchedules[user].length) {
            return 0;
        }

        VestingSchedule memory schedule = userSchedules[user][scheduleIndex];

        if (vested <= schedule.claimedAmount) {
            return 0;
        }

        return vested - schedule.claimedAmount;
    }

    /**
     * @notice Calculate total claimable amount across all schedules
     */
    function calculateTotalClaimable(address user) public view returns (uint256) {
        uint256 total = 0;
        uint256 scheduleCount = userSchedules[user].length;

        for (uint256 i = 0; i < scheduleCount; i++) {
            total += calculateClaimableAmount(user, i);
        }

        return total;
    }

    // ========== Query Functions - User Schedules ==========

    /**
     * @notice Get all vesting schedules for a user
     */
    function getUserSchedules(address user) external view returns (VestingSchedule[] memory) {
        return userSchedules[user];
    }

    /**
     * @notice Get number of schedules for a user
     */
    function getUserScheduleCount(address user) external view returns (uint256) {
        return userSchedules[user].length;
    }

    /**
     * @notice Get detailed information for a specific schedule
     */
    function getSchedule(
        address user,
        uint256 scheduleIndex
    ) external view returns (
        uint256 scheduleId,
        uint256 totalAmount,
        uint256 cliffDuration,
        uint256 periodDuration,
        uint256 amountPerPeriod,
        uint256 numberOfPeriods,
        uint256 claimedAmount,
        uint256 vestedAmount,
        uint256 claimableAmount,
        bool isActive
    ) {
        require(scheduleIndex < userSchedules[user].length, "Invalid schedule index");

        VestingSchedule memory schedule = userSchedules[user][scheduleIndex];

        return (
            schedule.scheduleId,
            schedule.totalAmount,
            schedule.cliffDuration,
            PERIOD_DURATION,
            schedule.amountPerPeriod,
            schedule.numberOfPeriods,
            schedule.claimedAmount,
            calculateVestedAmount(user, scheduleIndex),
            calculateClaimableAmount(user, scheduleIndex),
            schedule.isActive
        );
    }

    /**
     * @notice Get summary of all schedules for a user
     */
    function getUserSummary(address user) external view returns (
        uint256 totalAllocated,
        uint256 totalVested,
        uint256 totalClaimed,
        uint256 totalClaimable,
        uint256 scheduleCount
    ) {
        scheduleCount = userSchedules[user].length;

        for (uint256 i = 0; i < scheduleCount; i++) {
            VestingSchedule memory schedule = userSchedules[user][i];
            if (!schedule.isActive) continue;

            totalAllocated += schedule.totalAmount;
            totalClaimed += schedule.claimedAmount;
            totalVested += calculateVestedAmount(user, i);
            totalClaimable += calculateClaimableAmount(user, i);
        }

        return (totalAllocated, totalVested, totalClaimed, totalClaimable, scheduleCount);
    }

    // ========== Query Functions - Global Statistics ==========

    /**
     * @notice Get global statistics for specified beneficiaries
     * @param beneficiaries Array of beneficiary addresses to query
     * @return totalAllocated Total allocated amount
     * @return totalVested Total vested amount
     * @return totalClaimed Total claimed amount
     * @return totalClaimable Total claimable amount
     * @return totalLocked Total locked amount (not yet vested)
     * @return contractBalance Contract token balance
     * @return totalSchedules Total number of schedules
     * @return activeSchedules Number of active schedules
     */
    function getGlobalStatistics(address[] calldata beneficiaries) external view returns (
        uint256 totalAllocated,
        uint256 totalVested,
        uint256 totalClaimed,
        uint256 totalClaimable,
        uint256 totalLocked,
        uint256 contractBalance,
        uint256 totalSchedules,
        uint256 activeSchedules
    ) {
        contractBalance = token.balanceOf(address(this));

        for (uint256 i = 0; i < beneficiaries.length; i++) {
            address beneficiary = beneficiaries[i];
            uint256 scheduleCount = userSchedules[beneficiary].length;

            for (uint256 j = 0; j < scheduleCount; j++) {
                VestingSchedule memory schedule = userSchedules[beneficiary][j];

                totalSchedules++;

                if (!schedule.isActive) continue;

                activeSchedules++;
                totalAllocated += schedule.totalAmount;
                totalClaimed += schedule.claimedAmount;

                uint256 vested = calculateVestedAmount(beneficiary, j);
                totalVested += vested;
                totalClaimable += calculateClaimableAmount(beneficiary, j);
            }
        }

        totalLocked = totalAllocated > totalVested ? totalAllocated - totalVested : 0;

        return (
            totalAllocated,
            totalVested,
            totalClaimed,
            totalClaimable,
            totalLocked,
            contractBalance,
            totalSchedules,
            activeSchedules
        );
    }

    /**
     * @notice Get count of schedules in different states for specified beneficiaries
     * @param beneficiaries Array of beneficiary addresses to query
     */
    function getScheduleStateCounts(address[] calldata beneficiaries) external view returns (
        uint256 inCliff,
        uint256 vesting,
        uint256 completed
    ) {
        if (!isStarted) {
            return (0, 0, 0);
        }

        for (uint256 i = 0; i < beneficiaries.length; i++) {
            address beneficiary = beneficiaries[i];
            uint256 scheduleCount = userSchedules[beneficiary].length;

            for (uint256 j = 0; j < scheduleCount; j++) {
                VestingSchedule memory schedule = userSchedules[beneficiary][j];
                if (!schedule.isActive) continue;

                uint256 currentTime = block.timestamp;
                uint256 cliffEnd = startTime + schedule.cliffDuration;
                uint256 vestingEnd = cliffEnd + (schedule.numberOfPeriods * PERIOD_DURATION);

                if (currentTime < cliffEnd) {
                    inCliff++;
                } else if (currentTime < vestingEnd) {
                    vesting++;
                } else {
                    completed++;
                }
            }
        }

        return (inCliff, vesting, completed);
    }

    /**
     * @notice Get detailed information for a beneficiary
     */
    function getBeneficiaryDetail(address beneficiary) external view returns (
        uint256 scheduleCount,
        uint256 totalAllocated,
        uint256 totalVested,
        uint256 totalClaimed,
        uint256 totalClaimable,
        uint256 totalLocked,
        uint256 earliestCliffEnd,
        uint256 latestVestingEnd
    ) {
        scheduleCount = userSchedules[beneficiary].length;
        earliestCliffEnd = type(uint256).max;
        latestVestingEnd = 0;

        for (uint256 i = 0; i < scheduleCount; i++) {
            VestingSchedule memory schedule = userSchedules[beneficiary][i];
            if (!schedule.isActive) continue;

            totalAllocated += schedule.totalAmount;
            totalClaimed += schedule.claimedAmount;
            totalVested += calculateVestedAmount(beneficiary, i);
            totalClaimable += calculateClaimableAmount(beneficiary, i);

            if (isStarted) {
                uint256 cliffEnd = startTime + schedule.cliffDuration;
                uint256 vestingEnd = cliffEnd + (schedule.numberOfPeriods * PERIOD_DURATION);

                if (cliffEnd < earliestCliffEnd) {
                    earliestCliffEnd = cliffEnd;
                }
                if (vestingEnd > latestVestingEnd) {
                    latestVestingEnd = vestingEnd;
                }
            }
        }

        totalLocked = totalAllocated > totalVested ? totalAllocated - totalVested : 0;

        if (earliestCliffEnd == type(uint256).max) {
            earliestCliffEnd = 0;
        }

        return (
            scheduleCount,
            totalAllocated,
            totalVested,
            totalClaimed,
            totalClaimable,
            totalLocked,
            earliestCliffEnd,
            latestVestingEnd
        );
    }

    /**
     * @notice Get summary for multiple beneficiaries
     */
    function getBeneficiariesSummary(
        address[] calldata beneficiaries
    ) external view returns (
        uint256[] memory totalAllocated,
        uint256[] memory totalVested,
        uint256[] memory totalClaimed,
        uint256[] memory totalClaimable,
        uint256[] memory scheduleCount
    ) {
        uint256 length = beneficiaries.length;
        totalAllocated = new uint256[](length);
        totalVested = new uint256[](length);
        totalClaimed = new uint256[](length);
        totalClaimable = new uint256[](length);
        scheduleCount = new uint256[](length);

        for (uint256 i = 0; i < length; i++) {
            address beneficiary = beneficiaries[i];
            scheduleCount[i] = userSchedules[beneficiary].length;

            for (uint256 j = 0; j < scheduleCount[i]; j++) {
                VestingSchedule memory schedule = userSchedules[beneficiary][j];
                if (!schedule.isActive) continue;

                totalAllocated[i] += schedule.totalAmount;
                totalClaimed[i] += schedule.claimedAmount;
                totalVested[i] += calculateVestedAmount(beneficiary, j);
                totalClaimable[i] += calculateClaimableAmount(beneficiary, j);
            }
        }

        return (totalAllocated, totalVested, totalClaimed, totalClaimable, scheduleCount);
    }

    // ========== Query Functions - Time Projections ==========

    /**
     * @notice Get projected vesting at a future timestamp for specified beneficiaries
     * @param timestamp Future timestamp to project
     * @param beneficiaries Array of beneficiary addresses to query
     */
    function getProjectedVestingAt(
        uint256 timestamp,
        address[] calldata beneficiaries
    ) external view returns (
        uint256 projectedVested,
        uint256 projectedLocked,
        uint256 percentageVested
    ) {
        if (!isStarted || timestamp < startTime) {
            return (0, totalAllocatedAmount, 0);
        }

        uint256 totalAllocated = 0;

        for (uint256 i = 0; i < beneficiaries.length; i++) {
            address beneficiary = beneficiaries[i];
            uint256 scheduleCount = userSchedules[beneficiary].length;

            for (uint256 j = 0; j < scheduleCount; j++) {
                VestingSchedule memory schedule = userSchedules[beneficiary][j];
                if (!schedule.isActive) continue;

                totalAllocated += schedule.totalAmount;

                uint256 cliffEnd = startTime + schedule.cliffDuration;

                if (timestamp < cliffEnd) {
                    continue;
                }

                uint256 timeAfterCliff = timestamp - cliffEnd;
                uint256 periodsCompleted = timeAfterCliff / PERIOD_DURATION;

                if (periodsCompleted >= schedule.numberOfPeriods) {
                    projectedVested += schedule.totalAmount;
                } else {
                    projectedVested += periodsCompleted * schedule.amountPerPeriod;
                }
            }
        }

        projectedLocked = totalAllocated > projectedVested ? totalAllocated - projectedVested : 0;
        percentageVested = totalAllocated > 0 ? (projectedVested * 10000) / totalAllocated : 0;

        return (projectedVested, projectedLocked, percentageVested);
    }

    /**
     * @notice Get projected vesting for a user at a future timestamp
     */
    function getUserProjectedVestingAt(
        address user,
        uint256 timestamp
    ) external view returns (
        uint256 projectedVested,
        uint256 projectedClaimable
    ) {
        if (!isStarted || timestamp < startTime) {
            return (0, 0);
        }

        uint256 scheduleCount = userSchedules[user].length;

        for (uint256 i = 0; i < scheduleCount; i++) {
            VestingSchedule memory schedule = userSchedules[user][i];
            if (!schedule.isActive) continue;

            uint256 cliffEnd = startTime + schedule.cliffDuration;

            if (timestamp < cliffEnd) {
                continue;
            }

            uint256 timeAfterCliff = timestamp - cliffEnd;
            uint256 periodsCompleted = timeAfterCliff / PERIOD_DURATION;
            uint256 vested;

            if (periodsCompleted >= schedule.numberOfPeriods) {
                vested = schedule.totalAmount;
            } else {
                vested = periodsCompleted * schedule.amountPerPeriod;
            }

            projectedVested += vested;

            if (vested > schedule.claimedAmount) {
                projectedClaimable += (vested - schedule.claimedAmount);
            }
        }

        return (projectedVested, projectedClaimable);
    }

    // ========== Query Functions - Export Data ==========

    /**
     * @notice Export all schedules for specified beneficiaries
     * @param beneficiaries Array of beneficiary addresses to export
     */
    function exportAllSchedules(address[] calldata beneficiaries) external view returns (
        address[] memory beneficiaryAddresses,
        uint256[] memory scheduleIndexes,
        uint256[] memory scheduleIds,
        uint256[] memory totalAmounts,
        uint256[] memory cliffDurations,
        uint256[] memory numberOfPeriods,
        uint256[] memory amountsPerPeriod,
        uint256[] memory claimedAmounts,
        bool[] memory isActive
    ) {
        // Count total schedules
        uint256 totalCount = 0;
        for (uint256 i = 0; i < beneficiaries.length; i++) {
            totalCount += userSchedules[beneficiaries[i]].length;
        }

        // Initialize arrays
        beneficiaryAddresses = new address[](totalCount);
        scheduleIndexes = new uint256[](totalCount);
        scheduleIds = new uint256[](totalCount);
        totalAmounts = new uint256[](totalCount);
        cliffDurations = new uint256[](totalCount);
        numberOfPeriods = new uint256[](totalCount);
        amountsPerPeriod = new uint256[](totalCount);
        claimedAmounts = new uint256[](totalCount);
        isActive = new bool[](totalCount);

        // Fill arrays
        uint256 index = 0;
        for (uint256 i = 0; i < beneficiaries.length; i++) {
            address beneficiary = beneficiaries[i];
            uint256 scheduleCount = userSchedules[beneficiary].length;

            for (uint256 j = 0; j < scheduleCount; j++) {
                VestingSchedule memory schedule = userSchedules[beneficiary][j];

                beneficiaryAddresses[index] = beneficiary;
                scheduleIndexes[index] = j;
                scheduleIds[index] = schedule.scheduleId;
                totalAmounts[index] = schedule.totalAmount;
                cliffDurations[index] = schedule.cliffDuration;
                numberOfPeriods[index] = schedule.numberOfPeriods;
                amountsPerPeriod[index] = schedule.amountPerPeriod;
                claimedAmounts[index] = schedule.claimedAmount;
                isActive[index] = schedule.isActive;

                index++;
            }
        }

        return (
            beneficiaryAddresses,
            scheduleIndexes,
            scheduleIds,
            totalAmounts,
            cliffDurations,
            numberOfPeriods,
            amountsPerPeriod,
            claimedAmounts,
            isActive
        );
    }

    /**
     * @notice Export all schedules for a user
     */
    function exportUserSchedules(address user) external view returns (
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
    ) {
        uint256 scheduleCount = userSchedules[user].length;

        scheduleIds = new uint256[](scheduleCount);
        totalAmounts = new uint256[](scheduleCount);
        cliffDurations = new uint256[](scheduleCount);
        numberOfPeriods = new uint256[](scheduleCount);
        amountsPerPeriod = new uint256[](scheduleCount);
        claimedAmounts = new uint256[](scheduleCount);
        vestedAmounts = new uint256[](scheduleCount);
        claimableAmounts = new uint256[](scheduleCount);
        cliffEndTimes = new uint256[](scheduleCount);
        vestingEndTimes = new uint256[](scheduleCount);
        isActive = new bool[](scheduleCount);

        for (uint256 i = 0; i < scheduleCount; i++) {
            VestingSchedule memory schedule = userSchedules[user][i];

            scheduleIds[i] = schedule.scheduleId;
            totalAmounts[i] = schedule.totalAmount;
            cliffDurations[i] = schedule.cliffDuration;
            numberOfPeriods[i] = schedule.numberOfPeriods;
            amountsPerPeriod[i] = schedule.amountPerPeriod;
            claimedAmounts[i] = schedule.claimedAmount;
            vestedAmounts[i] = calculateVestedAmount(user, i);
            claimableAmounts[i] = calculateClaimableAmount(user, i);
            isActive[i] = schedule.isActive;

            if (isStarted) {
                cliffEndTimes[i] = startTime + schedule.cliffDuration;
                vestingEndTimes[i] = cliffEndTimes[i] + (schedule.numberOfPeriods * PERIOD_DURATION);
            }
        }

        return (
            scheduleIds,
            totalAmounts,
            cliffDurations,
            numberOfPeriods,
            amountsPerPeriod,
            claimedAmounts,
            vestedAmounts,
            claimableAmounts,
            cliffEndTimes,
            vestingEndTimes,
            isActive
        );
    }

    // ========== Health Check ==========

    /**
     * @notice Check contract health status
     */
    function healthCheck() external view returns (
        bool isHealthy,
        string memory message,
        uint256 requiredBalance,
        uint256 currentBalance,
        uint256 shortfall
    ) {
        currentBalance = token.balanceOf(address(this));
        requiredBalance = totalAllocatedAmount - totalClaimedAmount;

        if (currentBalance >= requiredBalance) {
            return (true, "Contract is healthy", requiredBalance, currentBalance, 0);
        } else {
            shortfall = requiredBalance - currentBalance;
            return (false, "Insufficient balance", requiredBalance, currentBalance, shortfall);
        }
    }
}
