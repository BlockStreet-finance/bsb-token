// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import "../src/BlockPass.sol";

/**
 * @title Deploy Test NFT
 * @dev Deploys BlockPass with IPFS metadata and mints 3 NFTs to deployer for testing.
 *
 * Usage:
 *   forge script script/DeployTestNFT.s.sol \
 *     --rpc-url $RPC_URL --broadcast --account iost \
 *     --sender <YOUR_ADDRESS>
 */
contract DeployTestNFT is Script {
    string constant BASE_TOKEN_URI = "ipfs://QmYzbqtzvufCqBneBbAt1b5r9h4qeuy8R8cSEtoJ2X4HY2/";

    function run() external {
        vm.startBroadcast();

        BlockPass nft = new BlockPass(BASE_TOKEN_URI);

        // Set deployer as minter and mint 3 NFTs
        nft.setMinter(msg.sender);
        nft.mint(msg.sender); // tokenId 1
        nft.mint(msg.sender); // tokenId 2
        nft.mint(msg.sender); // tokenId 3

        vm.stopBroadcast();

        console.log("BlockPass NFT deployed at:", address(nft));
        console.log("tokenURI(1):", nft.tokenURI(1));
        console.log("tokenURI(2):", nft.tokenURI(2));
        console.log("tokenURI(3):", nft.tokenURI(3));
    }
}
