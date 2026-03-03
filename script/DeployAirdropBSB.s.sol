// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import "../src/Airdrop_BSB.sol";

/**
 * @title Deploy Airdrop_BSB
 * @dev Deploys signature-based airdrop contract.
 *
 * Usage:
 *   forge script script/DeployAirdropBSB.s.sol \
 *     --sig "run(address,address)" <BSB_TOKEN> <SIGNER> \
 *     --rpc-url $RPC_URL --broadcast --account iost \
 *     --sender <YOUR_ADDRESS>
 */
contract DeployAirdropBSB is Script {
    function run(address tokenAddr, address signerAddr) external {
        console.log("=== Deploying Airdrop_BSB ===");
        console.log("Token:", tokenAddr);
        console.log("Signer:", signerAddr);

        vm.startBroadcast();

        Airdrop_BSB airdrop = new Airdrop_BSB(
            IERC20(tokenAddr),
            signerAddr,
            msg.sender
        );

        vm.stopBroadcast();

        console.log("=== Done ===");
        console.log("Airdrop_BSB:", address(airdrop));
        console.log("Owner:", airdrop.owner());
    }
}
