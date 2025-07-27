// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title BridgedDummyToken
 * @dev Bridged token deployed on Polygon Mumbai testnet
 * Only the bridge contract can mint/burn these tokens
 */
contract BridgedDummyToken is ERC20, AccessControl {
    bytes32 public constant BRIDGE_ROLE = keccak256("BRIDGE_ROLE");

    constructor(
        string memory name,
        string memory symbol,
        address bridgeContract
    ) ERC20(name, symbol) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(BRIDGE_ROLE, bridgeContract);
    }

    /**
     * @dev Mint tokens - only callable by bridge contract
     * @param to Address to mint tokens to
     * @param amount Amount of tokens to mint
     */
    function mint(address to, uint256 amount) external onlyRole(BRIDGE_ROLE) {
        _mint(to, amount);
    }

    /**
     * @dev Burn tokens - only callable by bridge contract
     * @param from Address to burn tokens from
     * @param amount Amount of tokens to burn
     */
    function burn(address from, uint256 amount) external onlyRole(BRIDGE_ROLE) {
        _burn(from, amount);
    }

    /**
     * @dev Burn tokens from caller's balance
     * @param amount Amount of tokens to burn
     */
    function burnSelf(uint256 amount) external {
        _burn(msg.sender, amount);
    }

    /**
     * @dev Add a new bridge contract (admin only)
     * @param newBridge Address of the new bridge contract
     */
    function addBridge(address newBridge) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(BRIDGE_ROLE, newBridge);
    }

    /**
     * @dev Remove a bridge contract (admin only)
     * @param bridge Address of the bridge contract to remove
     */
    function removeBridge(address bridge) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _revokeRole(BRIDGE_ROLE, bridge);
    }
}