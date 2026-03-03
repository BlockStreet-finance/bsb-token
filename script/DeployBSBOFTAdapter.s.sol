// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/BSBOFTAdapter.sol";

/**
 * @dev Deploy BSBOFTAdapter on ETH Mainnet (lock/unlock adapter for existing BSB token).
 *
 * Usage:
 *   forge script script/DeployBSBOFTAdapter.s.sol \
 *     --sig "run(address)" <BSB_TOKEN> \
 *     --broadcast --rpc-url $RPC_URL --account iost
 *
 * BSB Token (ETH Mainnet): 0xDB6Ba5D510F114F9b2eA08BEa7d30e32eEe33411
 * LZ EndpointV2 (ETH Mainnet): 0x1a44076050125825900e736c501f859c50fE728c
 * LZ EndpointV2 (Sepolia): 0x6EDCE65403992e310A62460808c4b910D972f10f
 */
contract DeployBSBOFTAdapter is Script {
    // Mainnet EndpointV2 — change to testnet endpoint for Sepolia
    address constant LZ_ENDPOINT = 0x1a44076050125825900e736c501f859c50fE728c;

    function run(address bsbToken) external {
        console.log("Deploying BSBOFTAdapter...");
        console.log("  BSB Token:", bsbToken);
        console.log("  LZ Endpoint:", LZ_ENDPOINT);
        console.log("  Owner/Delegate:", msg.sender);

        vm.startBroadcast();

        BSBOFTAdapter adapter = new BSBOFTAdapter(
            bsbToken,
            LZ_ENDPOINT,
            msg.sender
        );

        vm.stopBroadcast();

        console.log("BSBOFTAdapter deployed at:", address(adapter));
        console.log("");
        console.log("Next steps:");
        console.log("  1. Deploy BSBOFT on Mantle");
        console.log("  2. adapter.setPeer(30181, bytes32(uint256(uint160(mantleOFTAddress))))");
    }
}
