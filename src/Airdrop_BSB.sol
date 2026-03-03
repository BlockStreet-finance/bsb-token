// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title Airdrop BSB
 * @dev Signature-based airdrop contract.
 *      - Backend determines user eligibility and signs (user, amount, deadline, chainid, contract)
 *      - User calls claim with the signature to receive BSB tokens
 *      - Each user can only claim once
 */
contract Airdrop_BSB is Ownable, ReentrancyGuard {
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    IERC20 public immutable token;
    address public signer;
    bool public isEnded;

    mapping(address => bool) public hasClaimed;
    mapping(address => uint256) public claimedAmount;
    uint256 public totalClaimed;

    // Events
    event Claimed(address indexed user, uint256 amount);
    event AirdropEnded();
    event SignerChanged(address newSigner);
    event Withdrawn(address indexed to, uint256 amount);

    // Errors
    error AlreadyClaimed();
    error AirdropNotActive();
    error InvalidSignature();
    error SignatureExpired();
    error InvalidParams();
    error InsufficientBalance();

    constructor(
        IERC20 _token,
        address _signer,
        address _owner
    ) Ownable(_owner) {
        if (address(_token) == address(0) || _signer == address(0)) revert InvalidParams();
        token = _token;
        signer = _signer;
    }

    /**
     * @notice Claim airdrop tokens.
     * @param _amount   Amount of tokens to claim.
     * @param _deadline Signature expiration timestamp.
     * @param _sig      ECDSA signature from the authorized signer.
     *
     * @dev Signature: keccak256(abi.encodePacked(user, amount, deadline, chainid, address(this)))
     */
    function claim(uint256 _amount, uint256 _deadline, bytes calldata _sig) external nonReentrant {
        if (isEnded) revert AirdropNotActive();
        if (hasClaimed[msg.sender]) revert AlreadyClaimed();
        if (block.timestamp > _deadline) revert SignatureExpired();
        if (_amount == 0) revert InvalidParams();

        // Verify server signature
        bytes32 msgHash = keccak256(
            abi.encodePacked(msg.sender, _amount, _deadline, block.chainid, address(this))
        );
        bytes32 ethSignedHash = msgHash.toEthSignedMessageHash();
        if (ethSignedHash.recover(_sig) != signer) revert InvalidSignature();

        if (token.balanceOf(address(this)) < _amount) revert InsufficientBalance();

        hasClaimed[msg.sender] = true;
        claimedAmount[msg.sender] = _amount;
        totalClaimed += _amount;

        require(token.transfer(msg.sender, _amount), "Transfer failed");
        emit Claimed(msg.sender, _amount);
    }

    // ──────────────────── Admin ───────────────────────

    function endAirdrop() external onlyOwner {
        isEnded = true;
        emit AirdropEnded();
    }

    function setSigner(address _signer) external onlyOwner {
        if (_signer == address(0)) revert InvalidParams();
        signer = _signer;
        emit SignerChanged(_signer);
    }

    function withdrawRemaining(address to) external onlyOwner {
        if (to == address(0)) revert InvalidParams();
        uint256 balance = token.balanceOf(address(this));
        require(token.transfer(to, balance), "Transfer failed");
        emit Withdrawn(to, balance);
    }
}
