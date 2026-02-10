//SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {RebaseToken} from "../src/RebaseToken.sol";
import {Vault} from "../src/Vault.sol";

import {IRebaseToken} from "../src/Interfaces/IRebaseToken.sol";

contract RebaseTokenTest is Test {
    RebaseToken private rebaseToken;
    Vault private vault;

    address public owner = makeAddr("owner");
    address public user = makeAddr("user");

    function setUp() public {
        vm.startPrank(owner);
        rebaseToken = new RebaseToken();
        vault = new Vault(IRebaseToken(address(rebaseToken)));
        rebaseToken.grantMintAndBurnRole(address(vault));
        (bool success,) = payable(address(vault)).call{value: 1e18}("");
        vm.stopPrank();
    }

    function addRewardsToVault(uint256 rewardAmount) public {
        (bool success,) = payable(address(vault)).call{value: rewardAmount}("");
    } 

    function testDepositLinear(uint256 amount) public {
        amount = bound(amount, 1e4, type(uint96).max);
        // deposit
        vm.startPrank(user);
        vm.deal(user, amount);
        vault.deposit{value: amount}();

        // check our rebase token balance
        uint256 startBalance = rebaseToken.balanceOf(user);
        console.log("StartBalance", startBalance);
        assertEq(startBalance, amount);
        // warp the time and check balance again
        vm.warp(block.timestamp + 1 hours);
        uint256 middleBalance = rebaseToken.balanceOf(user);
        console.log("MiddleBalance", middleBalance);
        // Balance should have increased due to accrued interest
        assertGt(middleBalance, startBalance);
        // warp the time again and check balance again
        vm.warp(block.timestamp + 1 hours);
        uint256 endBalance = rebaseToken.balanceOf(user);
        console.log("EndBalance", endBalance);
        // Balance should continue to increase
        assertGt(endBalance, middleBalance);

        // For linear interest, the incremental differences should be approximately equal
        assertApproxEqAbs(endBalance - middleBalance, middleBalance - startBalance, 1);

        vm.stopPrank();
    }


    function testRedeemStraightAway(uint256 amount) public{
        amount = bound(amount, 1e5, type(uint96).max);
        // deposit
        vm.startPrank(user);
        vm.deal(user, amount);
        vault.deposit{value: amount}();
        assertEq(rebaseToken.balanceOf(user), amount);

        // redeem
        vault.redeem(type(uint256).max);
        assertEq(rebaseToken.balanceOf(user), 0);
        assertEq(address(user).balance, amount);
        vm.stopPrank();
    }

    function testRedeemAfterTimePassed(uint256 depositAmount, uint256 time) public {
        time = bound(time, 1000, type(uint96).max);
        depositAmount = bound(depositAmount, 1e5, type(uint96).max);
        //deposit 
        vm.deal(user, depositAmount);
        vm.prank(user);
        vault.deposit{value: depositAmount}();
        // warp the time
        vm.warp(block.timestamp + time);
        uint256 balanceAfterSometime = rebaseToken.balanceOf(user);
        // (b) add rewards to the vault 
        vm.deal(owner, balanceAfterSometime - depositAmount);
        vm.prank(owner);
        addRewardsToVault( balanceAfterSometime - depositAmount);
        // redeem
        vm.prank(user);
        vault.redeem(type(uint256).max);
      

        uint256 ethBalance = address(user).balance;

        assertEq(ethBalance, depositAmount);
        assertGt(ethBalance, depositAmount);
    }

    function testTransfer(uint256 amount, uint256 amountToSend) public {
        amount = bound(amount, 1e5 + 1e5, type(uint96).max);
        amountToSend = bound(amountToSend, 1e5, amount - 1e5);

        //deposit
        vm.deal(user,amount);
        vm.prank(user);
        vault.deposit{value: amount}();


        address user2 = makeAddr("user2");
        uint256  userBalance = rebaseToken.balanceOf(user);
        uint256  user2Balance = rebaseToken.balanceOf(user2);
        assertEq(userBalance, amount);
        assertEq(user2Balance, 0);

        vm.prank(owner);
        rebaseToken.setInterestRate(4e10);


        // transfer
        vm.prank(user);
        rebaseToken.transfer(user2, amountToSend);
        uint256 userBalanceAfterTransfer = rebaseToken.balanceOf(user);
        uint256 user2BalanceAfterTransfer = rebaseToken.balanceOf(user2);
        assertEq(userBalanceAfterTransfer, userBalance - amountToSend);
        assertEq(user2BalanceAfterTransfer, amountToSend);

        //check the user interest rate has been inherited
        assertEq(rebaseToken.getUserInterestRate(user), 5e10);
        assertEq(rebaseToken.getUserInterestRate(user2), 5e10);

    }
}
