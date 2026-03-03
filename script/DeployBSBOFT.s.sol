// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/BSBOFT.sol";

/**
 * @dev Deploy BSBOFT on Mantle (mint/burn OFT for bridged BSB tokens).
 *
 * Usage:
 *   forge script script/DeployBSBOFT.s.sol \
 *     --broadcast --rpc-url $MANTLE_RPC_URL --account iost
 *
 * LZ EndpointV2 (Mantle): 0x1a44076050125825900e736c501f859c50fE728c
 * LZ EndpointV2 (Mantle Sepolia): 0x6EDCE65403992e310A62460808c4b910D972f10f
 */
contract DeployBSBOFT is Script {
    // Mantle EndpointV2 — change to testnet endpoint for Mantle Sepolia
    address constant LZ_ENDPOINT = 0x1a44076050125825900e736c501f859c50fE728c;

    function run() external {
        console.log("Deploying BSBOFT...");
        console.log("  LZ Endpoint:", LZ_ENDPOINT);
        console.log("  Owner/Delegate:", msg.sender);

        vm.startBroadcast();

        BSBOFT oft = new BSBOFT(LZ_ENDPOINT, msg.sender);

        vm.stopBroadcast();

        console.log("BSBOFT deployed at:", address(oft));
        console.log("");
        console.log("Next steps:");
        console.log("  1. oft.setPeer(30101, bytes32(uint256(uint160(ethAdapterAddress))))");
        console.log("  2. On ETH: adapter.setPeer(30181, bytes32(uint256(uint160(address(oft)))))");
    }
}
