//SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {IRebaseToken} from "./Interfaces/IRebaseToken.sol";

contract Vault{
    
    IRebaseToken private immutable i_rebaseToken;

    event Deposit(address indexed user, uint256 amount);
    event Redeem(address indexed user, uint256 amount);

    error Vault__RedeemFailed();
    
    constructor(IRebaseToken _rebaseToken){
        i_rebaseToken = _rebaseToken;
    }

    receive() external payable{}

    /**
     * @notice allows user to deposit ETH into the vault and mint rebase token in return
     */
    function deposit() external payable{
        IRebaseToken(i_rebaseToken).mint(msg.sender, msg.value);
        emit Deposit(msg.sender, msg.value);
    }

    /**
     * @notice allws user to redeem their toke for ETH
     * @param _amount the amount od rebase token to redeem
     */
    function redeem(uint256 _amount) external{

        if(_amount == type(uint256).max){
            _amount = i_rebaseToken.balanceOf(msg.sender);
        }


        i_rebaseToken.burn(msg.sender, _amount);
        (bool success, ) = payable(msg.sender).call{value: _amount}("");

        if(!success){
            revert Vault__RedeemFailed();
        }

        emit Redeem(msg.sender, _amount);
    }

    /**
     * @notice get the address of the rebase token
     * @return the address of the rebase token
     */

    function getRebaseTokenAddress() external view returns (address){
        return address(i_rebaseToken); 
    }

}