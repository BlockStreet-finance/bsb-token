// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import "../src/BlockPass.sol";
import "../src/BlockPassMinter.sol";

/**
 * @title Deploy new Minter for existing BlockPass NFT
 * @dev Deploys BlockPassMinter and sets it as the minter on an existing NFT.
 *
 * Usage:
 *   forge script script/DeployMinterForExistingNFT.s.sol \
 *     --sig "run(address,address,address)" <NFT_ADDRESS> <SIGNER> <TREASURY> \
 *     --rpc-url $RPC_URL --broadcast --account iost \
 *     --sender <YOUR_ADDRESS>
 */
contract DeployMinterForExistingNFT is Script {
    function run(address nftAddr, address signerAddr, address treasuryAddr) external {
        BlockPass nft = BlockPass(nftAddr);

        console.log("=== Deploy Minter for Existing NFT ===");
        console.log("NFT:", nftAddr);
        console.log("Signer:", signerAddr);
        console.log("Treasury:", treasuryAddr);
        console.log("Current minter:", nft.minter());

        vm.startBroadcast();

        BlockPassMinter minter = new BlockPassMinter(
            nftAddr,
            signerAddr,
            treasuryAddr
        );

        nft.setMinter(address(minter));

        vm.stopBroadcast();

        console.log("=== Done ===");
        console.log("BlockPassMinter:", address(minter));
        console.log("NFT minter updated to:", nft.minter());
    }
}
