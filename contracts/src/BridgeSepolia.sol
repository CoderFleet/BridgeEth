// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract BridgeSepolia is Ownable(msg.sender) {
    IERC20 public brrrToken;

    mapping(bytes32 => bool) public processedMessages;

    error AmountZero();
    error TransferFailed();
    error AlreadyProcessed();
    error UnlockTransferFailed();

    event Locked(address indexed user, uint256 amount, string toChain, address to);
    event Unlocked(address indexed user, uint256 amount);

    constructor(address _brrrToken) Ownable(msg.sender) {
        brrrToken = IERC20(_brrrToken);
    }

    function lock(uint256 amount, string memory toChain, address to) external {
        if (amount == 0) revert AmountZero();
        if (!brrrToken.transferFrom(msg.sender, address(this), amount)) revert TransferFailed();

        emit Locked(msg.sender, amount, toChain, to);
    }

    function unlock(address to, uint256 amount, uint256 nonce, bytes memory signature) external onlyOwner {
        bytes32 messageHash = keccak256(abi.encodePacked(to, amount, nonce));
        if (processedMessages[messageHash]) revert AlreadyProcessed();

        processedMessages[messageHash] = true;
        if (!brrrToken.transfer(to, amount)) revert UnlockTransferFailed();

        emit Unlocked(to, amount);
    }
}
