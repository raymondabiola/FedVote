// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

// INTERFACES

interface IRegistry {
    struct RegisteredVoter {
        string name;
        address voterAddress;
        uint voterStreak;
        bool isRegistered;
    }
    
    function getValidNINHashForAddress(address _address) external view returns(bytes32);
    
    function registeredVoter(bytes32 _ninHash) external view returns (RegisteredVoter memory);

    function incrementVoterStreak(address _voter) external;
    
    function setVoterStreak(address _voter, uint256 _num) external;
}

interface IDemocracyBadge {
    function mintDemocracyBadge(address to) external;
    function balanceOf(address owner) external view returns (uint256);
}

interface IElectionBody {
    struct PartyCandidate {
        string partyName;
        string candidateName;
    }
    function isPartyRegistered(string memory _partyName) external view returns (bool);
    function getPartyCandidate(string memory _partyName, uint256 _electionId) external view returns (PartyCandidate memory);
}

// ELECTION CONTRACT

contract Election is AccessControl {

    bytes32 public constant ELECTION_OFFICER_ROLE = keccak256("ELECTION_OFFICER_ROLE");

    IRegistry public registry;
    IDemocracyBadge public democracyBadge;
    IElectionBody public electionBody;

    uint256 public constant BADGE_THRESHOLD = 3; 

    struct ElectionDetails {
        string name;
        uint256 startTime;
        uint256 endTime;
        bool isActive;
        bool isEnded;
    }

    uint256 public currentElectionId;

    // Mappings
    mapping(uint256 => ElectionDetails) public electionDetails;
    mapping(uint256 => mapping(string => uint256)) public voteCounts;
    mapping(uint256 => mapping(address => bool)) public hasVoted;
    mapping(uint256 => string[]) public electionParties;

    // Local Accreditation
    mapping(uint256 => mapping(address => bool)) public isAccreditedForElection;

    // Track last election voted in to handle Streak Resets
    mapping(address => uint256) public lastVotedElectionId;

    // Events
    event ElectionCreated(uint256 indexed electionId, string name);
    event VoterAccredited(address indexed voter, uint256 indexed electionId);
    event VoteCast(address indexed voter, uint256 indexed electionId, string party);
    event DemocracyBadgeAwarded(address indexed voter);
    event StreakReset(address indexed voter);
    event ElectionEnded(uint256 indexed electionId, string winner, uint256 votes, bool isTie);

    constructor(address _registry, address _democracyBadge, address _electionBody) {
        registry = IRegistry(_registry);
        democracyBadge = IDemocracyBadge(_democracyBadge);
        electionBody = IElectionBody(_electionBody);
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ELECTION_OFFICER_ROLE, msg.sender);
    }

    // ADMIN FUNCTIONS

    function createElection(
        string memory _name, 
        uint256 _durationInHours, 
        string[] memory _participatingParties
    ) external onlyRole(ELECTION_OFFICER_ROLE) {
        require(_participatingParties.length > 0, "No parties provided");
        
        currentElectionId++;
        uint256 newId = currentElectionId;

        electionDetails[newId] = ElectionDetails({
            name: _name,
            startTime: block.timestamp,
            endTime: block.timestamp + (_durationInHours * 1 hours),
            isActive: true,
            isEnded: false
        });

        for (uint i = 0; i < _participatingParties.length; i++) {
            require(electionBody.isPartyRegistered(_participatingParties[i]), "Party not registered globally");
            electionParties[newId].push(_participatingParties[i]);
        }

        emit ElectionCreated(newId, _name);
    }

    function accreditMyself() external {
        // 1. Check if Election is Active
        // We use currentElectionId to determine which election they are trying to accredit for.
        require(!electionDetails[currentElectionId].isEnded, "Election ended");
        require(electionDetails[currentElectionId].isActive, "No active election");

        // 2. Get NIN from Address
        bytes32 ninHash = registry.getValidNINHashForAddress(msg.sender);
        require(ninHash != bytes32(0), "Address not linked to NIN");

        // 3. Check Registration in Registry
        IRegistry.RegisteredVoter memory voter = registry.registeredVoter(ninHash);
        require(voter.isRegistered, "You are not a registered voter");

        // 4. Mark Accredited Locally
        require(!isAccreditedForElection[currentElectionId][msg.sender], "Already accredited for this election");
        isAccreditedForElection[currentElectionId][msg.sender] = true;
        
        emit VoterAccredited(msg.sender, currentElectionId);
    }

    function endElection(uint256 _electionId) external onlyRole(ELECTION_OFFICER_ROLE) {
        ElectionDetails storage election = electionDetails[_electionId];
        require(election.isActive, "Election not active");
        require(block.timestamp > election.endTime, "Election time not passed");

        election.isActive = false;
        election.isEnded = true;

        string memory winner = "No Votes";
        uint256 highestVotes = 0;
        bool isTie = false;
        
        string[] memory parties = electionParties[_electionId];

        for(uint i=0; i < parties.length; i++){
            uint256 votes = voteCounts[_electionId][parties[i]];
            
            if(votes > highestVotes){
                // New Leader
                highestVotes = votes;
                winner = parties[i];
                isTie = false;
            } else if (votes == highestVotes && votes > 0) {
                // Tie Detected
                isTie = true;
                winner = "No Winner (Tie)";
            }
        }

        // If it's a tie, the winner variable is "No Winner (Tie)"
        emit ElectionEnded(_electionId, winner, highestVotes, isTie);
    }

    // VOTING LOGIC

    function vote(uint256 _electionId, string memory _partyName) external {
        ElectionDetails storage election = electionDetails[_electionId];
        
        require(election.isActive, "Election not active");
        require(block.timestamp >= election.startTime && block.timestamp <= election.endTime, "Election closed");
        require(!hasVoted[_electionId][msg.sender], "Already voted");

        // Check Local Accreditation
        require(isAccreditedForElection[_electionId][msg.sender], "Not Accredited");

        // Validate Party
        IElectionBody.PartyCandidate memory candidateDetails = electionBody.getPartyCandidate(_partyName, _electionId);
        require(bytes(candidateDetails.candidateName).length > 0, "Party invalid");

        // Retrieve Data from Registry
        bytes32 ninHash = registry.getValidNINHashForAddress(msg.sender);
        IRegistry.RegisteredVoter memory voterData = registry.registeredVoter(ninHash);

        // Record Vote
        voteCounts[_electionId][_partyName]++;
        hasVoted[_electionId][msg.sender] = true;

        // Handle Streaks
        _handleStreakAndRewards(msg.sender, voterData.voterStreak, _electionId);

        emit VoteCast(msg.sender, _electionId, _partyName);
    }

    function _handleStreakAndRewards(
        address _voter, 
        uint256 _currentStreak, 
        uint256 _electionId
    ) internal {
        
        uint256 lastElectionVoted = lastVotedElectionId[_voter];
        lastVotedElectionId[_voter] = _electionId;

        // CHECK IF ELECTION MISSED
        // If they voted before (last != 0) AND current ID > last ID + 1
        if (lastElectionVoted != 0 && _electionId > (lastElectionVoted + 1)) {
            
            // RESET STREAK
            // It will beset to 1, because this current vote counts as the start of a new streak
            try registry.setVoterStreak(_voter, 1) {
                emit StreakReset(_voter);
            } catch {
                // Fail silently
            }

        } else {
            // CONTINUE STREAK

            try registry.incrementVoterStreak(_voter) {
                
                // Check for Badge Threshold (Current + 1 = Threshold)
                if ((_currentStreak + 1) == BADGE_THRESHOLD) {
                    if (democracyBadge.balanceOf(_voter) == 0) {
                        try democracyBadge.mintDemocracyBadge(_voter) {
                            emit DemocracyBadgeAwarded(_voter);
                        } catch {
                            // Fail silently
                        }
                    }
                }
            } catch {
                // Fail silently
            }
        }
    }
}