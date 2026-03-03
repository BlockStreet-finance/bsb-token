// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "../src/Airdrop_BSB.sol";
import "../src/BlockStreetToken.sol";

contract Airdrop_BSBTest is Test {
    BlockStreetToken public bsb;
    Airdrop_BSB public airdrop;

    uint256 public signerKey = 0xA11CE;
    address public signerAddr;
    address public owner = address(this);
    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);

    uint256 public constant DEFAULT_DEADLINE = 3 minutes;

    function setUp() public {
        signerAddr = vm.addr(signerKey);
        bsb = new BlockStreetToken();
        airdrop = new Airdrop_BSB(IERC20(address(bsb)), signerAddr, owner);

        // Fund airdrop contract
        bsb.transfer(address(airdrop), 1_000_000 ether);
    }

    // ─── Helpers ──────────────────────────────────────

    function _deadline() internal view returns (uint256) {
        return block.timestamp + DEFAULT_DEADLINE;
    }

    function _sign(address user, uint256 amount, uint256 deadline) internal view returns (bytes memory) {
        bytes32 msgHash = keccak256(
            abi.encodePacked(user, amount, deadline, block.chainid, address(airdrop))
        );
        bytes32 ethHash = MessageHashUtils.toEthSignedMessageHash(msgHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerKey, ethHash);
        return abi.encodePacked(r, s, v);
    }

    function _sign(address user, uint256 amount) internal view returns (bytes memory) {
        return _sign(user, amount, _deadline());
    }

    // ─── Constructor ─────────────────────────────────

    function test_constructor() public view {
        assertEq(address(airdrop.token()), address(bsb));
        assertEq(airdrop.signer(), signerAddr);
        assertEq(airdrop.owner(), owner);
        assertEq(airdrop.totalClaimed(), 0);
    }

    function test_constructor_revert_zero_token() public {
        vm.expectRevert(Airdrop_BSB.InvalidParams.selector);
        new Airdrop_BSB(IERC20(address(0)), signerAddr, owner);
    }

    function test_constructor_revert_zero_signer() public {
        vm.expectRevert(Airdrop_BSB.InvalidParams.selector);
        new Airdrop_BSB(IERC20(address(bsb)), address(0), owner);
    }

    // ─── Claim ───────────────────────────────────────

    function test_claim() public {
        uint256 amount = 1000 ether;

        vm.prank(alice);
        airdrop.claim(amount, _deadline(), _sign(alice, amount));

        assertEq(bsb.balanceOf(alice), amount);
        assertTrue(airdrop.hasClaimed(alice));
        assertEq(airdrop.claimedAmount(alice), amount);
        assertEq(airdrop.totalClaimed(), amount);
    }

    function test_claim_multiple_users() public {
        uint256 amountAlice = 1000 ether;
        uint256 amountBob = 2000 ether;

        vm.prank(alice);
        airdrop.claim(amountAlice, _deadline(), _sign(alice, amountAlice));

        vm.prank(bob);
        airdrop.claim(amountBob, _deadline(), _sign(bob, amountBob));

        assertEq(bsb.balanceOf(alice), amountAlice);
        assertEq(bsb.balanceOf(bob), amountBob);
        assertEq(airdrop.totalClaimed(), amountAlice + amountBob);
    }

    function test_claim_revert_already_claimed() public {
        uint256 amount = 1000 ether;

        vm.prank(alice);
        airdrop.claim(amount, _deadline(), _sign(alice, amount));

        vm.prank(alice);
        vm.expectRevert(Airdrop_BSB.AlreadyClaimed.selector);
        airdrop.claim(amount, _deadline(), _sign(alice, amount));
    }

    function test_claim_revert_expired() public {
        uint256 amount = 1000 ether;
        uint256 deadline = block.timestamp + 3 minutes;
        bytes memory sig = _sign(alice, amount, deadline);

        vm.warp(deadline + 1);
        vm.prank(alice);
        vm.expectRevert(Airdrop_BSB.SignatureExpired.selector);
        airdrop.claim(amount, deadline, sig);
    }

    function test_claim_revert_zero_amount() public {
        vm.prank(alice);
        vm.expectRevert(Airdrop_BSB.InvalidParams.selector);
        airdrop.claim(0, _deadline(), _sign(alice, 0));
    }

    function test_claim_revert_invalid_sig() public {
        uint256 amount = 1000 ether;
        bytes memory sig = _sign(alice, amount);

        vm.prank(bob); // wrong sender
        vm.expectRevert(Airdrop_BSB.InvalidSignature.selector);
        airdrop.claim(amount, _deadline(), sig);
    }

    function test_claim_revert_wrong_amount() public {
        uint256 amount = 1000 ether;
        bytes memory sig = _sign(alice, amount);

        vm.prank(alice);
        vm.expectRevert(Airdrop_BSB.InvalidSignature.selector);
        airdrop.claim(2000 ether, _deadline(), sig); // different amount
    }

    function test_claim_revert_insufficient_balance() public {
        // Deploy with no funds
        Airdrop_BSB empty = new Airdrop_BSB(IERC20(address(bsb)), signerAddr, owner);

        uint256 amount = 1000 ether;
        uint256 deadline = _deadline();
        bytes32 msgHash = keccak256(
            abi.encodePacked(alice, amount, deadline, block.chainid, address(empty))
        );
        bytes32 ethHash = MessageHashUtils.toEthSignedMessageHash(msgHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerKey, ethHash);
        bytes memory sig = abi.encodePacked(r, s, v);

        vm.prank(alice);
        vm.expectRevert(Airdrop_BSB.InsufficientBalance.selector);
        empty.claim(amount, deadline, sig);
    }

    function test_claim_revert_ended() public {
        airdrop.endAirdrop();

        uint256 amount = 1000 ether;
        vm.prank(alice);
        vm.expectRevert(Airdrop_BSB.AirdropNotActive.selector);
        airdrop.claim(amount, _deadline(), _sign(alice, amount));
    }

    // ─── Admin ───────────────────────────────────────

    function test_endAirdrop() public {
        assertFalse(airdrop.isEnded());
        airdrop.endAirdrop();
        assertTrue(airdrop.isEnded());
    }

    function test_endAirdrop_revert_not_owner() public {
        vm.prank(alice);
        vm.expectRevert();
        airdrop.endAirdrop();
    }

    function test_setSigner() public {
        address newSigner = address(0xCAFE);
        airdrop.setSigner(newSigner);
        assertEq(airdrop.signer(), newSigner);
    }

    function test_setSigner_revert_zero() public {
        vm.expectRevert(Airdrop_BSB.InvalidParams.selector);
        airdrop.setSigner(address(0));
    }

    function test_setSigner_revert_not_owner() public {
        vm.prank(alice);
        vm.expectRevert();
        airdrop.setSigner(alice);
    }

    function test_withdrawRemaining() public {
        address treasury = address(0xDEAD);
        uint256 balance = bsb.balanceOf(address(airdrop));

        airdrop.withdrawRemaining(treasury);
        assertEq(bsb.balanceOf(treasury), balance);
        assertEq(bsb.balanceOf(address(airdrop)), 0);
    }

    function test_withdrawRemaining_revert_zero() public {
        vm.expectRevert(Airdrop_BSB.InvalidParams.selector);
        airdrop.withdrawRemaining(address(0));
    }

    function test_withdrawRemaining_revert_not_owner() public {
        vm.prank(alice);
        vm.expectRevert();
        airdrop.withdrawRemaining(alice);
    }
}
