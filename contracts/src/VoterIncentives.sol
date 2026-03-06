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
    error AlreadyClaimedIncentiveForAllThreshold();
    error CannotSendZeroAmount();

    mapping(address => mapping(uint => bool)) public hasClaimedIncentive;
    mapping(address => uint) public totalIncentiveReceived;

    constructor(
        address _democracyBadge,
        address _nationalToken,
        address _registry,
        uint _incentiveAmount
    ) {
        democracyBadge = DemocracyBadge(tokenAddress);
        nationalToken = NationalToken(tokenAddress);
        registry = Registry(tokenAddress);
        incentiveAmount = _incentiveAmount;
    }

    function checkEligibility(address _address, uint _voterStreak) internal {
        if (_address == address(0)) {
            revert(InvalidAddress());
        }

        if (_address.code.length > 0) {
            revert ContractAddressNotAllowed(_address);
        }

        if (democracyBadge.balanceOf(_address) == 0) {
            revert(DontHaveDemocracyBadge());
        }
        if (_voterStreak % 3 != 0) {
            revert(NotEligibleYet());
        }

        // if (hasClaimedIncentive[_address][_voterStreak]) {
        //     revert(AlreadyClaimedIncentiveForCurrentStreakThreshold(_voterStreak));
        // }
    }

    function claimIncentives() external {
        uint voterStreak = registry
            .getVoterDataViaAddress(msg.sender)
            .voterStreak;

        checkEligibility(msg.sender, voterStreak);

        uint totalReward;

        for (uint i = 3; i <= voterStreak; i += 3) {
            if (voterStreak % 3 == 0) {
                if (!hasClaimedIncentive[msg.sender][i]) {
                    hasClaimedIncentive[msg.sender][i] = true;
                    totalReward += incentiveAmount;
                }
            }
        }
        if (totalReward == 0) {
            revert(AlreadyClaimedIncentiveForAllThreshold());
        }


        totalIncentiveReceived[msg.sender] = totalReward; 

        nationalToken.mint(msg.sender, totalReward);

    }

    function setCurrentIncentive(uint _incentiveAmount) external onlyOwner {
        if(_incentiveAmount < 1){
            revert(CannotSendZeroAmount());
        }
        incentiveAmount = _incentiveAmount;
    }
}

