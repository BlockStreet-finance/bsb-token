// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import "../src/BlockPass.sol";
import "../src/BlockPassMinter.sol";

/**
 * @title Deploy BlockPass + BlockPassMinter
 * @dev Deploys both contracts and wires them together.
 *
 * Usage:
 *   forge script script/DeployBlockPass.s.sol \
 *     --sig "run(address,address,address)" <SIGNER> <USDT> <TREASURY> \
 *     --rpc-url $RPC_URL --broadcast --account iost
 */
contract DeployBlockPass is Script {
    string constant BASE_TOKEN_URI = "ipfs://QmYzbqtzvufCqBneBbAt1b5r9h4qeuy8R8cSEtoJ2X4HY2/";

    function run(address signerAddr, address usdtAddr, address treasuryAddr) external {
        string memory baseURI = BASE_TOKEN_URI;

        console.log("=== Deploying BlockPass + Minter ===");
        console.log("Signer:", signerAddr);
        console.log("USDT:", usdtAddr);
        console.log("Treasury:", treasuryAddr);
        console.log("BaseURI:", baseURI);
        console.log("");

        vm.startBroadcast();

        // 1. Deploy NFT
        BlockPass nft = new BlockPass(baseURI);

        // 2. Deploy Minter
        BlockPassMinter minter = new BlockPassMinter(
            address(nft),
            signerAddr,
            usdtAddr,
            treasuryAddr
        );

        // 3. Authorize minter on NFT
        nft.setMinter(address(minter));

        vm.stopBroadcast();

        console.log("=== Deployment Successful ===");
        console.log("BlockPass NFT:", address(nft));
        console.log("BlockPassMinter:", address(minter));
        console.log("Phase: PAUSED (call minter.setPhase to start)");
        console.log("");

    }
}
