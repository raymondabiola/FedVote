// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

//  INTERFACES

interface IRegistry {
    struct RegisteredVoter {
        string name;
        address voterAddress;
        uint voterStreak;
        bool isRegistered;
    }

    function getValidNINHashForAddress(address _address) external view returns (bytes32);

    function registeredVoter(bytes32 _ninHash) external view returns (RegisteredVoter memory);

    function incrementVoterStreak(address _voter) external;

    function resetVoterStreak(address _voter) external;
}

interface IDemocracyBadge {
    function balanceOf(address owner) external view returns (uint256);

    function mintDemocracyBadge(address to) external;
}

interface IElectionBody {
    struct CandidateStruct {
        uint256 PartyId;
        string Name;
        string PartyAcronym;
        address Address;
    }

    // Returns true if the party is approved for the given election.
    function isPartyRegistered(string memory _partyAcronym, uint256 _electionId) external view returns (bool);

    // Returns the candidate for a party in a given election.
    // name will be empty if no candidate has been set yet.
    function getPartyCandidate(string memory _partyAcronym, uint256 _electionId) external view returns (CandidateStruct memory);

    // The current active election cycle ID set by the election body admin.
    function electionId() external view returns (uint256);
}

//  ELECTION CONTRACT

contract Election is AccessControl, ReentrancyGuard{

    //  ROLES

    bytes32 public constant ELECTION_OFFICER_ROLE = keccak256("ELECTION_OFFICER_ROLE");

    //  EXTERNAL CONTRACTS

    IRegistry public registry;
    IDemocracyBadge public democracyBadge;
    IElectionBody public electionBody;

    //  CONSTANTS

    uint256 public constant BADGE_THRESHOLD = 3;

    // CUSTOM ERRORS
    error AlreadyVoted();
    error InvalidAddress();
    error ElectionHasEnded();
    error InvalidEndTime();
    error EndTimeMustBeGreaterThanStartTime();
    error ElectionDurationMustBeAtLeast30Mins();
    error ElectionNotStarted();
    error NoActiveElection();
    error ElectionNotActive();
    error ElectionNotEnded();
    error AlreadyAccredited();
    error NotAccredited();
    error AddressNotLinkedToNIN();
    error NotARegisteredVoter();
    error NoCandidateForParty();
    error CurrentElectionIsActive();
    error NoPartiesProvided();
    error PartyNotRegisteredForThisElection();
    error PartyNotInThisElectionParticipatingList();

    //  STRUCTS

    struct ElectionDetails {
        string name;
        uint256 electionId;   // The ID sourced from ElectionBody
        uint256 startTime;
        uint256 endTime;
        bool isActive;
        string winner;            // Stored on-chain so it can be queried after the election ends
        bool isTie;
    }

    //  STATE

    uint256 public currentElectionId;

    //  MAPPINGS

    mapping(uint256 => ElectionDetails) public elections;

    // internalElectionId => partyAcronym => vote count
    mapping(uint256 => mapping(string => uint256)) public voteCounts;

    // internalElectionId => voter address => has voted
    mapping(uint256 => mapping(address => bool)) public hasVoted;

    // internalElectionId => list of participating party acronyms
    mapping(uint256 => string[]) public electionParties;

    // internalElectionId => voter address => is accredited
    mapping(uint256 => mapping(address => bool)) public isAccreditedForElection;

    // voter address => internalElectionId of last election they voted in (for streak tracking)
    mapping(address => uint256) public lastVotedElectionId;

    //  EVENTS

    event ElectionCreated(uint256 indexed electionId, string name);
    event VoterAccredited(address indexed voter, uint256 indexed internalId);
    event VoteCast(address indexed voter, uint256 indexed internalId, string partyAcronym);
    event DemocracyBadgeAwarded(address indexed voter);
    event StreakReset(address indexed voter);
    event ElectionEnded(uint256 indexed internalId, string winner, uint256 votes, bool isTie);

    //  CONSTRUCTOR

    constructor(address _registry, address _democracyBadge, address _electionBody) {
        registry      = IRegistry(_registry);
        democracyBadge = IDemocracyBadge(_democracyBadge);
        electionBody  = IElectionBody(_electionBody);

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ELECTION_OFFICER_ROLE, msg.sender);
    }

    //  ADMIN: CREATE ELECTION

     function updateDemocracyBadgeCA(address _democracyBadge) external onlyRole(DEFAULT_ADMIN_ROLE){
         if (_democracyBadge == address(0)) revert InvalidAddress();
        democracyBadge = IDemocracyBadge(_democracyBadge);
    }

    function updateElectionBodyCA(address _electionBody) external onlyRole(DEFAULT_ADMIN_ROLE){
          if (_electionBody == address(0)) revert InvalidAddress();
        electionBody = IElectionBody(_electionBody);
    }

    function updateRegistryCA(address _registry) external onlyRole(DEFAULT_ADMIN_ROLE){
          if (_registry == address(0)) revert InvalidAddress();
        registry = IRegistry(_registry);
    }

    function createElection(
        string memory _name,
        string[] memory _participatingParties,
        uint256 _startTime,
        uint256 _endTime
    ) external onlyRole(ELECTION_OFFICER_ROLE) {

        if(elections[currentElectionId].isActive) revert CurrentElectionIsActive();
        if(_participatingParties.length == 0) revert NoPartiesProvided();

        if(_endTime == 0) revert InvalidEndTime();
        if(_startTime > _endTime) revert EndTimeMustBeGreaterThanStartTime();
        if((_endTime - _startTime) < 1800 seconds) revert ElectionDurationMustBeAtLeast30Mins();


        currentElectionId = electionBody.electionId();

        // Validate every party against ElectionBody before creating
        for (uint256 i = 0; i < _participatingParties.length; i++) {

            if(!electionBody.isPartyRegistered(_participatingParties[i], currentElectionId)) revert PartyNotRegisteredForThisElection();

            electionParties[currentElectionId].push(_participatingParties[i]);
        }

        elections[currentElectionId] = ElectionDetails({
            name:          _name,
            electionId: currentElectionId,
            startTime:     block.timestamp + _startTime,
            endTime:       block.timestamp + _endTime,
            isActive:      true,
            winner:        "",
            isTie:         false
        });

        emit ElectionCreated(currentElectionId, _name);
    }

    //  SELF-ACCREDITATION

    function accreditMyself() external {
        uint256 currentId = currentElectionId;

        if (currentId == 0) revert NoActiveElection();

        ElectionDetails storage election = elections[currentId];
        if (!election.isActive) revert ElectionNotActive();

        if (block.timestamp > election.endTime) {
            revert ElectionHasEnded();
        }

        // Verify the caller has a valid NIN on record
        bytes32 ninHash = registry.getValidNINHashForAddress(msg.sender);
        if (ninHash == bytes32(0)) revert AddressNotLinkedToNIN();

        // Verify the caller is a registered voter
        IRegistry.RegisteredVoter memory voter = registry.registeredVoter(ninHash);
        if (!voter.isRegistered) revert NotARegisteredVoter();

        if (isAccreditedForElection[currentId][msg.sender]) revert AlreadyAccredited();
        isAccreditedForElection[currentId][msg.sender] = true;

        emit VoterAccredited(msg.sender, currentId);
    }

    //  VOTING

    function vote(string memory _partyAcronym) external nonReentrant {
        ElectionDetails storage election = elections[currentElectionId];

        if (block.timestamp < election.startTime) {
            revert ElectionNotStarted();
        }

        if (block.timestamp > election.endTime) {
            revert ElectionHasEnded();
        }

        if (hasVoted[currentElectionId][msg.sender]) revert AlreadyVoted();
        if (!isAccreditedForElection[currentElectionId][msg.sender]) revert NotAccredited();

        // Validate the party is in this election's participating list
        if(!_partyIsInElection(currentElectionId, _partyAcronym)) revert PartyNotInThisElectionParticipatingList();

        // Validate the party has a candidate registered with ElectionBody
        IElectionBody.CandidateStruct memory candidate =
            electionBody.getPartyCandidate(_partyAcronym, election.electionId);
        if (bytes(candidate.Name).length == 0) revert NoCandidateForParty();

        // Record the vote
        voteCounts[currentElectionId][_partyAcronym]+=1;
        hasVoted[currentElectionId][msg.sender] = true;

        // Retrieve voter data for streak handling
        bytes32 ninHash = registry.getValidNINHashForAddress(msg.sender);
        IRegistry.RegisteredVoter memory voterData = registry.registeredVoter(ninHash);

        _handleStreakAndRewards(msg.sender, voterData.voterStreak);
        lastVotedElectionId[msg.sender] = currentElectionId;

        emit VoteCast(msg.sender, currentElectionId, _partyAcronym);
    }

    //  END ELECTION

    /// Ends an election, tallies votes, and stores the result on-chain.
    function declareWinner() external onlyRole(ELECTION_OFFICER_ROLE) {
        ElectionDetails storage election = elections[currentElectionId];

        if (!election.isActive) revert ElectionNotActive();
        if (block.timestamp <= election.endTime) revert ElectionNotEnded();

        election.isActive = false;

        string memory winner    = "No Votes";
        uint256 highestVotes    = 0;
        bool isTie              = false;

        string[] memory parties = electionParties[currentElectionId];

        for (uint256 i = 0; i < parties.length; i++) {
            uint256 votes = voteCounts[currentElectionId][parties[i]];

            if (votes > highestVotes) {
                highestVotes = votes;
                winner       = parties[i];
                isTie        = false;
            } else if (votes == highestVotes && votes > 0) {
                isTie  = true;
                winner = "No Winner (Tie)";
            }
        }

        // Store result on-chain for post-election queries
        election.winner = winner;
        election.isTie  = isTie;

        emit ElectionEnded(currentElectionId, winner, highestVotes, isTie);
    }

    //  INTERNAL HELPERS

    // Handles streak increment/reset and badge minting.
    function _handleStreakAndRewards(
        address _voter,
        uint256 _currentStreak
    ) internal {
        uint256 lastElectionVoted = lastVotedElectionId[_voter];

        if (lastElectionVoted != 0 && currentElectionId > (lastElectionVoted + 1)) {
            // Voter missed at least one election — reset streak to 1
            // (reset to 0 first, then increment so this vote counts as the new start)
            try registry.resetVoterStreak(_voter) {
                try registry.incrementVoterStreak(_voter) {
                    emit StreakReset(_voter);
                } catch {}
            } catch {}
        } else {
            // Continuing streak
            try registry.incrementVoterStreak(_voter) {
                // Badge threshold check uses the streak value BEFORE this increment.
                // If streak was 2, after increment it is 3, so (_currentStreak + 1) == BADGE_THRESHOLD.
                if ((_currentStreak + 1) == BADGE_THRESHOLD) {
                    if (democracyBadge.balanceOf(_voter) == 0) {
                        try democracyBadge.mintDemocracyBadge(_voter) {
                            emit DemocracyBadgeAwarded(_voter);
                        } catch {}
                    }
                }
            } catch {}
        }
    }

    // Returns true if the given party acronym is in the election's participating list.
    function _partyIsInElection(uint256 _electionId, string memory _partyAcronym) internal view returns (bool) {
        string[] memory parties = electionParties[_electionId];
        bytes32 target = keccak256(abi.encodePacked(_partyAcronym));
        for (uint256 i = 0; i < parties.length; i++) {
            if (keccak256(abi.encodePacked(parties[i])) == target) return true;
        }
        return false;
    }

    //  VIEW FUNCTIONS

    // Returns the stored winner for a completed election.
    function getElectionResult(uint256 _electionId)
        external
        view
        returns (string memory winner, bool isTie)
    {
        ElectionDetails storage e = elections[_electionId];
        return (e.winner, e.isTie);
    }
}