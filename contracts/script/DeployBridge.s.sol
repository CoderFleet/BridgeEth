// script/DeployBridge.s.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/DummyToken.sol";
import "../src/BridgedDummyToken.sol";
import "../src/Bridge.sol";

contract DeployBridge is Script {
    // Chain IDs
    uint256 constant SEPOLIA_CHAIN_ID = 11155111;
    uint256 constant MUMBAI_CHAIN_ID = 80001;

    // Token configurations
    string constant DUMMY_TOKEN_NAME = "DummyToken";
    string constant DUMMY_TOKEN_SYMBOL = "DUMMY";
    uint256 constant INITIAL_SUPPLY = 1_000_000; // 1M tokens

    string constant BRIDGED_TOKEN_NAME = "Bridged DummyToken";
    string constant BRIDGED_TOKEN_SYMBOL = "bDUMMY";

    function run() external {
        uint256 chainId = block.chainid;
        
        if (chainId == SEPOLIA_CHAIN_ID) {
            deployOnSepolia();
        } else if (chainId == MUMBAI_CHAIN_ID) {
            deployOnMumbai();
        } else {
            revert("Unsupported chain ID");
        }
    }

    function deployOnSepolia() internal {
        vm.startBroadcast();

        console.log("Deploying on Sepolia (Chain ID: %s)", SEPOLIA_CHAIN_ID);
        console.log("Deployer: %s", msg.sender);

        // Deploy DummyToken
        DummyToken dummyToken = new DummyToken(
            DUMMY_TOKEN_NAME,
            DUMMY_TOKEN_SYMBOL,
            INITIAL_SUPPLY
        );
        console.log("DummyToken deployed at: %s", address(dummyToken));

        // For now, deploy bridge with placeholder address
        // This will need to be updated after Mumbai deployment
        address mumbaiTokenPlaceholder = address(0);
        
        Bridge bridge = new Bridge(
            address(dummyToken),     // token (original)
            mumbaiTokenPlaceholder,  // counterpart token (to be updated)
            MUMBAI_CHAIN_ID,         // counterpart chain id
            true                     // is source chain
        );
        console.log("Sepolia Bridge deployed at: %s", address(bridge));

        vm.stopBroadcast();

        // Log deployment info
        console.log("\n=== Sepolia Deployment Complete ===");
        console.log("DummyToken: %s", address(dummyToken));
        console.log("Bridge: %s", address(bridge));
        console.log("\nSave these addresses for Mumbai deployment!");
        console.log("export SEPOLIA_DUMMY_TOKEN=%s", address(dummyToken));
        console.log("export SEPOLIA_BRIDGE=%s", address(bridge));
    }

    function deployOnMumbai() internal {
        // Get Sepolia addresses from environment
        address sepoliaDummyToken = vm.envAddress("SEPOLIA_DUMMY_TOKEN");
        require(sepoliaDummyToken != address(0), "SEPOLIA_DUMMY_TOKEN not set");

        vm.startBroadcast();

        console.log("Deploying on Mumbai (Chain ID: %s)", MUMBAI_CHAIN_ID);
        console.log("Deployer: %s", msg.sender);
        console.log("Sepolia DummyToken: %s", sepoliaDummyToken);

        // Deploy Bridge first (needed for BridgedToken constructor)
        Bridge bridge = new Bridge(
            address(0),              // placeholder for bridged token
            sepoliaDummyToken,       // counterpart token (original on Sepolia)
            SEPOLIA_CHAIN_ID,        // counterpart chain id
            false                    // is source chain
        );
        console.log("Mumbai Bridge deployed at: %s", address(bridge));

        // Deploy BridgedDummyToken with bridge address
        BridgedDummyToken bridgedToken = new BridgedDummyToken(
            BRIDGED_TOKEN_NAME,
            BRIDGED_TOKEN_SYMBOL,
            address(bridge)
        );
        console.log("BridgedDummyToken deployed at: %s", address(bridgedToken));

        // Deploy final bridge with correct token address
        Bridge finalBridge = new Bridge(
            address(bridgedToken),   // token (bridged)
            sepoliaDummyToken,       // counterpart token (original)
            SEPOLIA_CHAIN_ID,        // counterpart chain id
            false                    // is source chain
        );
        console.log("Final Mumbai Bridge deployed at: %s", address(finalBridge));

        // Grant bridge role to final bridge contract
        bridgedToken.addBridge(address(finalBridge));
        console.log("Bridge role granted to final bridge contract");

        vm.stopBroadcast();

        // Log deployment info
        console.log("\n=== Mumbai Deployment Complete ===");
        console.log("BridgedDummyToken: %s", address(bridgedToken));
        console.log("Bridge: %s", address(finalBridge));
        console.log("\nUpdate your environment with:");
        console.log("export MUMBAI_BRIDGED_TOKEN=%s", address(bridgedToken));
        console.log("export MUMBAI_BRIDGE=%s", address(finalBridge));
        console.log("\nNOTE: You may need to update the Sepolia bridge with the bridged token address!");
    }
}

// Additional deployment script for updating bridge addresses
contract UpdateBridgeAddresses is Script {
    function run() external {
        address bridgeAddress = vm.envAddress("BRIDGE_ADDRESS");
        address newCounterpartToken = vm.envAddress("NEW_COUNTERPART_TOKEN");
        
        vm.startBroadcast();
        
        // If needed, you can add update functions to the Bridge contract
        // For now, this would require redeployment with correct addresses
        
        vm.stopBroadcast();
    }
}