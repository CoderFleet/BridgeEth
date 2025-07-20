// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Mintable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract BridgeMumbai is Ownable {
    using ECDSA for bytes32;

    address public validator;
    IERC20 public brrrToken;

    mapping(bytes32 => bool) public processedHashes;

    event TokensRedeemed(address indexed to, uint256 amount, bytes32 indexed txHash);

    constructor(address _brrrToken, address _validator) Ownable(msg.sender) {
        brrrToken = IERC20(_brrrToken);
        validator = _validator;
    }

    function redeem(
        address to,
        uint256 amount,
        bytes32 txHash,
        bytes memory signature
    ) external {
        bytes32 messageHash = keccak256(abi.encodePacked(to, amount, txHash));
        bytes32 ethSignedMessageHash = messageHash.toEthSignedMessageHash();

        require(!processedHashes[txHash], "Already processed");
        require(ethSignedMessageHash.recover(signature) == validator, "Invalid signature");

        processedHashes[txHash] = true;
        ERC20Mintable(address(brrrToken)).mint(to, amount);

        emit TokensRedeemed(to, amount, txHash);
    }

    function updateValidator(address _newValidator) external onlyOwner {
        validator = _newValidator;
    }
}
