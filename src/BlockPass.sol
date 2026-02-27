// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title Block Pass
 * @dev Non-transferable ERC721 (Soulbound).
 *      - Fixed supply: 2000
 *      - Only authorized minter contract can mint
 *      - No transfers allowed after minting
 */
contract BlockPass is ERC721, Ownable {
    uint256 public constant MAX_SUPPLY = 2000;

    address public minter;        // authorized minter contract
    string  public baseTokenURI;
    uint256 public totalSupply;

    error Soulbound();
    error ZeroAddress();
    error NotMinter();
    error MaxSupplyReached();

    event MinterChanged(address newMinter);
    event BaseURIChanged(string newBaseURI);

    modifier onlyMinter() {
        if (msg.sender != minter) revert NotMinter();
        _;
    }

    constructor(
        string memory _baseTokenURI
    ) ERC721("Block Pass", "BSP") Ownable(msg.sender) {
        baseTokenURI = _baseTokenURI;
    }

    /// @notice Called by the minter contract to mint a token.
    /// @return tokenId The newly minted token ID.
    function mint(address to) external onlyMinter returns (uint256) {
        if (totalSupply >= MAX_SUPPLY) revert MaxSupplyReached();
        uint256 tokenId = totalSupply + 1;
        totalSupply++;
        _safeMint(to, tokenId);
        return tokenId;
    }

    // ──────────────────── Soulbound ───────────────────
    function _update(
        address to,
        uint256 tokenId,
        address auth
    ) internal override returns (address) {
        address from = _ownerOf(tokenId);
        if (from != address(0)) revert Soulbound();
        return super._update(to, tokenId, auth);
    }

    // ──────────────────── Metadata ────────────────────
    function _baseURI() internal view override returns (string memory) {
        return baseTokenURI;
    }

    // ──────────────────── Admin ───────────────────────
    function setMinter(address _minter) external onlyOwner {
        if (_minter == address(0)) revert ZeroAddress();
        minter = _minter;
        emit MinterChanged(_minter);
    }

    function setBaseURI(string calldata _baseTokenURI) external onlyOwner {
        baseTokenURI = _baseTokenURI;
        emit BaseURIChanged(_baseTokenURI);
    }

    function remaining() external view returns (uint256) {
        return MAX_SUPPLY - totalSupply;
    }
}
