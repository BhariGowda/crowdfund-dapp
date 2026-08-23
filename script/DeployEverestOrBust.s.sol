// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {EverestOrBust} from "../src/EverestOrBust.sol";

/// @title DeployEverestOrBust
/// @notice Deploys the EverestOrBust fundraise campaign to Avalanche C-Chain.
/// @dev    Campaign parameters:
///         - Goal:     $69,000 (69_000e18 normalized)
///         - Duration: 69 days (Dec 10 2026 - Feb 17 2027)
///         - Tokens:   USDC, USDT (Avalanche C-Chain)
///         - Cap:      $6.9 per address
///
///         Fuji Testnet:
///           forge script script/DeployEverestOrBust.s.sol \
///             --rpc-url fuji --broadcast --verify
///
///         Avalanche Mainnet:
///           forge script script/DeployEverestOrBust.s.sol \
///             --rpc-url avalanche --broadcast --verify
///
///         Required env vars:
///           PRIVATE_KEY, SNOWTRACE_API_KEY
///           USDC_ADDRESS, USDT_ADDRESS
contract DeployEverestOrBust is Script {
    /// @dev Dec 10 2026 00:00:00 UTC
    uint256 constant START = 1765324800;

    function run() external returns (EverestOrBust campaign) {
        address usdc = vm.envAddress("USDC_ADDRESS");
        address usdt = vm.envAddress("USDT_ADDRESS");

        vm.startBroadcast();

        campaign = new EverestOrBust(msg.sender, usdc, usdt, START);

        console2.log("EverestOrBust deployed at:", address(campaign));
        console2.log("Creator:  ", msg.sender);
        console2.log("USDC:     ", usdc);
        console2.log("USDT:     ", usdt);
        console2.log("Start:    ", START);
        console2.log("Deadline: ", START + 69 days);
        console2.log("Goal:     $69,000");
        console2.log("Cap:      $6.9 per address");

        vm.stopBroadcast();
    }
}
