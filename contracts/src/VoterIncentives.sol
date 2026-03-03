// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;
import {DemocracyBadge} from "src/DemocracyBadge.sol";
import {NationalToken} from "src/NationalToken.sol";
import {Registry} from "src/Registry.sol";

contract VoterIncentives {
    DemocracyBadge public democracyBadge;

    NationalToken public nationalToken;

    Registry public registry;

    error Invalid_Address();
    error No_VoterStreak();
    error Not_Eligible_Yet();
    error Already_Claim_Streak();
    error Dont_Have_DemocracyBadge();

    mapping(address => mapping(uint => bool)) public hasClaimedIncentive;

    function claimIncentives() external {
        uint voterStreak = registry
            .getVoterDataViaAddress(msg.sender)
            .voterStreak;

        if (msg.sender == address(0)) {
            revert(Invalid_Address());
        }

        if (voterStreak < 1) {
            revert(No_VoterStreak());
        }

        if (voterStreak % 3 != 0) {
            revert(Not_Eligible_Yet());
        }

        if (hasClaimedIncentive[msg.sender][voterStreak]) {
            revert(Already_Claim_Streak());
        }

        if (democracyBadge.balanceOf(msg.sender) == 0) {
            revert(Dont_Have_DemocracyBadge());
        }

        hasClaimedIncentive[msg.sender][voterStreak] = true;

        nationalToken.mint(msg.sender, 100);
    }
}
