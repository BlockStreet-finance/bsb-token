// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { OFT } from "@layerzerolabs/oft-evm/contracts/OFT.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

/// @title BSBOFT
/// @notice OFT representation of BSB token on remote chains (e.g. Mantle).
///         Mints on receive, burns on send.
contract BSBOFT is OFT {
    constructor(
        address _lzEndpoint,
        address _delegate
    ) OFT("Block Street", "BSB", _lzEndpoint, _delegate) Ownable(_delegate) {}
}
