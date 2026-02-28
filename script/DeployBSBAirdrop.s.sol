// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import "../src/BSBAirdrop.sol";

/**
 * @dev Deploy BSBAirdrop contract.
 *
 * Usage:
 *   forge script script/DeployBSBAirdrop.s.sol \
 *     --sig "run(address,address)" <BSB_TOKEN> <BLOCK_PASS_NFT> \
 *     --broadcast --rpc-url $RPC_URL --account iost
 */
contract DeployBSBAirdrop is Script {
    // ──────────── Airdrop Parameters (edit before deploy) ────────────
    uint256 constant AMOUNT_PER_NFT   = 10_000 * 10**18;  // 10,000 BSB per NFT
    uint256 constant INITIAL_RELEASE  = 1_250 * 10**18;    // 1,250 BSB immediately (12.5%)
    uint256 constant CLIFF_DURATION   = 12 * 30 days;          // 12 months
    uint256 constant VESTING_PERIODS  = 24;                // 12 months after cliff
    // ─────────────────────────────────────────────────────────────────

    function run(address tokenAddr, address nftAddr) external {

        console.log("Deploying BSBAirdrop...");
        console.log("  Token:", tokenAddr);
        console.log("  BlockPass:", nftAddr);
        console.log("  Amount per NFT:", AMOUNT_PER_NFT);
        console.log("  Initial release:", INITIAL_RELEASE);
        console.log("  Cliff duration:", CLIFF_DURATION);
        console.log("  Vesting periods:", VESTING_PERIODS);

        vm.startBroadcast();

        BSBAirdrop airdrop = new BSBAirdrop(
            IERC20(tokenAddr),
            IERC721(nftAddr),
            AMOUNT_PER_NFT,
            INITIAL_RELEASE,
            CLIFF_DURATION,
            VESTING_PERIODS,
            msg.sender
        );

        vm.stopBroadcast();

        console.log("BSBAirdrop deployed at:", address(airdrop));
        console.log("  Locked amount per NFT:", airdrop.lockedAmount());

        console.log("BSB_AIRDROP_ADDRESS=", address(airdrop));
    }
}
