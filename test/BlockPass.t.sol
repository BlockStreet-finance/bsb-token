// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "../src/BlockPass.sol";
import "../src/BlockPassMinter.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

// ═══════════════════════════════════════════════════════
// BlockPass NFT tests
// ═══════════════════════════════════════════════════════

contract BlockPassTest is Test {
    BlockPass public nft;
    address public user1 = address(0x1001);
    address public user2 = address(0x1002);
    address public minterAddr = address(0xAAAA);

    function setUp() public {
        nft = new BlockPass("https://api.blockstreet.com/pass/");
        nft.setMinter(minterAddr);
    }

    function test_constructor() public view {
        assertEq(nft.name(), "Block Pass");
        assertEq(nft.symbol(), "BSP");
        assertEq(nft.totalSupply(), 0);
        assertEq(nft.MAX_SUPPLY(), 2000);
        assertEq(nft.minter(), minterAddr);
    }

    function test_mint_by_minter() public {
        vm.prank(minterAddr);
        uint256 tokenId = nft.mint(user1);

        assertEq(tokenId, 1);
        assertEq(nft.balanceOf(user1), 1);
        assertEq(nft.ownerOf(1), user1);
        assertEq(nft.totalSupply(), 1);
    }

    function test_mint_revert_not_minter() public {
        vm.prank(user1);
        vm.expectRevert(BlockPass.NotMinter.selector);
        nft.mint(user1);
    }

    function test_mint_revert_max_supply() public {
        vm.startPrank(minterAddr);
        for (uint256 i = 0; i < 2000; i++) {
            nft.mint(address(uint160(0x10000 + i)));
        }
        vm.expectRevert(BlockPass.MaxSupplyReached.selector);
        nft.mint(user1);
        vm.stopPrank();
    }

    function test_transfer_revert_soulbound() public {
        vm.prank(minterAddr);
        nft.mint(user1);

        vm.prank(user1);
        vm.expectRevert(BlockPass.Soulbound.selector);
        nft.transferFrom(user1, user2, 1);
    }

    function test_safeTransfer_revert_soulbound() public {
        vm.prank(minterAddr);
        nft.mint(user1);

        vm.prank(user1);
        vm.expectRevert(BlockPass.Soulbound.selector);
        nft.safeTransferFrom(user1, user2, 1);
    }

    function test_tokenURI() public {
        vm.prank(minterAddr);
        nft.mint(user1);
        assertEq(nft.tokenURI(1), "https://api.blockstreet.com/pass/1");
    }

    function test_setMinter() public {
        address newMinter = address(0xBBBB);
        nft.setMinter(newMinter);
        assertEq(nft.minter(), newMinter);
    }

    function test_setMinter_revert_zero() public {
        vm.expectRevert(BlockPass.ZeroAddress.selector);
        nft.setMinter(address(0));
    }

    function test_setMinter_revert_not_owner() public {
        vm.prank(user1);
        vm.expectRevert();
        nft.setMinter(user1);
    }

    function test_setBaseURI() public {
        nft.setBaseURI("https://new.uri/");
        vm.prank(minterAddr);
        nft.mint(user1);
        assertEq(nft.tokenURI(1), "https://new.uri/1");
    }

    function test_remaining() public {
        assertEq(nft.remaining(), 2000);
        vm.prank(minterAddr);
        nft.mint(user1);
        assertEq(nft.remaining(), 1999);
    }
}

// ═══════════════════════════════════════════════════════
// BlockPassMinter tests
// ═══════════════════════════════════════════════════════

