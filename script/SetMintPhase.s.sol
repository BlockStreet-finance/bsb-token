// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import "../src/BlockPassMinter.sol";

/**
 * @title Set BlockPassMinter Phase
 * @dev Change the minting phase (0=PAUSED, 1=PHASE1, 2=PHASE2).
 *
 * Usage:
 *   forge script script/SetMintPhase.s.sol \
 *     --sig "run(address,uint8)" <MINTER_ADDRESS> <PHASE> \
 *     --rpc-url $RPC_URL --broadcast --account iost
 *
 * Examples:
 *   # Start Phase 1
 *   forge script script/SetMintPhase.s.sol \
 *     --sig "run(address,uint8)" 0x... 1 \
 *     --rpc-url $RPC_URL --broadcast --account iost
 *
 *   # Pause minting
 *   forge script script/SetMintPhase.s.sol \
 *     --sig "run(address,uint8)" 0x... 0 \
 *     --rpc-url $RPC_URL --broadcast --account iost
 */
contract SetMintPhase is Script {
    function run(address minterAddr, uint8 _phase) external {
        BlockPassMinter minter = BlockPassMinter(minterAddr);

        string[3] memory phaseNames = ["PAUSED", "PHASE1", "PHASE2"];

        console.log("BlockPassMinter:", minterAddr);
        console.log("Current phase:", phaseNames[uint8(minter.phase())]);
        console.log("Setting phase:", phaseNames[_phase]);

        vm.startBroadcast();
        minter.setPhase(BlockPassMinter.Phase(_phase));
        vm.stopBroadcast();

        console.log("Phase set to:", phaseNames[_phase]);
    }
}
