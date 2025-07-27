// test/Bridge.t.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/DummyToken.sol";
import "../src/BridgedDummyToken.sol";
import "../src/Bridge.sol";

contract BridgeTest is Test {
    DummyToken public dummyToken;
    BridgedDummyToken public bridgedToken;
    Bridge public sepoliaBridge;
    Bridge public mumbaiBridge;
    
    address public owner = makeAddr("owner");
    address public relayer = makeAddr("relayer");
    address public user = makeAddr("user");
    
    uint256 constant SEPOLIA_CHAIN_ID = 11155111;
    uint256 constant MUMBAI_CHAIN_ID = 80001;
    uint256 constant INITIAL_SUPPLY = 1_000_000 ether;
    uint256 constant BRIDGE_AMOUNT = 100 ether;

    event TokensLocked(
        address indexed user,
        uint256 indexed amount,
        uint256 indexed nonce,
        uint256 chainId,
        bytes32 txHash
    );

    event TokensBurned(
        address indexed user,
        uint256 indexed amount,
        uint256 indexed nonce,
        uint256 chainId,
        bytes32 txHash
    );

    function setUp() public {
        vm.startPrank(owner);
        
        // Deploy DummyToken (Sepolia)
        dummyToken = new DummyToken("DummyToken", "DUMMY", INITIAL_SUPPLY);
        
        // Deploy BridgedDummyToken first with a temporary bridge address
        // We'll use a placeholder address that's not zero
        address tempBridge = makeAddr("tempBridge");
        bridgedToken = new BridgedDummyToken(
            "Bridged DummyToken",
            "bDUMMY",
            tempBridge
        );
        
        // Deploy Sepolia bridge with the bridged token address
        sepoliaBridge = new Bridge(
            address(dummyToken),        // token (original)
            address(bridgedToken),      // counterpart token (bridged)
            MUMBAI_CHAIN_ID,            // counterpart chain id
            true                        // is source chain
        );
        
        // Deploy Mumbai bridge with the dummy token address
        mumbaiBridge = new Bridge(
            address(bridgedToken),      // token (bridged)
            address(dummyToken),        // counterpart token (original)
            SEPOLIA_CHAIN_ID,           // counterpart chain id
            false                       // is source chain
        );
        
        // Grant bridge role to Mumbai bridge (replace temp bridge)
        bridgedToken.addBridge(address(mumbaiBridge));
        bridgedToken.removeBridge(tempBridge);
        
        // Add relayer to both bridges
        sepoliaBridge.grantRole(sepoliaBridge.RELAYER_ROLE(), relayer);
        mumbaiBridge.grantRole(mumbaiBridge.RELAYER_ROLE(), relayer);
        
        // Give some tokens to user
        dummyToken.transfer(user, BRIDGE_AMOUNT * 10);
        
        vm.stopPrank();
    }

    function testLockTokens() public {
        vm.startPrank(user);
        
        // Approve bridge to spend tokens
        dummyToken.approve(address(sepoliaBridge), BRIDGE_AMOUNT);
        
        // Get initial balances
        uint256 userBalanceBefore = dummyToken.balanceOf(user);
        uint256 bridgeBalanceBefore = dummyToken.balanceOf(address(sepoliaBridge));
        
        // Lock tokens
        vm.expectEmit(true, true, true, false);
        emit TokensLocked(user, BRIDGE_AMOUNT, 0, MUMBAI_CHAIN_ID, bytes32(0));
        
        sepoliaBridge.lockTokens(BRIDGE_AMOUNT);
        
        // Check balances
        assertEq(dummyToken.balanceOf(user), userBalanceBefore - BRIDGE_AMOUNT);
        assertEq(dummyToken.balanceOf(address(sepoliaBridge)), bridgeBalanceBefore + BRIDGE_AMOUNT);
        assertEq(sepoliaBridge.totalLocked(), BRIDGE_AMOUNT);
        assertEq(sepoliaBridge.getUserNonce(user), 1);
        
        vm.stopPrank();
    }

    function testMintTokens() public {
        bytes32 originalTxHash = keccak256("test_tx");
        
        vm.startPrank(relayer);
        
        // Mint tokens on Mumbai
        mumbaiBridge.mintTokens(user, BRIDGE_AMOUNT, 0, originalTxHash);
        
        // Check bridged token balance
        assertEq(bridgedToken.balanceOf(user), BRIDGE_AMOUNT);
        assertTrue(mumbaiBridge.isTransactionProcessed(originalTxHash));
        
        vm.stopPrank();
    }

    function testBurnTokens() public {
        // First mint some bridged tokens
        bytes32 originalTxHash = keccak256("test_tx");
        vm.prank(relayer);
        mumbaiBridge.mintTokens(user, BRIDGE_AMOUNT, 0, originalTxHash);
        
        vm.startPrank(user);
        
        // Burn bridged tokens
        vm.expectEmit(true, true, true, false);
        emit TokensBurned(user, BRIDGE_AMOUNT, 0, SEPOLIA_CHAIN_ID, bytes32(0));
        
        mumbaiBridge.burnTokens(BRIDGE_AMOUNT);
        
        // Check balance
        assertEq(bridgedToken.balanceOf(user), 0);
        assertEq(mumbaiBridge.getUserNonce(user), 1);
        
        vm.stopPrank();
    }

    function testUnlockTokens() public {
        // First lock some tokens
        vm.startPrank(user);
        dummyToken.approve(address(sepoliaBridge), BRIDGE_AMOUNT);
        sepoliaBridge.lockTokens(BRIDGE_AMOUNT);
        vm.stopPrank();
        
        bytes32 burnTxHash = keccak256("burn_tx");
        uint256 userBalanceBefore = dummyToken.balanceOf(user);
        
        vm.startPrank(relayer);
        
        // Unlock tokens
        sepoliaBridge.unlockTokens(user, BRIDGE_AMOUNT, 0, burnTxHash);
        
        // Check balances
        assertEq(dummyToken.balanceOf(user), userBalanceBefore + BRIDGE_AMOUNT);
        assertEq(sepoliaBridge.totalLocked(), 0);
        assertTrue(sepoliaBridge.isTransactionProcessed(burnTxHash));
        
        vm.stopPrank();
    }

    function testCannotLockZeroTokens() public {
        vm.startPrank(user);
        
        vm.expectRevert("Amount must be greater than 0");
        sepoliaBridge.lockTokens(0);
        
        vm.stopPrank();
    }

    function testCannotLockOnMumbai() public {
        vm.startPrank(user);
        
        vm.expectRevert("Not available on this chain");
        mumbaiBridge.lockTokens(BRIDGE_AMOUNT);
        
        vm.stopPrank();
    }

    function testCannotBurnOnSepolia() public {
        vm.startPrank(user);
        
        vm.expectRevert("Not available on this chain");
        sepoliaBridge.burnTokens(BRIDGE_AMOUNT);
        
        vm.stopPrank();
    }

    function testOnlyRelayerCanMint() public {
        bytes32 originalTxHash = keccak256("test_tx");
        
        vm.startPrank(user);
        
        vm.expectRevert();
        mumbaiBridge.mintTokens(user, BRIDGE_AMOUNT, 0, originalTxHash);
        
        vm.stopPrank();
    }

    function testOnlyRelayerCanUnlock() public {
        bytes32 burnTxHash = keccak256("burn_tx");
        
        vm.startPrank(user);
        
        vm.expectRevert();
        sepoliaBridge.unlockTokens(user, BRIDGE_AMOUNT, 0, burnTxHash);
        
        vm.stopPrank();
    }

    function testCannotProcessSameTransactionTwice() public {
        bytes32 originalTxHash = keccak256("test_tx");
        
        vm.startPrank(relayer);
        
        // First mint should work
        mumbaiBridge.mintTokens(user, BRIDGE_AMOUNT, 0, originalTxHash);
        
        // Second mint should fail
        vm.expectRevert("Transaction already processed");
        mumbaiBridge.mintTokens(user, BRIDGE_AMOUNT, 0, originalTxHash);
        
        vm.stopPrank();
    }

    function testPauseUnpause() public {
        vm.startPrank(owner);
        
        // Pause bridge
        sepoliaBridge.pause();
        
        vm.stopPrank();
        vm.startPrank(user);
        
        // Should revert when paused
        dummyToken.approve(address(sepoliaBridge), BRIDGE_AMOUNT);
        vm.expectRevert("EnforcedPause()");
        sepoliaBridge.lockTokens(BRIDGE_AMOUNT);
        
        vm.stopPrank();
        vm.startPrank(owner);
        
        // Unpause bridge
        sepoliaBridge.unpause();
        
        vm.stopPrank();
        vm.startPrank(user);
        
        // Should work after unpause
        sepoliaBridge.lockTokens(BRIDGE_AMOUNT);
        
        vm.stopPrank();
    }

    function testEmergencyWithdraw() public {
        // First lock some tokens
        vm.startPrank(user);
        dummyToken.approve(address(sepoliaBridge), BRIDGE_AMOUNT);
        sepoliaBridge.lockTokens(BRIDGE_AMOUNT);
        vm.stopPrank();
        
        uint256 ownerBalanceBefore = dummyToken.balanceOf(owner);
        
        vm.startPrank(owner);
        
        // Emergency withdraw
        sepoliaBridge.emergencyWithdraw(address(dummyToken), BRIDGE_AMOUNT);
        
        // Check balance
        assertEq(dummyToken.balanceOf(owner), ownerBalanceBefore + BRIDGE_AMOUNT);
        
        vm.stopPrank();
    }

    function testNonceIncrementation() public {
        vm.startPrank(user);
        
        dummyToken.approve(address(sepoliaBridge), BRIDGE_AMOUNT * 3);
        
        // First lock
        sepoliaBridge.lockTokens(BRIDGE_AMOUNT);
        assertEq(sepoliaBridge.getUserNonce(user), 1);
        
        // Second lock
        sepoliaBridge.lockTokens(BRIDGE_AMOUNT);
        assertEq(sepoliaBridge.getUserNonce(user), 2);
        
        // Third lock
        sepoliaBridge.lockTokens(BRIDGE_AMOUNT);
        assertEq(sepoliaBridge.getUserNonce(user), 3);
        
        vm.stopPrank();
    }
}