contract BlockPassMinterTest is Test {
    BlockPass public nft;
    BlockPassMinter public minter;

    uint256 public signerKey = 0xA11CE;
    address public signerAddr;
    address public treasury = address(0xBEEF);
    address public user1 = address(0x1001);
    address public user2 = address(0x1002);

    function setUp() public {
        signerAddr = vm.addr(signerKey);

        nft = new BlockPass("https://api.blockstreet.com/pass/");
        minter = new BlockPassMinter(
            address(nft),
            signerAddr,
            treasury
        );
        nft.setMinter(address(minter));

        // Fund users with native token
        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);
    }

    uint256 public constant DEFAULT_DEADLINE = 3 minutes;
    uint256 public constant MINT_PRICE = 0.00111 ether;

    // ─── Helpers ──────────────────────────────────────
    function _deadline() internal view returns (uint256) {
        return block.timestamp + DEFAULT_DEADLINE;
    }

    function _sign(address _minter, uint8 phase, uint256 deadline) internal view returns (bytes memory) {
        bytes32 msgHash = keccak256(
            abi.encodePacked(_minter, phase, deadline, block.chainid, address(minter))
        );
        bytes32 ethHash = MessageHashUtils.toEthSignedMessageHash(msgHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerKey, ethHash);
        return abi.encodePacked(r, s, v);
    }

    function _sign(address _minter, uint8 phase) internal view returns (bytes memory) {
        return _sign(_minter, phase, _deadline());
    }

    // ─── Constructor ──────────────────────────────────
    function test_constructor() public view {
        assertEq(address(minter.nft()), address(nft));
        assertEq(minter.signer(), signerAddr);
        assertEq(minter.treasury(), treasury);
        assertEq(uint8(minter.phase()), uint8(BlockPassMinter.Phase.PAUSED));
        assertEq(minter.MINT_PRICE(), 0.00111 ether);
        assertEq(minter.PHASE1_SUPPLY(), 1500);
        assertEq(minter.PHASE2_SUPPLY(), 500);
    }

    function test_constructor_revert_zero_nft() public {
        vm.expectRevert(BlockPassMinter.ZeroAddress.selector);
        new BlockPassMinter(address(0), signerAddr, treasury);
    }

    function test_constructor_revert_zero_signer() public {
        vm.expectRevert(BlockPassMinter.ZeroAddress.selector);
        new BlockPassMinter(address(nft), address(0), treasury);
    }

    function test_constructor_revert_zero_treasury() public {
        vm.expectRevert(BlockPassMinter.ZeroAddress.selector);
        new BlockPassMinter(address(nft), signerAddr, address(0));
    }

    // ─── Mint: phase1 ───────────────────────────────
    function test_mint_phase1() public {
        minter.setPhase(BlockPassMinter.Phase.PHASE1);

        vm.prank(user1);
        minter.mint{value: MINT_PRICE}(1, _deadline(), _sign(user1, 1));

        assertEq(nft.balanceOf(user1), 1);
        assertEq(nft.ownerOf(1), user1);
        assertEq(nft.totalSupply(), 1);
        assertEq(minter.phase1Minted(), 1);
        assertTrue(minter.hasMinted(user1));
        assertEq(treasury.balance, MINT_PRICE);
    }

    // ─── Mint: phase2 ───────────────────────────────
    function test_mint_phase2() public {
        // Phase1 auto-transitions to Phase2 after filling
        _fillPhase1();
        assertEq(uint8(minter.phase()), uint8(BlockPassMinter.Phase.PHASE2));

        vm.prank(user2);
        minter.mint{value: MINT_PRICE}(2, _deadline(), _sign(user2, 2));

        assertEq(nft.balanceOf(user2), 1);
        assertEq(minter.phase2Minted(), 1);
    }

    // ─── Mint: paused ─────────────────────────────────
    function test_mint_revert_paused() public {
        vm.prank(user1);
        vm.expectRevert(BlockPassMinter.MintPaused.selector);
        minter.mint{value: MINT_PRICE}(1, _deadline(), _sign(user1, 1));
    }

    // ─── Mint: wrong phase ────────────────────────────
    function test_mint_revert_wrong_phase() public {
        _fillPhase1(); // auto-transitions to Phase2

        vm.prank(user1);
        vm.expectRevert(BlockPassMinter.WrongPhase.selector);
        minter.mint{value: MINT_PRICE}(1, _deadline(), _sign(user1, 1)); // signed for phase1
    }

    // ─── Mint: already minted ─────────────────────────
    function test_mint_revert_already_minted() public {
        minter.setPhase(BlockPassMinter.Phase.PHASE1);

        vm.prank(user1);
        minter.mint{value: MINT_PRICE}(1, _deadline(), _sign(user1, 1));

        vm.prank(user1);
        vm.expectRevert(BlockPassMinter.AlreadyMinted.selector);
        minter.mint{value: MINT_PRICE}(1, _deadline(), _sign(user1, 1));
    }

    // ─── Mint: expired signature ──────────────────────
    function test_mint_revert_expired() public {
        minter.setPhase(BlockPassMinter.Phase.PHASE1);
        uint256 deadline = block.timestamp + 3 minutes;
        bytes memory sig = _sign(user1, 1, deadline);

        vm.warp(deadline + 1);
        vm.prank(user1);
        vm.expectRevert(BlockPassMinter.SignatureExpired.selector);
        minter.mint{value: MINT_PRICE}(1, deadline, sig);
    }

    // ─── Mint: deadline too far in the future ────────
    function test_mint_revert_deadline_too_far() public {
        minter.setPhase(BlockPassMinter.Phase.PHASE1);
        uint256 deadline = block.timestamp + 6 minutes;
        bytes memory sig = _sign(user1, 1, deadline);

        vm.prank(user1);
        vm.expectRevert(BlockPassMinter.SignatureExpired.selector);
        minter.mint{value: MINT_PRICE}(1, deadline, sig);
    }

    // ─── Mint: invalid signature ──────────────────────
    function test_mint_revert_invalid_sig() public {
        minter.setPhase(BlockPassMinter.Phase.PHASE1);
        bytes memory sig = _sign(user1, 1);

        vm.prank(user2); // wrong sender
        vm.expectRevert(BlockPassMinter.InvalidSignature.selector);
        minter.mint{value: MINT_PRICE}(1, _deadline(), sig);
    }

    // ─── Mint: phase1 auto-transitions to phase2 ──────
    function test_mint_phase1_auto_phase2() public {
        minter.setPhase(BlockPassMinter.Phase.PHASE1);

        for (uint256 i = 1; i <= 1500; i++) {
            address u = address(uint160(0x10000 + i));
            vm.deal(u, MINT_PRICE);
            vm.prank(u);
            minter.mint{value: MINT_PRICE}(1, _deadline(), _sign(u, 1));
        }

        assertEq(minter.phase1Minted(), 1500);
        // Auto-transitioned to Phase2
        assertEq(uint8(minter.phase()), uint8(BlockPassMinter.Phase.PHASE2));

        // Phase1 signature no longer works
        address extra = address(0xDEAD);
        vm.deal(extra, MINT_PRICE);
        vm.prank(extra);
        vm.expectRevert(BlockPassMinter.WrongPhase.selector);
        minter.mint{value: MINT_PRICE}(1, _deadline(), _sign(extra, 1));
    }

    // ─── Mint: phase2 supply cap (500) ────────────────
    function test_mint_revert_phase2_supply() public {
        _fillPhase1(); // auto-transitions to Phase2

        for (uint256 i = 1; i <= 500; i++) {
            address u = address(uint160(0x20000 + i));
            vm.deal(u, MINT_PRICE);
            vm.prank(u);
            minter.mint{value: MINT_PRICE}(2, _deadline(), _sign(u, 2));
        }

        assertEq(minter.phase2Minted(), 500);

        address extra = address(0xBEAD);
        vm.deal(extra, MINT_PRICE);
        vm.prank(extra);
        vm.expectRevert(BlockPassMinter.PhaseSupplyReached.selector);
        minter.mint{value: MINT_PRICE}(2, _deadline(), _sign(extra, 2));
    }

    // ─── Helpers ─────────────────────────────────────
    function _fillPhase1() internal {
        minter.setPhase(BlockPassMinter.Phase.PHASE1);
        for (uint256 i = 1; i <= 1500; i++) {
            address u = address(uint160(0x50000 + i));
            vm.deal(u, MINT_PRICE);
            vm.prank(u);
            minter.mint{value: MINT_PRICE}(1, _deadline(), _sign(u, 1));
        }
    }

    // ─── Admin ────────────────────────────────────────
    function test_setPhase() public {
        minter.setPhase(BlockPassMinter.Phase.PHASE1);
        assertEq(uint8(minter.phase()), 1);

        // After filling phase1, auto-transitions to Phase2
        _fillPhase1();
        assertEq(uint8(minter.phase()), 2);

        minter.setPhase(BlockPassMinter.Phase.PAUSED);
        assertEq(uint8(minter.phase()), 0);
    }

    function test_setPhase_revert_phase2_before_phase1_complete() public {
        minter.setPhase(BlockPassMinter.Phase.PHASE1);
        vm.expectRevert(BlockPassMinter.Phase1NotComplete.selector);
        minter.setPhase(BlockPassMinter.Phase.PHASE2);
    }

    function test_setPhase_revert_not_owner() public {
        vm.prank(user1);
        vm.expectRevert();
        minter.setPhase(BlockPassMinter.Phase.PHASE1);
    }

    function test_setSigner() public {
        address newSigner = address(0xCAFE);
        minter.setSigner(newSigner);
        assertEq(minter.signer(), newSigner);
    }

    function test_setSigner_revert_zero() public {
        vm.expectRevert(BlockPassMinter.ZeroAddress.selector);
        minter.setSigner(address(0));
    }

    function test_setTreasury() public {
        address newTreasury = address(0xCAFE);
        minter.setTreasury(newTreasury);
        assertEq(minter.treasury(), newTreasury);
    }

    function test_setTreasury_revert_zero() public {
        vm.expectRevert(BlockPassMinter.ZeroAddress.selector);
        minter.setTreasury(address(0));
    }
}
