// SPDX-License-Identifier: MIT
pragma solidity  ^0.8.30;
import {DemocracyBadge} from "src/DemocracyBadge.sol";
import {NationalToken} from "src/NationalToken.sol";
import {Registry} from "src/Registry.sol";


contract VoterIncentives {

    DemocracyBadge public democracyBadge;

    NationalToken public nationalToken;

    Registry public registry;

    mapping(address => bool) public hasClaimedIncentive;

    uint voterStreak = registry.getVoterDataViaAddress(msg.sender).voterStreak;

    // uint resetStreak = registry.resetVoterStreak(msg.sender);

    function checkEligibility() external {
        require(msg.sender != address(0), "Invalid Address");

        require(voterStreak % 3 == 0, "Doesnt meet the requirement to get incentiviced");

        require(!hasClaimedIncentive[msg.sender], "You cant claim multiple times for same amount of voting streak" );

        hasClaimedIncentive[msg.sender] = false;

        if(democracyBadge.balanceOf(msg.sender) == 0){
            revert("You do not have the DemocracyBadge");
        }
    }

    function claimIncentive(address _patriotNFT, uint amont) public {

        nationalToken.mint(msg.sender, amount);

        hasClaimedIncentive[msg.sender] = true;
    }

}