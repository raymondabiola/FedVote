// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;
import {DemocracyBadge} from "src/DemocracyBadge.sol";
import {NationalToken} from "src/NationalToken.sol";
import {Registry} from "src/Registry.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract VoterIncentives is Ownable {

    DemocracyBadge public democracyBadge;

    NationalToken public nationalToken;

    Registry public registry;

    uint incentiveAmount;

    error InvalidAddress();
    error NoVoterStreak();
    error NotEligibleYet();
    error AlreadyClaimedIncentiveForCurrentStreakThreshold(uint currentStreak);
    error DontHaveDemocracyBadge();
    error ContractAddressNotAllowed(address caller);

    mapping(address => mapping(uint => bool)) public hasClaimedIncentive;

    constructor ( address _democracyBadge,
    address _nationalToken,
    address _registry,
    uint _incentiveAmount){
        democracyBadge = DemocracyBadge(tokenAddress);
        nationalToken = NationalToken(tokenAddress);
        registry = Registry(tokenAddress);
        incentiveAmount = _incentiveAmount;
    }

    function checkEligibility(address _address,uint _voterStreak) internal {
          if (_address == address(0)) {
            revert(InvalidAddress());
        }

        if(_address.code.length > 0){
               revert ContractAddressNotAllowed(_address);
        }


        if (_voterStreak % 3 != 0) {
            revert(NotEligibleYet());
        }

        if (hasClaimedIncentive[_address][_voterStreak]) {
            revert(AlreadyClaimedIncentiveForCurrentStreakThreshold(_voterStreak));
        }

        if (democracyBadge.balanceOf(_address) == 0) {
            revert(DontHaveDemocracyBadge());
        }
    }

    function claimIncentives() external {
        uint voterStreak = registry
            .getVoterDataViaAddress(msg.sender)
            .voterStreak;

        checkEligibility(msg.sender, voterStreak);

        hasClaimedIncentive[msg.sender][voterStreak] = true;

        nationalToken.mint(msg.sender, incentiveAmount);
    }

   function setCurrentIncentive(uint _incentiveAmount) external onlyOwner {
          incentiveAmount = _incentiveAmount;  
    }
}
