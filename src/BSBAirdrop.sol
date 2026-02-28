// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title BSB Airdrop
 * @dev Airdrop contract for BlockPass NFT holders.
 *      - Initial release available immediately after start
 *      - Remaining locked for a cliff period (e.g. 12 months)
 *      - After cliff, remaining released monthly over configurable periods
 *      - Users claim themselves based on NFT ownership
 */
contract BSBAirdrop is Ownable, ReentrancyGuard {
    IERC20 public immutable token;
    IERC721 public immutable blockPass;

    uint256 public constant PERIOD_DURATION = 30 days;

    // Configurable parameters (set at deployment)
    uint256 public immutable amountPerNFT;      // Total airdrop amount per NFT
    uint256 public immutable initialRelease;     // Amount released immediately per NFT (e.g. 1250e18)
    uint256 public immutable cliffDuration;      // Cliff period in seconds (e.g. 360 days)
    uint256 public immutable vestingPeriods;     // Number of monthly periods after cliff

    // Derived
    uint256 public immutable lockedAmount;       // Amount locked per NFT (= amountPerNFT - initialRelease)

    // State
    bool public isStarted;
    uint256 public startTime;
    uint256 public totalClaimed;

    // tokenId => amount already claimed
    mapping(uint256 => uint256) public claimedAmount;

    // Events
    event AirdropStarted(uint256 startTime);
    event Claimed(address indexed user, uint256 indexed tokenId, uint256 amount);
    event Withdrawn(address indexed to, uint256 amount);

    // Errors
    error NotStarted();
    error AlreadyStarted();
    error NotNFTOwner();
    error NothingToClaim();
    error InsufficientBalance();
    error InvalidParams();

    constructor(
        IERC20 _token,
        IERC721 _blockPass,
        uint256 _amountPerNFT,
        uint256 _initialRelease,
        uint256 _cliffDuration,
        uint256 _vestingPeriods,
        address _owner
    ) Ownable(_owner) {
        if (address(_token) == address(0) || address(_blockPass) == address(0)) revert InvalidParams();
        if (_amountPerNFT == 0 || _vestingPeriods == 0) revert InvalidParams();
        if (_initialRelease > _amountPerNFT) revert InvalidParams();

        token = _token;
        blockPass = _blockPass;
        amountPerNFT = _amountPerNFT;
        initialRelease = _initialRelease;
        cliffDuration = _cliffDuration;
        vestingPeriods = _vestingPeriods;
        lockedAmount = _amountPerNFT - _initialRelease;
    }

    // ========== Owner Functions ==========

    /// @notice Start the airdrop at current block timestamp
    function startAirdrop() external onlyOwner {
        if (isStarted) revert AlreadyStarted();
        startTime = block.timestamp;
        isStarted = true;
        emit AirdropStarted(startTime);
    }

    /// @notice Start the airdrop at a future timestamp
    function startAirdropAt(uint256 _startTime) external onlyOwner {
        if (isStarted) revert AlreadyStarted();
        if (_startTime < block.timestamp) revert InvalidParams();
        startTime = _startTime;
        isStarted = true;
        emit AirdropStarted(_startTime);
    }

    /// @notice Withdraw remaining tokens (e.g. after airdrop ends)
    function withdrawRemaining(address to) external onlyOwner {
        if (to == address(0)) revert InvalidParams();
        uint256 balance = token.balanceOf(address(this));
        require(token.transfer(to, balance), "Transfer failed");
        emit Withdrawn(to, balance);
    }

    // ========== User Functions ==========

    /// @notice Claim airdrop for a single NFT
    function claim(uint256 tokenId) external nonReentrant {
        if (!isStarted || block.timestamp < startTime) revert NotStarted();
        if (blockPass.ownerOf(tokenId) != msg.sender) revert NotNFTOwner();

        uint256 claimable = _claimableFor(tokenId);
        if (claimable == 0) revert NothingToClaim();

        claimedAmount[tokenId] += claimable;
        totalClaimed += claimable;

        require(token.transfer(msg.sender, claimable), "Transfer failed");
        emit Claimed(msg.sender, tokenId, claimable);
    }

    /// @notice Claim airdrop for multiple NFTs in one transaction
    function claimBatch(uint256[] calldata tokenIds) external nonReentrant {
        if (!isStarted || block.timestamp < startTime) revert NotStarted();

        uint256 totalClaimable = 0;

        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];
            if (blockPass.ownerOf(tokenId) != msg.sender) revert NotNFTOwner();

            uint256 claimable = _claimableFor(tokenId);
            if (claimable > 0) {
                claimedAmount[tokenId] += claimable;
                totalClaimable += claimable;
                emit Claimed(msg.sender, tokenId, claimable);
            }
        }

        if (totalClaimable == 0) revert NothingToClaim();

        totalClaimed += totalClaimable;
        require(token.transfer(msg.sender, totalClaimable), "Transfer failed");
    }

    // ========== Internal Functions ==========

    function _claimableFor(uint256 tokenId) internal view returns (uint256) {
        uint256 vested = _vestedFor(tokenId);
        uint256 claimed = claimedAmount[tokenId];
        return vested > claimed ? vested - claimed : 0;
    }

    function _vestedFor(uint256 /* tokenId */) internal view returns (uint256) {
        // Before cliff: only TGE portion
        if (block.timestamp < startTime + cliffDuration) {
            return initialRelease;
        }

        // After cliff: TGE + proportional locked amount
        uint256 timeAfterCliff = block.timestamp - (startTime + cliffDuration);
        uint256 periodsCompleted = timeAfterCliff / PERIOD_DURATION;

        if (periodsCompleted >= vestingPeriods) {
            return amountPerNFT; // Fully vested
        }

        uint256 vestedFromLock = lockedAmount * periodsCompleted / vestingPeriods;
        return initialRelease + vestedFromLock;
    }

    // ========== View Functions ==========

    /// @notice Get claimable amount for a tokenId
    function getClaimable(uint256 tokenId) external view returns (uint256) {
        if (!isStarted || block.timestamp < startTime) return 0;
        return _claimableFor(tokenId);
    }

    /// @notice Get full vesting info for a tokenId
    function getVestingInfo(uint256 tokenId) external view returns (
        uint256 totalAmount,
        uint256 vestedAmount,
        uint256 claimedAmt,
        uint256 claimableAmount,
        uint256 cliffEndTime,
        uint256 vestingEndTime
    ) {
        totalAmount = amountPerNFT;
        claimedAmt = claimedAmount[tokenId];

        if (isStarted && block.timestamp >= startTime) {
            vestedAmount = _vestedFor(tokenId);
            claimableAmount = vestedAmount > claimedAmt ? vestedAmount - claimedAmt : 0;
        }

        if (isStarted) {
            cliffEndTime = startTime + cliffDuration;
            vestingEndTime = cliffEndTime + (vestingPeriods * PERIOD_DURATION);
        }
    }

    /// @notice Get batch claimable amounts for multiple tokenIds
    function getClaimableBatch(uint256[] calldata tokenIds) external view returns (uint256[] memory amounts) {
        amounts = new uint256[](tokenIds.length);
        for (uint256 i = 0; i < tokenIds.length; i++) {
            if (isStarted && block.timestamp >= startTime) {
                amounts[i] = _claimableFor(tokenIds[i]);
            }
        }
    }
}
