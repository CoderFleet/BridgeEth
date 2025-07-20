// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract BrrrCoin is ERC20, Ownable {
    bool public failTransfers;
    error BridgeMockToken__TransferFailed();
    
    constructor() ERC20("BrrrCoin", "BRR") Ownable(msg.sender) {
        _mint(msg.sender,1_000_000 * 10 ** decimals());
    }

    function setFailTranfers(bool _fail) external onlyOwner() {
        failTransfers = _fail;
    }

    function transfer(address _to, uint256 _amount) public override returns(bool) {
        if(failTransfers) revert BridgeMockToken__TransferFailed();
        return super.transfer(_to, _amount);
    }

    function transferFrom(address _from, address _to, uint256 _value) public override returns(bool) {
        if(failTransfers) revert BridgeMockToken__TransferFailed();
        return super.transferFrom(_from, _to, _value);
    }
}