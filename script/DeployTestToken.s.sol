// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import "../src/BlockStreetToken.sol";

/**
 * @title Deploy Test BSB Token
 * @dev Deploys BlockStreetToken for testing. All 1B tokens go to deployer.
 *
 * Usage:
 *   forge script script/DeployTestToken.s.sol \
 *     --rpc-url $RPC_URL --broadcast --account iost
 */
contract DeployTestToken is Script {
    function run() external {
        vm.startBroadcast();
        BlockStreetToken token = new BlockStreetToken();
        vm.stopBroadcast();

        console.log("BSB Token deployed at:", address(token));
        console.log("Total supply:", token.totalSupply());
    }
}
