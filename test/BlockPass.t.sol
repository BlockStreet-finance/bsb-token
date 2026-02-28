// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "../src/BlockPass.sol";
import "../src/BlockPassMinter.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract MockUSDT is ERC20 {
    constructor() ERC20("Mock USDT", "USDT") {}

    function decimals() public pure override returns (uint8) {
        return 6;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

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
    MockUSDT public usdt;

    uint256 public signerKey = 0xA11CE;
    address public signerAddr;
    address public treasury = address(0xBEEF);
    address public user1 = address(0x1001);
    address public user2 = address(0x1002);

    function setUp() public {
        signerAddr = vm.addr(signerKey);
        usdt = new MockUSDT();

        nft = new BlockPass("https://api.blockstreet.com/pass/");
        minter = new BlockPassMinter(
            address(nft),
            signerAddr,
            address(usdt),
            treasury
        );
        nft.setMinter(address(minter));

        // Give users USDT and approve the minter
        usdt.mint(user1, 100 * 10 ** 6);
        usdt.mint(user2, 100 * 10 ** 6);
        vm.prank(user1);
        usdt.approve(address(minter), type(uint256).max);
        vm.prank(user2);
        usdt.approve(address(minter), type(uint256).max);
    }

    // ─── Helpers ──────────────────────────────────────
    function _sign(address _minter, uint8 phase) internal view returns (bytes memory) {
        bytes32 msgHash = keccak256(
            abi.encodePacked(_minter, phase, block.chainid, address(minter))
        );
        bytes32 ethHash = MessageHashUtils.toEthSignedMessageHash(msgHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerKey, ethHash);
        return abi.encodePacked(r, s, v);
    }

    // ─── Constructor ──────────────────────────────────
    function test_constructor() public view {
        assertEq(address(minter.nft()), address(nft));
        assertEq(minter.signer(), signerAddr);
        assertEq(address(minter.usdt()), address(usdt));
        assertEq(minter.treasury(), treasury);
        assertEq(uint8(minter.phase()), uint8(BlockPassMinter.Phase.PAUSED));
        assertEq(minter.MINT_PRICE(), 5 * 10 ** 6);
        assertEq(minter.PHASE1_SUPPLY(), 1500);
        assertEq(minter.PHASE2_SUPPLY(), 500);
    }

    function test_constructor_revert_zero_nft() public {
        vm.expectRevert(BlockPassMinter.ZeroAddress.selector);
        new BlockPassMinter(address(0), signerAddr, address(usdt), treasury);
    }

    function test_constructor_revert_zero_signer() public {
        vm.expectRevert(BlockPassMinter.ZeroAddress.selector);
        new BlockPassMinter(address(nft), address(0), address(usdt), treasury);
    }

    function test_constructor_revert_zero_usdt() public {
        vm.expectRevert(BlockPassMinter.ZeroAddress.selector);
        new BlockPassMinter(address(nft), signerAddr, address(0), treasury);
    }

    function test_constructor_revert_zero_treasury() public {
        vm.expectRevert(BlockPassMinter.ZeroAddress.selector);
        new BlockPassMinter(address(nft), signerAddr, address(usdt), address(0));
    }

    // ─── Mint: phase1 ───────────────────────────────
    function test_mint_phase1() public {
        minter.setPhase(BlockPassMinter.Phase.PHASE1);

        vm.prank(user1);
        minter.mint(1, _sign(user1, 1));

        assertEq(nft.balanceOf(user1), 1);
        assertEq(nft.ownerOf(1), user1);
        assertEq(nft.totalSupply(), 1);
        assertEq(minter.phase1Minted(), 1);
        assertTrue(minter.hasMinted(user1));
        assertEq(usdt.balanceOf(treasury), 5 * 10 ** 6);
    }

    // ─── Mint: phase2 ───────────────────────────────
    function test_mint_phase2() public {
        // Must complete phase1 first
        _fillPhase1();
        minter.setPhase(BlockPassMinter.Phase.PHASE2);

        vm.prank(user2);
        minter.mint(2, _sign(user2, 2));

        assertEq(nft.balanceOf(user2), 1);
        assertEq(minter.phase2Minted(), 1);
    }

    // ─── Mint: paused ─────────────────────────────────
    function test_mint_revert_paused() public {
        vm.prank(user1);
        vm.expectRevert(BlockPassMinter.MintPaused.selector);
        minter.mint(1, _sign(user1, 1));
    }

    // ─── Mint: wrong phase ────────────────────────────
    function test_mint_revert_wrong_phase() public {
        _fillPhase1();
        minter.setPhase(BlockPassMinter.Phase.PHASE2);

        vm.prank(user1);
        vm.expectRevert(BlockPassMinter.WrongPhase.selector);
        minter.mint(1, _sign(user1, 1)); // signed for phase1
    }

    // ─── Mint: already minted ─────────────────────────
    function test_mint_revert_already_minted() public {
        minter.setPhase(BlockPassMinter.Phase.PHASE1);

        vm.prank(user1);
        minter.mint(1, _sign(user1, 1));

        vm.prank(user1);
        vm.expectRevert(BlockPassMinter.AlreadyMinted.selector);
        minter.mint(1, _sign(user1, 1));
    }

    // ─── Mint: invalid signature ──────────────────────
    function test_mint_revert_invalid_sig() public {
        minter.setPhase(BlockPassMinter.Phase.PHASE1);
        bytes memory sig = _sign(user1, 1);

        vm.prank(user2); // wrong sender
        vm.expectRevert(BlockPassMinter.InvalidSignature.selector);
        minter.mint(1, sig);
    }

    // ─── Mint: phase1 supply cap (1500) ───────────────
    function test_mint_revert_phase1_supply() public {
        minter.setPhase(BlockPassMinter.Phase.PHASE1);

        for (uint256 i = 1; i <= 1500; i++) {
            address u = address(uint160(0x10000 + i));
            usdt.mint(u, 5 * 10 ** 6);
            vm.prank(u);
            usdt.approve(address(minter), type(uint256).max);
            vm.prank(u);
            minter.mint(1, _sign(u, 1));
        }

        assertEq(minter.phase1Minted(), 1500);

        address extra = address(0xDEAD);
        usdt.mint(extra, 5 * 10 ** 6);
        vm.prank(extra);
        usdt.approve(address(minter), type(uint256).max);
        vm.prank(extra);
        vm.expectRevert(BlockPassMinter.PhaseSupplyReached.selector);
        minter.mint(1, _sign(extra, 1));
    }

    // ─── Mint: phase2 supply cap (500) ────────────────
    function test_mint_revert_phase2_supply() public {
        _fillPhase1();
        minter.setPhase(BlockPassMinter.Phase.PHASE2);

        for (uint256 i = 1; i <= 500; i++) {
            address u = address(uint160(0x20000 + i));
            usdt.mint(u, 5 * 10 ** 6);
            vm.prank(u);
            usdt.approve(address(minter), type(uint256).max);
            vm.prank(u);
            minter.mint(2, _sign(u, 2));
        }

        assertEq(minter.phase2Minted(), 500);

        address extra = address(0xBEAD);
        usdt.mint(extra, 5 * 10 ** 6);
        vm.prank(extra);
        usdt.approve(address(minter), type(uint256).max);
        vm.prank(extra);
        vm.expectRevert(BlockPassMinter.PhaseSupplyReached.selector);
        minter.mint(2, _sign(extra, 2));
    }

    // ─── Helpers ─────────────────────────────────────
    function _fillPhase1() internal {
        minter.setPhase(BlockPassMinter.Phase.PHASE1);
        for (uint256 i = 1; i <= 1500; i++) {
            address u = address(uint160(0x50000 + i));
            usdt.mint(u, 5 * 10 ** 6);
            vm.prank(u);
            usdt.approve(address(minter), type(uint256).max);
            vm.prank(u);
            minter.mint(1, _sign(u, 1));
        }
    }

    // ─── Admin ────────────────────────────────────────
    function test_setPhase() public {
        minter.setPhase(BlockPassMinter.Phase.PHASE1);
        assertEq(uint8(minter.phase()), 1);

        _fillPhase1();
        minter.setPhase(BlockPassMinter.Phase.PHASE2);
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
