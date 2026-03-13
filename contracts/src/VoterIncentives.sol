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

    uint public baseIncentives;

    error InvalidAddress();
    error StreakNotUpToTheMinimumEligibility(
        uint streak,
        uint minimumEligibility
    );
    error VoterDoNotHaveDemocracyBadge();
    error ContractAddressNotAllowed(address caller);
    error AlreadyClaimedIncentivesForAllThreshold();
    error InvalidAmount();

    mapping(address => mapping(uint => bool)) public hasClaimedIncentives;
    mapping(address => uint) public totalIncentivesReceived;

    constructor(
        address _democracyBadge,
        address _nationalToken,
        address _registry,
        uint _baseIncentives
    ) Ownable(msg.sender) {
        if (_baseIncentives == 0) revert InvalidAmount();

        if (
            _democracyBadge == address(0) ||
            _nationalToken == address(0) ||
            _registry == address(0)
        ) revert InvalidAddress();

        democracyBadge = DemocracyBadge(_democracyBadge);

        nationalToken = NationalToken(_nationalToken);

        registry = Registry(_registry);

        baseIncentives = _baseIncentives;
    }

// Set Parameter functions
    function updateDemocracyBadgeCA(address _newDemocracyBadgeAddr) external onlyOwner{
        democracyBadge = DemocracyBadge(_newDemocracyBadgeAddr);
    }

    function updateNationalTokenCA(address _newNationalTokenAddr) external onlyOwner{
        nationalToken = NationalToken(_newNationalTokenAddr);
    }

    function updateRegistryCA(address _newRegistryAddr) external onlyOwner{
        registry = Registry(_newRegistryAddr);
    }

// This function checks if the voter is eligibility to claim Incentives
    function checkEligibility(
        address _address
    ) public view returns (bool) {
        if (_address == address(0)) {
            revert InvalidAddress();
        }

        if (_address.code.length > 0) {
            revert ContractAddressNotAllowed(_address);
        }

        if (democracyBadge.balanceOf(_address) == 0) {
            revert VoterDoNotHaveDemocracyBadge();
        }

        uint voterStreak = registry
        .getVoterDataViaAddress(_address)
        .voterStreak;

        if (voterStreak < 3) {
            revert StreakNotUpToTheMinimumEligibility(voterStreak, 3);
        }

        bool claimedAllIncentives = true;

        for (uint i = 3; i <= voterStreak; i += 3) {
            if (!hasClaimedIncentives[msg.sender][i]) {
                claimedAllIncentives = false;
                break;
            }
        }
        if (claimedAllIncentives) revert AlreadyClaimedIncentivesForAllThreshold();

        return true;
    }


// Voters who have pending incentives will receive them when they call this function
    function claimIncentives() external {
        uint voterStreak = registry
            .getVoterDataViaAddress(msg.sender)
            .voterStreak;

        bool passed = checkEligibility(msg.sender);

        if (passed) {
            uint totalPendingIncentives;

            for (uint i = 3; i <= voterStreak; i += 3) {
                if (!hasClaimedIncentives[msg.sender][i]) {
                    hasClaimedIncentives[msg.sender][i] = true;
                    uint thresholdIncentives = calculateIncentives(i);
                    totalPendingIncentives += thresholdIncentives;
                }
            }

            nationalToken.mint(msg.sender, totalPendingIncentives);
            totalIncentivesReceived[msg.sender] += totalPendingIncentives;
        }
    }

// This function Calculates the incentives to be claimed by a voter based on the amount of times he hasclaimed on the streak.

    function calculateIncentives(uint256 streak) internal view returns (uint256) {
        uint incentives;
            uint256 level = streak / 3;

            uint256 growth = 130; // 1.30
            uint256 precision = 100;

            uint256 numerator = growth ** (level - 1);
            uint256 denominator = precision ** (level - 1);

            incentives = (baseIncentives * numerator) / denominator;
        
        return incentives;
    }

// This function sets the base incentives to be received by each voter on a minimum of 3 voter streak
    function setBaseIncentives(uint _baseIncentives) external onlyOwner {
        if (_baseIncentives == 0) {
            revert InvalidAmount();
        }
        baseIncentives = _baseIncentives;
    }
}