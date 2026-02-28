// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "../src/BSBAirdrop.sol";
import "../src/BlockStreetToken.sol";
import "../src/BlockPass.sol";

contract BSBAirdropTest is Test {
    BlockStreetToken public bsb;
    BlockPass public nft;
    BSBAirdrop public airdrop;

    address public owner = address(this);
    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);

    // Default params: 50 ether initial release, 12-month cliff, 12-month vesting
    uint256 public constant AMOUNT_PER_NFT = 1000 ether;
    uint256 public constant INITIAL_RELEASE = 50 ether;  // direct amount
    uint256 public constant CLIFF = 360 days;             // 12 months
    uint256 public constant VESTING_PERIODS = 12;         // 12 months after cliff
    uint256 public constant PERIOD = 30 days;

    function setUp() public {
        bsb = new BlockStreetToken();
        nft = new BlockPass("https://example.com/");

        airdrop = new BSBAirdrop(
            IERC20(address(bsb)),
            IERC721(address(nft)),
            AMOUNT_PER_NFT,
            INITIAL_RELEASE,
            CLIFF,
            VESTING_PERIODS,
            owner
        );

        // Fund the airdrop contract
        bsb.transfer(address(airdrop), 100_000 ether);

        // Set up NFT minter and mint NFTs
        nft.setMinter(address(this));
        nft.mint(alice); // tokenId 1
        nft.mint(bob);   // tokenId 2
    }

    // ========== Constructor Tests ==========

    function test_constructor_params() public view {
        assertEq(address(airdrop.token()), address(bsb));
        assertEq(address(airdrop.blockPass()), address(nft));
        assertEq(airdrop.amountPerNFT(), AMOUNT_PER_NFT);
        assertEq(airdrop.initialRelease(), INITIAL_RELEASE);
        assertEq(airdrop.cliffDuration(), CLIFF);
        assertEq(airdrop.vestingPeriods(), VESTING_PERIODS);
        assertEq(airdrop.lockedAmount(), AMOUNT_PER_NFT - INITIAL_RELEASE);
    }

    function test_constructor_reverts_zero_token() public {
        vm.expectRevert(BSBAirdrop.InvalidParams.selector);
        new BSBAirdrop(IERC20(address(0)), IERC721(address(nft)), AMOUNT_PER_NFT, INITIAL_RELEASE, CLIFF, VESTING_PERIODS, owner);
    }

    function test_constructor_reverts_zero_nft() public {
        vm.expectRevert(BSBAirdrop.InvalidParams.selector);
        new BSBAirdrop(IERC20(address(bsb)), IERC721(address(0)), AMOUNT_PER_NFT, INITIAL_RELEASE, CLIFF, VESTING_PERIODS, owner);
    }

    function test_constructor_reverts_zero_amount() public {
        vm.expectRevert(BSBAirdrop.InvalidParams.selector);
        new BSBAirdrop(IERC20(address(bsb)), IERC721(address(nft)), 0, INITIAL_RELEASE, CLIFF, VESTING_PERIODS, owner);
    }

    function test_constructor_reverts_zero_periods() public {
        vm.expectRevert(BSBAirdrop.InvalidParams.selector);
        new BSBAirdrop(IERC20(address(bsb)), IERC721(address(nft)), AMOUNT_PER_NFT, INITIAL_RELEASE, CLIFF, 0, owner);
    }

    function test_constructor_reverts_release_exceeds_total() public {
        vm.expectRevert(BSBAirdrop.InvalidParams.selector);
        new BSBAirdrop(IERC20(address(bsb)), IERC721(address(nft)), AMOUNT_PER_NFT, AMOUNT_PER_NFT + 1, CLIFF, VESTING_PERIODS, owner);
    }

    // ========== Start Tests ==========

    function test_startAirdrop() public {
        airdrop.startAirdrop();
        assertTrue(airdrop.isStarted());
        assertEq(airdrop.startTime(), block.timestamp);
    }

    function test_startAirdropAt() public {
        uint256 future = block.timestamp + 1 days;
        airdrop.startAirdropAt(future);
        assertTrue(airdrop.isStarted());
        assertEq(airdrop.startTime(), future);
    }

    function test_startAirdrop_reverts_already_started() public {
        airdrop.startAirdrop();
        vm.expectRevert(BSBAirdrop.AlreadyStarted.selector);
        airdrop.startAirdrop();
    }

    function test_startAirdropAt_reverts_past() public {
        vm.warp(1000);
        vm.expectRevert(BSBAirdrop.InvalidParams.selector);
        airdrop.startAirdropAt(999);
    }

    function test_startAirdrop_only_owner() public {
        vm.prank(alice);
        vm.expectRevert();
        airdrop.startAirdrop();
    }

    // ========== Claim Tests - TGE ==========

    function test_claim_tge_immediately() public {
        airdrop.startAirdrop();

        uint256 expected = INITIAL_RELEASE; // 50 ether (5%)

        vm.prank(alice);
        airdrop.claim(1);

        assertEq(bsb.balanceOf(alice), expected);
        assertEq(airdrop.claimedAmount(1), expected);
        assertEq(airdrop.totalClaimed(), expected);
    }

    function test_claim_reverts_not_started() public {
        vm.prank(alice);
        vm.expectRevert(BSBAirdrop.NotStarted.selector);
        airdrop.claim(1);
    }

    function test_claim_reverts_before_start_time() public {
        airdrop.startAirdropAt(block.timestamp + 1 days);

        vm.prank(alice);
        vm.expectRevert(BSBAirdrop.NotStarted.selector);
        airdrop.claim(1);
    }

    function test_claim_reverts_not_owner() public {
        airdrop.startAirdrop();

        vm.prank(bob);
        vm.expectRevert(BSBAirdrop.NotNFTOwner.selector);
        airdrop.claim(1); // tokenId 1 belongs to alice
    }

    function test_claim_reverts_nothing_to_claim() public {
        airdrop.startAirdrop();

        vm.prank(alice);
        airdrop.claim(1); // first claim succeeds

        vm.prank(alice);
        vm.expectRevert(BSBAirdrop.NothingToClaim.selector);
        airdrop.claim(1); // second claim fails (nothing new)
    }

    // ========== Claim Tests - During Cliff ==========

    function test_no_additional_during_cliff() public {
        airdrop.startAirdrop();

        // Claim TGE
        vm.prank(alice);
        airdrop.claim(1);
        uint256 balanceAfterTGE = bsb.balanceOf(alice);

        // Warp to middle of cliff
        vm.warp(block.timestamp + 180 days);

        // Nothing new to claim
        assertEq(airdrop.getClaimable(1), 0);

        // Should revert
        vm.prank(alice);
        vm.expectRevert(BSBAirdrop.NothingToClaim.selector);
        airdrop.claim(1);

        assertEq(bsb.balanceOf(alice), balanceAfterTGE);
    }

    // ========== Claim Tests - After Cliff ==========

    function test_claim_after_cliff_nothing_extra() public {
        airdrop.startAirdrop();
        uint256 start = block.timestamp;

        // Claim TGE first
        vm.prank(alice);
        airdrop.claim(1);

        // At cliff end: no new tokens unlocked yet (need to wait 30 more days)
        vm.warp(start + CLIFF);
        assertEq(airdrop.getClaimable(1), 0);
    }

    function test_claim_after_cliff_first_period() public {
        airdrop.startAirdrop();
        uint256 start = block.timestamp;

        // Warp to cliff + 30 days for first vesting period
        vm.warp(start + CLIFF + PERIOD);

        uint256 tge = INITIAL_RELEASE;
        uint256 locked = AMOUNT_PER_NFT - tge;
        uint256 firstPeriodVested = locked * 1 / VESTING_PERIODS;
        uint256 expectedTotal = tge + firstPeriodVested;

        vm.prank(alice);
        airdrop.claim(1);

        assertEq(bsb.balanceOf(alice), expectedTotal);
    }

    function test_claim_after_cliff_mid_vesting() public {
        airdrop.startAirdrop();
        uint256 start = block.timestamp;

        // Warp to cliff + 6 months: periodsCompleted = 6*30/30 = 6
        vm.warp(start + CLIFF + 6 * PERIOD);

        uint256 tge = INITIAL_RELEASE;
        uint256 locked = AMOUNT_PER_NFT - tge;
        uint256 vestedFromLock = locked * 6 / VESTING_PERIODS;
        uint256 expected = tge + vestedFromLock;

        vm.prank(alice);
        airdrop.claim(1);

        assertEq(bsb.balanceOf(alice), expected);
    }

    function test_claim_fully_vested() public {
        airdrop.startAirdrop();
        uint256 start = block.timestamp;

        // Warp past all vesting
        vm.warp(start + CLIFF + VESTING_PERIODS * PERIOD);

        vm.prank(alice);
        airdrop.claim(1);

        assertEq(bsb.balanceOf(alice), AMOUNT_PER_NFT);
        assertEq(airdrop.claimedAmount(1), AMOUNT_PER_NFT);
    }

    function test_claim_incremental() public {
        airdrop.startAirdrop();
        uint256 start = block.timestamp;

        uint256 tge = INITIAL_RELEASE;
        uint256 locked = AMOUNT_PER_NFT - tge;

        // Claim TGE
        vm.prank(alice);
        airdrop.claim(1);
        assertEq(bsb.balanceOf(alice), tge);

        // Warp to cliff + 3 months: periodsCompleted = 3
        vm.warp(start + CLIFF + 3 * PERIOD);
        uint256 vested3 = locked * 3 / VESTING_PERIODS;

        vm.prank(alice);
        airdrop.claim(1);
        assertEq(bsb.balanceOf(alice), tge + vested3);

        // Warp to fully vested
        vm.warp(start + CLIFF + VESTING_PERIODS * PERIOD);

        vm.prank(alice);
        airdrop.claim(1);
        assertEq(bsb.balanceOf(alice), AMOUNT_PER_NFT);
    }

    // ========== Batch Claim Tests ==========

    function test_claimBatch() public {
        // Mint a second NFT to alice
        nft.mint(alice); // tokenId 3

        airdrop.startAirdrop();

        uint256 tge = INITIAL_RELEASE;

        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = 1;
        tokenIds[1] = 3;

        vm.prank(alice);
        airdrop.claimBatch(tokenIds);

        assertEq(bsb.balanceOf(alice), tge * 2);
        assertEq(airdrop.totalClaimed(), tge * 2);
    }

    function test_claimBatch_reverts_not_owner() public {
        airdrop.startAirdrop();

        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = 1;
        tokenIds[1] = 2; // belongs to bob

        vm.prank(alice);
        vm.expectRevert(BSBAirdrop.NotNFTOwner.selector);
        airdrop.claimBatch(tokenIds);
    }

    function test_claimBatch_reverts_nothing() public {
        airdrop.startAirdrop();

        // Claim first
        vm.prank(alice);
        airdrop.claim(1);

        // Batch claim again - nothing left
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 1;

        vm.prank(alice);
        vm.expectRevert(BSBAirdrop.NothingToClaim.selector);
        airdrop.claimBatch(tokenIds);
    }

    // ========== View Function Tests ==========

    function test_getClaimable_before_start() public view {
        assertEq(airdrop.getClaimable(1), 0);
    }

    function test_getVestingInfo() public {
        airdrop.startAirdrop();
        uint256 start = block.timestamp;

        (
            uint256 totalAmount,
            uint256 vestedAmount,
            uint256 claimedAmt,
            uint256 claimableAmount,
            uint256 cliffEndTime,
            uint256 vestingEndTime
        ) = airdrop.getVestingInfo(1);

        assertEq(totalAmount, AMOUNT_PER_NFT);
        assertEq(vestedAmount, airdrop.initialRelease());
        assertEq(claimedAmt, 0);
        assertEq(claimableAmount, airdrop.initialRelease());
        assertEq(cliffEndTime, start + CLIFF);
        assertEq(vestingEndTime, start + CLIFF + VESTING_PERIODS * PERIOD);
    }

    function test_getClaimableBatch() public {
        airdrop.startAirdrop();

        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = 1;
        tokenIds[1] = 2;

        uint256[] memory amounts = airdrop.getClaimableBatch(tokenIds);
        assertEq(amounts.length, 2);
        assertEq(amounts[0], airdrop.initialRelease());
        assertEq(amounts[1], airdrop.initialRelease());
    }

    // ========== Withdraw Tests ==========

    function test_withdrawRemaining() public {
        uint256 contractBal = bsb.balanceOf(address(airdrop));
        address treasury = address(0xDEAD);

        airdrop.withdrawRemaining(treasury);
        assertEq(bsb.balanceOf(treasury), contractBal);
        assertEq(bsb.balanceOf(address(airdrop)), 0);
    }

    function test_withdrawRemaining_only_owner() public {
        vm.prank(alice);
        vm.expectRevert();
        airdrop.withdrawRemaining(alice);
    }

    function test_withdrawRemaining_reverts_zero_address() public {
        vm.expectRevert(BSBAirdrop.InvalidParams.selector);
        airdrop.withdrawRemaining(address(0));
    }

    // ========== Edge Cases ==========

    function test_zero_initial_release() public {
        // Deploy with 0 initial release
        BSBAirdrop noTge = new BSBAirdrop(
            IERC20(address(bsb)),
            IERC721(address(nft)),
            AMOUNT_PER_NFT,
            0,
            CLIFF,
            VESTING_PERIODS,
            owner
        );
        bsb.transfer(address(noTge), 100_000 ether);
        noTge.startAirdrop();

        // Nothing claimable before cliff
        assertEq(noTge.getClaimable(1), 0);

        // At cliff end: still 0 (need to wait 30 more days)
        vm.warp(block.timestamp + CLIFF);
        assertEq(noTge.getClaimable(1), 0);

        // After cliff + 30 days: first period vests
        vm.warp(block.timestamp + PERIOD);
        uint256 expected = AMOUNT_PER_NFT * 1 / VESTING_PERIODS;
        assertEq(noTge.getClaimable(1), expected);
    }

    function test_full_initial_release() public {
        // Deploy with 100% initial release
        BSBAirdrop fullTge = new BSBAirdrop(
            IERC20(address(bsb)),
            IERC721(address(nft)),
            AMOUNT_PER_NFT,
            AMOUNT_PER_NFT,  // all released immediately
            0,
            1,
            owner
        );
        bsb.transfer(address(fullTge), 100_000 ether);
        fullTge.startAirdrop();

        vm.prank(alice);
        fullTge.claim(1);
        assertEq(bsb.balanceOf(alice), AMOUNT_PER_NFT);
    }

    function test_nonexistent_tokenId_reverts() public {
        airdrop.startAirdrop();

        vm.prank(alice);
        vm.expectRevert(); // ownerOf reverts for nonexistent token
        airdrop.claim(999);
    }

    function test_multiple_users_independent() public {
        airdrop.startAirdrop();

        uint256 tge = INITIAL_RELEASE;

        vm.prank(alice);
        airdrop.claim(1);
        assertEq(bsb.balanceOf(alice), tge);

        vm.prank(bob);
        airdrop.claim(2);
        assertEq(bsb.balanceOf(bob), tge);

        assertEq(airdrop.totalClaimed(), tge * 2);
    }
}
