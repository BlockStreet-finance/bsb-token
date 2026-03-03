// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { OFTAdapter } from "@layerzerolabs/oft-evm/contracts/OFTAdapter.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

/// @title BSBOFTAdapter
/// @notice OFT Adapter for the existing BSB token on ETH Mainnet.
///         Locks tokens on send, unlocks on receive.
///         Only ONE adapter should exist per token across all chains.
contract BSBOFTAdapter is OFTAdapter {
    constructor(
        address _token,
        address _lzEndpoint,
        address _delegate
    ) OFTAdapter(_token, _lzEndpoint, _delegate) Ownable(_delegate) {}
}
