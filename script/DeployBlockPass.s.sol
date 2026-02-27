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
 *      PRIVATE_KEY=your_private_key
 *      RPC_URL=your_rpc_url
 *      PASS_SIGNER=0x...        (server signing wallet address)
 *      USDT_ADDRESS=0x...       (USDT contract address)
 *      TREASURY_ADDRESS=0x...   (receives mint payments)
 *      BASE_TOKEN_URI=https://... (metadata base URI)
 *
 *   2. Run:
 *      forge script script/DeployBlockPass.s.sol --rpc-url $RPC_URL --broadcast
 */
contract DeployBlockPass is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        address signerAddr = vm.envAddress("PASS_SIGNER");
        address usdtAddr = vm.envAddress("USDT_ADDRESS");
        address treasuryAddr = vm.envAddress("TREASURY_ADDRESS");
        string memory baseURI = vm.envString("BASE_TOKEN_URI");

        console.log("=== Deploying BlockPass + Minter ===");
        console.log("Deployer:", deployer);
        console.log("Signer:", signerAddr);
        console.log("USDT:", usdtAddr);
        console.log("Treasury:", treasuryAddr);
        console.log("BaseURI:", baseURI);
        console.log("");

        vm.startBroadcast(deployerPrivateKey);

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
        console.log("Owner:", deployer);
        console.log("Phase: PAUSED (call minter.setPhase to start)");
        console.log("");

        string memory info = string.concat(
            "BLOCK_PASS_NFT=", vm.toString(address(nft)), "\n",
            "BLOCK_PASS_MINTER=", vm.toString(address(minter)), "\n",
            "OWNER=", vm.toString(deployer), "\n",
            "SIGNER=", vm.toString(signerAddr), "\n",
            "USDT=", vm.toString(usdtAddr), "\n",
            "TREASURY=", vm.toString(treasuryAddr), "\n"
        );

        vm.writeFile("deployments/block-pass.env", info);
        console.log("Saved to: deployments/block-pass.env");
    }
}
