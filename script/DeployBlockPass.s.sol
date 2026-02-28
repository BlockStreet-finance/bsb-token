// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import "../src/BlockPass.sol";
import "../src/BlockPassMinter.sol";

/**
 * @title Deploy BlockPass + BlockPassMinter
 * @dev Deploys both contracts and wires them together.
 *
 *   1. Set .env file:
 *      PASS_SIGNER=0x...        (server signing wallet address)
 *      USDT_ADDRESS=0x...       (USDT contract address)
 *      TREASURY_ADDRESS=0x...   (receives mint payments)
 *
 *   2. Run:
 *      forge script script/DeployBlockPass.s.sol --rpc-url $RPC_URL --broadcast --account iost
 */
contract DeployBlockPass is Script {
    string constant BASE_TOKEN_URI = "ipfs://QmYzbqtzvufCqBneBbAt1b5r9h4qeuy8R8cSEtoJ2X4HY2/";

    function run() external {
        address signerAddr = vm.envAddress("PASS_SIGNER");
        address usdtAddr = vm.envAddress("USDT_ADDRESS");
        address treasuryAddr = vm.envAddress("TREASURY_ADDRESS");
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

        string memory info = string.concat(
            "BLOCK_PASS_NFT=", vm.toString(address(nft)), "\n",
            "BLOCK_PASS_MINTER=", vm.toString(address(minter)), "\n",
            "SIGNER=", vm.toString(signerAddr), "\n",
            "USDT=", vm.toString(usdtAddr), "\n",
            "TREASURY=", vm.toString(treasuryAddr), "\n"
        );

        vm.writeFile("deployments/block-pass.env", info);
        console.log("Saved to: deployments/block-pass.env");
    }
}
