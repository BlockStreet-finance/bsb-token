// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./BlockPass.sol";

/**
 * @title BlockPass Minter
 * @dev Handles mint logic: signature verification, USDT payment, phase control.
 *      Calls BlockPass.mint() to issue tokens.
 */
contract BlockPassMinter is Ownable, ReentrancyGuard {
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;
    using SafeERC20 for IERC20;

    // ──────────────────── Constants ────────────────────
    uint256 public constant MINT_PRICE = 5 * 10 ** 6; // 5 USDT (6 decimals)
    uint256 public constant PHASE1_SUPPLY = 1500;
    uint256 public constant PHASE2_SUPPLY = 500;

    // ──────────────────── Enums ────────────────────────
    enum Phase { PAUSED, PHASE1, PHASE2 }

    // ──────────────────── State ────────────────────────
    BlockPass public immutable nft;
    IERC20    public immutable usdt;
    address   public signer;     // server-side signing wallet
    address   public treasury;   // receives mint payments
    Phase     public phase;
    uint256   public phase1Minted;
    uint256   public phase2Minted;

    mapping(address => bool) public hasMinted;

    // ──────────────────── Errors ───────────────────────
    error MintPaused();
    error AlreadyMinted();
    error InvalidSignature();
    error ZeroAddress();
    error WrongPhase();
    error PhaseSupplyReached();
    error Phase1NotComplete();

    // ──────────────────── Events ───────────────────────
    event PhaseChanged(Phase newPhase);
    event SignerChanged(address newSigner);
    event TreasuryChanged(address newTreasury);
    event Minted(address indexed to, uint256 tokenId);

    // ──────────────────── Constructor ──────────────────
    constructor(
        address _nft,
        address _signer,
        address _usdt,
        address _treasury
    ) Ownable(msg.sender) {
        if (_nft == address(0) || _signer == address(0) || _usdt == address(0) || _treasury == address(0))
            revert ZeroAddress();
        nft = BlockPass(_nft);
        signer = _signer;
        usdt = IERC20(_usdt);
        treasury = _treasury;
        phase = Phase.PAUSED;
    }

    // ──────────────────── Mint ─────────────────────────

    /**
     * @notice Mint a Block Pass. Costs 5 USDT.
     * @param _phase  Phase this signature was issued for (1=PHASE1, 2=PHASE2).
     * @param _sig    ECDSA signature from the authorized signer.
     *
     * @dev User must approve this contract for MINT_PRICE of USDT before calling.
     *      Signature: keccak256(abi.encodePacked(minter, _phase, chainid, address(this)))
     */
    function mint(uint8 _phase, bytes calldata _sig) external nonReentrant {
        if (phase == Phase.PAUSED) revert MintPaused();
        if (uint8(phase) != _phase) revert WrongPhase();
        if (hasMinted[msg.sender]) revert AlreadyMinted();

        // Check per-phase supply cap
        if (phase == Phase.PHASE1) {
            if (phase1Minted >= PHASE1_SUPPLY) revert PhaseSupplyReached();
        } else {
            if (phase2Minted >= PHASE2_SUPPLY) revert PhaseSupplyReached();
        }

        // Verify server signature
        bytes32 msgHash = keccak256(
            abi.encodePacked(msg.sender, _phase, block.chainid, address(this))
        );
        bytes32 ethSignedHash = msgHash.toEthSignedMessageHash();
        if (ethSignedHash.recover(_sig) != signer) revert InvalidSignature();

        // Effects: update state before external calls (CEI pattern)
        hasMinted[msg.sender] = true;
        if (phase == Phase.PHASE1) {
            phase1Minted++;
        } else {
            phase2Minted++;
        }

        // Interactions: external calls last
        usdt.safeTransferFrom(msg.sender, treasury, MINT_PRICE);
        uint256 tokenId = nft.mint(msg.sender);

        emit Minted(msg.sender, tokenId);
    }

    // ──────────────────── Admin ───────────────────────
    function setPhase(Phase _phase) external onlyOwner {
        if (_phase == Phase.PHASE2 && phase1Minted < PHASE1_SUPPLY) revert Phase1NotComplete();
        phase = _phase;
        emit PhaseChanged(_phase);
    }

    function setSigner(address _signer) external onlyOwner {
        if (_signer == address(0)) revert ZeroAddress();
        signer = _signer;
        emit SignerChanged(_signer);
    }

    function setTreasury(address _treasury) external onlyOwner {
        if (_treasury == address(0)) revert ZeroAddress();
        treasury = _treasury;
        emit TreasuryChanged(_treasury);
    }
}
