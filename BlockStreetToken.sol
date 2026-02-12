// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title Block Street Token
 * @dev ERC20 token with fixed supply of 1 billion tokens
 */
contract BlockStreetToken is ERC20 {
    uint256 public constant TOTAL_SUPPLY = 1_000_000_000 * 10**18; // 1 billion tokens with 18 decimals

    /**
     * @dev Constructor that mints the entire supply to the deployer
     */
    constructor() ERC20("Block Street", "BSB") {
        _mint(msg.sender, TOTAL_SUPPLY);
    }
}