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
    function interestRate(uint256 _newInterestRate) external {
        if (_newInterestRate >= s_interestRate) {
            revert RebaseToken__InterestRateCanOnlyDecrease(s_interestRate, _newInterestRate);
        }

        s_interestRate = _newInterestRate;

        emit InterestRateSet(_newInterestRate);
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
    * @notice Calculate the balance for user including accumulated interest for a user since their last update
    * (principal balnace) + some interest
    * @param _user The user to calculate the balance for
    * @return The balance of the user including accumulated interest
    */
    function balanceOf(address _user) public view override returns (uint256) {
        return super.balanceOf(_user) * _calculateUserAccumulatedInterestSinceLastUpdate(_user) / PRECISION_FACTOR;
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

    function _mintAccruedInterest(address _user) internal {
        s_userLastUpdatedTimestamp[_user] = block.timestamp;
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
