// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {BrrrCoin} from "../src/BrrrCoin.sol";

contract BrrrCoinTest is Test {
    BrrrCoin public brrr;
    address public user = address(0x1);
    address public recipient = address(0x2);

    function setUp() public {
        brrr = new BrrrCoin();
        brrr.transfer(user, 1000 ether);
        vm.prank(user);
        brrr.approve(address(this), type(uint256).max);
    }

    function testInitialSupply() view public {
        assertEq(brrr.totalSupply(), 1_000_000 ether);
        assertEq(brrr.balanceOf(address(this)), 1_000_000 ether - 1000 ether);
        assertEq(brrr.balanceOf(user), 1000 ether);
    }

    function testTransfer() public {
        vm.prank(user);
        bool success = brrr.transfer(recipient, 200 ether);
        assertTrue(success);
        assertEq(brrr.balanceOf(recipient), 200 ether);
        assertEq(brrr.balanceOf(user), 800 ether);
    }

    function testTransferFrom() public {
        vm.prank(user);
        brrr.approve(address(this), 500 ether);
        bool success = brrr.transferFrom(user, recipient, 500 ether);
        assertTrue(success);
        assertEq(brrr.balanceOf(recipient), 500 ether);
        assertEq(brrr.balanceOf(user), 500 ether);
    }

    function testFailTransferWhenFailEnabled() public {
        brrr.setFailTranfers(true);
        vm.prank(user);
        brrr.transfer(recipient, 1 ether);
    }

    function testFailTransferFromWhenFailEnabled() public {
        vm.prank(user);
        brrr.approve(address(this), 100 ether);
        brrr.setFailTranfers(true);
        brrr.transferFrom(user, recipient, 1 ether);
    }

    function testOnlyOwnerCanSetFailTransfers() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(user);
        brrr.setFailTranfers(true);
    }
}

