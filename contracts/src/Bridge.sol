// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

interface IBridgedToken {
    function mint(address to, uint256 amount) external;
    function burn(address from, uint256 amount) external;
}

/**
 * @title Bridge
 * @dev Cross-chain bridge contract deployed on both Sepolia and Mumbai
 * Handles locking/unlocking of original tokens and minting/burning of bridged tokens
 */
contract Bridge is AccessControl, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    bytes32 public constant RELAYER_ROLE = keccak256("RELAYER_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    uint256 public constant SEPOLIA_CHAIN_ID = 11155111;
    uint256 public constant MUMBAI_CHAIN_ID = 80001;

    address public immutable token;
    address public immutable counterpartToken;
    
    uint256 public immutable thisChainId;
    uint256 public immutable counterpartChainId;
    bool public immutable isSourceChain;

    mapping(bytes32 => bool) public processedTransactions;
    mapping(address => uint256) public userNonces;
    uint256 public totalLocked;


    event TokensLocked(
        address indexed user,
        uint256 indexed amount,
        uint256 indexed nonce,
        uint256 chainId,
        bytes32 txHash
    );

    event TokensUnlocked(
        address indexed user,
        uint256 indexed amount,
        uint256 indexed nonce,
        bytes32 originalTxHash
    );

    event TokensBurned(
        address indexed user,
        uint256 indexed amount,
        uint256 indexed nonce,
        uint256 chainId,
        bytes32 txHash
    );

    event TokensMinted(
        address indexed user,
        uint256 indexed amount,
        uint256 indexed nonce,
        bytes32 originalTxHash
    );

    constructor(
        address _token,
        address _counterpartToken,
        uint256 _counterpartChainId,
        bool _isSourceChain
    ) {
        require(_token != address(0), "Invalid token address");
        require(_counterpartToken != address(0), "Invalid counterpart token address");
        
        token = _token;
        counterpartToken = _counterpartToken;
        thisChainId = block.chainid;
        counterpartChainId = _counterpartChainId;
        isSourceChain = _isSourceChain;

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(RELAYER_ROLE, msg.sender);
    }

    /**
     * @dev Lock tokens on source chain (Sepolia)
     * @param amount Amount of tokens to lock
     */
    function lockTokens(uint256 amount) 
        external 
        nonReentrant 
        whenNotPaused 
    {
        require(isSourceChain, "Not available on this chain");
        require(amount > 0, "Amount must be greater than 0");

        uint256 nonce = userNonces[msg.sender]++;
        bytes32 txHash = keccak256(abi.encodePacked(
            msg.sender,
            amount,
            nonce,
            block.timestamp,
            thisChainId
        ));

        // Transfer tokens from user to bridge
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        totalLocked += amount;

        emit TokensLocked(msg.sender, amount, nonce, counterpartChainId, txHash);
    }

    /**
     * @dev Unlock tokens on source chain (called by relayer)
     * @param user User address to unlock tokens for
     * @param amount Amount of tokens to unlock
     * @param nonce User's nonce from the original transaction
     * @param originalTxHash Hash of the original burn transaction
     */
    function unlockTokens(
        address user,
        uint256 amount,
        uint256 nonce,
        bytes32 originalTxHash
    ) 
        external 
        onlyRole(RELAYER_ROLE) 
        nonReentrant 
        whenNotPaused 
    {
        require(isSourceChain, "Not available on this chain");
        require(!processedTransactions[originalTxHash], "Transaction already processed");
        require(amount > 0, "Amount must be greater than 0");
        require(totalLocked >= amount, "Insufficient locked tokens");

        processedTransactions[originalTxHash] = true;
        totalLocked -= amount;

        IERC20(token).safeTransfer(user, amount);

        emit TokensUnlocked(user, amount, nonce, originalTxHash);
    }

    /**
     * @dev Burn bridged tokens on destination chain (Mumbai)
     * @param amount Amount of tokens to burn
     */
    function burnTokens(uint256 amount) 
        external 
        nonReentrant 
        whenNotPaused 
    {
        require(!isSourceChain, "Not available on this chain");
        require(amount > 0, "Amount must be greater than 0");

        uint256 nonce = userNonces[msg.sender]++;
        bytes32 txHash = keccak256(abi.encodePacked(
            msg.sender,
            amount,
            nonce,
            block.timestamp,
            thisChainId
        ));

        IBridgedToken(token).burn(msg.sender, amount);

        emit TokensBurned(msg.sender, amount, nonce, counterpartChainId, txHash);
    }

    /**
     * @dev Mint bridged tokens on destination chain (called by relayer)
     * @param user User address to mint tokens for
     * @param amount Amount of tokens to mint
     * @param nonce User's nonce from the original transaction
     * @param originalTxHash Hash of the original lock transaction
     */
    function mintTokens(
        address user,
        uint256 amount,
        uint256 nonce,
        bytes32 originalTxHash
    ) 
        external 
        onlyRole(RELAYER_ROLE) 
        nonReentrant 
        whenNotPaused 
    {
        require(!isSourceChain, "Not available on this chain");
        require(!processedTransactions[originalTxHash], "Transaction already processed");
        require(amount > 0, "Amount must be greater than 0");

        processedTransactions[originalTxHash] = true;

        IBridgedToken(token).mint(user, amount);

        emit TokensMinted(user, amount, nonce, originalTxHash);
    }

    /**
     * @dev Add a new relayer (admin only)
     * @param relayer Address of the new relayer
     */
    function addRelayer(address relayer) external onlyRole(ADMIN_ROLE) {
        _grantRole(RELAYER_ROLE, relayer);
    }

    /**
     * @dev Remove a relayer (admin only)
     * @param relayer Address of the relayer to remove
     */
    function removeRelayer(address relayer) external onlyRole(ADMIN_ROLE) {
        _revokeRole(RELAYER_ROLE, relayer);
    }

    /**
     * @dev Pause the bridge (admin only)
     */
    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }

    /**
     * @dev Unpause the bridge (admin only)
     */
    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }

    /**
     * @dev Emergency withdrawal function (admin only)
     * @param _token Token address to withdraw
     * @param amount Amount to withdraw
     */
    function emergencyWithdraw(address _token, uint256 amount) 
        external 
        onlyRole(ADMIN_ROLE) 
    {
        IERC20(_token).safeTransfer(msg.sender, amount);
    }

    /**
     * @dev Get user's current nonce
     * @param user User address
     * @return Current nonce for the user
     */
    function getUserNonce(address user) external view returns (uint256) {
        return userNonces[user];
    }

    /**
     * @dev Check if transaction is already processed
     * @param txHash Transaction hash to check
     * @return True if transaction is processed
     */
    function isTransactionProcessed(bytes32 txHash) external view returns (bool) {
        return processedTransactions[txHash];
    }
}