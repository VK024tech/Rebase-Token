//SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/*
* @title RebaseToken
* @author Vivek kandari
* @notice This is a cross-chain rebase token that incentivises users to deposit into a vault and gain interest in rewards.
* @notice The interest rate in the smart contract can only decrease
* @notice Each user will have their own interest rate that is global interest rate at the time of depositing.
*/
contract RebaseToken is ERC20 {
    error RebaseToken__InterestRateCanOnlyDecrease(uint256 currentRate, uint256 newRate);

    uint256 private constant PRECISION_FACTOR = 1e18;
    uint256 public s_interestRate = 5e10;
    mapping(address => uint256) private s_userInterestRate;
    mapping(address => uint256) private s_userLastUpdatedTimestamp;

    event InterestRateSet(uint256 newInterestRate);

    constructor() ERC20("Rebase Token", "RBT") {}

    /*
    * @notice Set the interest rate in the contract
    * @param _newInterestRate The new interest rate to be set
    * @dev The interest rate can only decrease
    */
    function setInterestRate(uint256 _newInterestRate) external {
        if (_newInterestRate >= s_interestRate) {
            revert RebaseToken__InterestRateCanOnlyDecrease(s_interestRate, _newInterestRate);
        }

        s_interestRate = _newInterestRate;

        emit InterestRateSet(_newInterestRate);
    }

    /*
    * @notice get the principle balance of a user. this is the number of tokens that have currently been minted to the user, 
    * not including any interest rate that has accured since last time the user interacted with protocol.
    * @param _user the user to get pricipla balance for
    * @returns the principle balance of the user 
    */
    function principleBalanceOf(address _user) external view returns (uint256){
        return super.balanceOf(_user);
    }

    /*
    * @notice Mint the user tokens when they deposit into the vault
    * @param _to the user to mint the tokens to
    * @param _amounr the amount of tokens to mint
    */

    function mint(address _to, uint256 _amount) external {
        _mintAccruedInterest(_to);
        s_userInterestRate[_to] = s_interestRate;
        _mint(_to, _amount);
    }

    /*
    * @notice burn the user tokens when they withdraw from the vault
    * @param _from the user to burn the tokens from
    * @param _amount the amount of tokens to burn
    */
    function burn(address _from, uint256 _amount) external{
        if(_amount == type(uint256).max){
            _amount = balanceOf(_from);
        }
        _mintAccruedInterest(_from);
        _burn(_from, _amount);
    }

    /*
    * @notice Calculate the balance for user including accumulated interest for a user since their last update
    * (principal balnace) + some interest
    * @param _user The user to calculate the balance for
    * @return The balance of the user including accumulated interest
    */
    function balanceOf(address _user) public view override returns (uint256) {
        return super.balanceOf(_user) * _calculateUserAccumulatedInterestSinceLastUpdate(_user) / PRECISION_FACTOR;
    }

    /*
    * @notice Transfer tokens from one user to another
    * @param _recipient the user to transfer the tokens to
    * @param _amount the amount of tokens to transfer
    * @returns True if the transfer was successful
    */

    function transfer(address _recipient, uint256 _amount) public override returns(bool){
        _mintAccruedInterest(msg.sender);
        _mintAccruedInterest(_recipient);
        if(_amount == type(uint256).max){
            _amount = balanceOf(msg.sender);
        }

        if(balanceOf(_recipient)==0){
            s_userInterestRate[_recipient] = s_userInterestRate[msg.sender];
        }

        return super.transfer(_recipient, _amount);
    }

    /*
    * @notice tranfer tokens form one user to another
    *  @param _sender to transfer the tokens from
    *  @param _recipient  to transfer the tokens to
    * @param _amount the amount of tokens to transfer
    * @return true if tranfer successful
    */
    function transferFrom(address _sender, address _recipient, uint256 _amount) public override returns (bool){
        _mintAccruedInterest(_sender);
        _mintAccruedInterest(_recipient);
        if(_amount == type(uint256).max){
            _amount = balanceOf(_sender);
        }

        if(balanceOf(_recipient)==0){
            s_userInterestRate[_recipient] = s_userInterestRate[_sender];
        }

        return super.transferFrom(_sender,_recipient, _amount);
    }

    /*
    * @notice Calculate the accumulated interest for a user since their last update
    * @param _user The user to calculate the accumulated interest for
    * @return The accumulated interest for the user since their last update
    */
    function _calculateUserAccumulatedInterestSinceLastUpdate(address _user) internal view returns (uint256 linearInterest) {
        uint256 timeElapsed = block.timestamp - s_userLastUpdatedTimestamp[_user];
        linearInterest = PRECISION_FACTOR + (s_userInterestRate[_user] * timeElapsed);
        
    }

    /*
    * @notice Mint the accured interest to the user since the last time they interacted with the protocol (e.g. burn, mint, transfer)
    *  @param the user to mint accured interest to
    */

    function _mintAccruedInterest(address _user) internal {
        uint256 previousPrincipleBalance = super.balanceOf(_user);
        uint256 currentBalance = balanceOf(_user);
        uint256 balanceIncrease = currentBalance - previousPrincipleBalance; 
        s_userLastUpdatedTimestamp[_user] = block.timestamp;
        _mint(_user, balanceIncrease);
    }

    function getInterestRate() external view returns(uint256){
        return s_interestRate;
    }

    /*
    * @notice Get the interest rate of a user
    * @param _user The user to get the interest rate for
    * @return The interest rate of the user
    */
    function getUserInterestRate(address _user) external view returns (uint256) {
        return s_userInterestRate[_user];
    }
}
