// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "./NationalToken.sol";
import "./Registry.sol";
import {INationalElectionBody} from "./interfaces/INationalElectionBody.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract PoliticalPartyManager is AccessControl, ReentrancyGuard {
    
    NationalToken public nationalToken;
    Registry public registry;
    INationalElectionBody public electionBody;

    string public partyName;
    address public chairman;
    uint256 public electionId;
    uint256 public candidacyFee;
    uint256 public membershipFee;
    uint256 public memberId;

    bytes32 public constant PARTY_LEADER = keccak256("PARTY_LEADER");
    bytes32 public constant MEMBER_ROLE = keccak256("MEMBER_ROLE");

    constructor(
        address _chairman,
        string memory _partyName,
        address _nationalTokenAddress,
        address _electionBodyAddress,
        address _registryAddress
    ) {
        chairman = _chairman;
        _grantRole(DEFAULT_ADMIN_ROLE, chairman);
        _grantRole(PARTY_LEADER, chairman);
        partyName = _partyName;
        nationalToken = NationalToken(_nationalTokenAddress);
        electionBody = INationalElectionBody(_electionBodyAddress);
        registry = Registry(_registryAddress);
    }

    struct Member {
        uint256 id;
        string name;
        string party;
        address walletAddress;
        bool hasPaidForMembership;
    }

    struct Candidate {
        uint256 id;
        string name;
        string party;
        uint256 voteCount;
        address walletAddress;
    }

    struct ElectionDetails {
        uint256 id;
        string partyName;
        uint256 startTime;
        uint256 endTime;
        uint256 candidateRegDeadline;
        uint256 winnerCandidateIndex;
    }

    mapping(uint256 => Candidate[]) public candidates;
    mapping(address => Member) public members;
    mapping(uint256 => uint256) public totalCandidates;
    mapping(uint256 => ElectionDetails) public elections;
    mapping(address => mapping(uint => bool)) public hasPaidForCandidacy;
    mapping(address => mapping(uint => bool)) public isCandidateForElection;
    // internalElectionId => voter address => has voted
    mapping(uint256 => mapping(address => bool)) public hasVoted;
    mapping(uint256 => bool) public winnerDeclared;

    event DeclareWinner(uint256 electionId, uint256 winner, bool isTie, uint256 highestVoteCount);
    event MemberRemoved(address memberAddress); 
    event DeclareTie(uint256 electionId, uint256 highestVoteCount);

    error InvalidName();
    error InvalidNIN();
    error InvalidCandidateID();
    error AlreadyVoted();
    error InvalidAmount();
    error InvalidAddress();
    error CallerMustBeAnEOA();
    error CandidateNotRegistered();
    error NotPaidForCandidacy();
    error NotPaidForMembership();
    error AlreadyPaidForCandidacy();
    error AlreadyPaidForMembership();
    error AlreadyAMember();
    error ElectionEnded();
    error ElectionIsOngoing();
    error NotAuthorizedCitizen();
    error AlreadyAMemberOfAParty();
    error InsufficientContractBal();
    error NotAMember();
    error ElectionDoesNotExist();
    error AlreadyACandidateForThisElection(uint electionId);
    error InvalidEndTime();
    error EndTimeMustBeGreaterThanStartTime();
    error ElectionDurationMustBeAtLeast30Mins();
    error ElectionResultIsATie();
    error NoCandidatesRegistered();
    error NoValidCandidates();
    error ElectionStarted();
    error ElectionNotStarted();
    error CandidateRegDeadlineMustBeAtLeast30MinsLessThanStartTime();
    error CandRegDeadlineReached();

    function updateNationalTokenCA(address _nationalToken) external onlyRole(DEFAULT_ADMIN_ROLE){
          if (_nationalToken == address(0)) revert InvalidAddress();
        nationalToken = NationalToken(_nationalToken);
    }

    function updateRegistryCA(address _registry) external onlyRole(DEFAULT_ADMIN_ROLE){
          if (_registry == address(0)) revert InvalidAddress();
        registry = Registry(_registry);
    }

    function updateElectionBodyCA(address _electionBody) external onlyRole(DEFAULT_ADMIN_ROLE){
          if (_electionBody == address(0)) revert InvalidAddress();
        electionBody = INationalElectionBody(_electionBody);
    }

    function setElectionId() external onlyRole(DEFAULT_ADMIN_ROLE) {
        electionId = electionBody.getElectionId();
    }

    function setCandidacyFee(uint256 _candidacyFee) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_candidacyFee == 0) {
            revert InvalidAmount();
        }

        candidacyFee = _candidacyFee;
    }

    function setMembershipFee(uint256 _membershipFee) external onlyRole(PARTY_LEADER) {
        if (_membershipFee == 0) {
            revert InvalidAmount();
        }

        membershipFee = _membershipFee;
    }

    function payForMembership(uint256 _nin) external nonReentrant {
        uint256 _fee = membershipFee;

        if (msg.sender.code.length > 0) {
            revert CallerMustBeAnEOA();
        }

        if (registry.checkIfCitizenIsPartyMember(_nin)) {
            revert AlreadyAMemberOfAParty();
        }

        if (!registry.getValidityOfAddress(msg.sender)) {
            revert NotAuthorizedCitizen();
        }

        if (!registry.getValidityOfNIN(_nin)) {
            revert InvalidNIN();
        }

        if (members[msg.sender].hasPaidForMembership) {
            revert AlreadyPaidForMembership();
        }

        if (_fee == 0) {
            revert InvalidAmount();
        }

        members[msg.sender].hasPaidForMembership = true;
        nationalToken.transferFrom(msg.sender, address(this), _fee);
    }

    function memberRegistration(string memory _name, uint256 _nin) external {
        if (registry.checkIfCitizenIsPartyMember(_nin)) {
            revert AlreadyAMemberOfAParty();
        }

        string memory validName = registry.getValidNameForNIN(_nin);

        if (keccak256(abi.encodePacked(validName)) != keccak256(abi.encodePacked(_name)) ) {
            revert InvalidName();
        }

        if (!registry.getValidityOfAddress(msg.sender)) {
            revert NotAuthorizedCitizen();
        }

        if (!registry.getValidityOfNIN(_nin)) {
            revert InvalidNIN();
        }

        if (hasRole(MEMBER_ROLE, msg.sender)) {
        revert AlreadyAMember(); 
        }
        
        if (!members[msg.sender].hasPaidForMembership) {
            revert NotPaidForMembership();
        }

        memberId++;

        members[msg.sender] = Member({
            id: memberId,
            name: _name,
            party: partyName,
            walletAddress: msg.sender,
            hasPaidForMembership: true
        });

        registry.setCitizenPartyMembershipStatusAsTrue(_nin);
        _grantRole(MEMBER_ROLE, msg.sender);
    }

    function removeMember(address _memberAddress, uint256 _nin) external onlyRole(PARTY_LEADER) {
        if(_memberAddress == address(0)) revert InvalidAddress();
        if(!hasRole(MEMBER_ROLE, _memberAddress)) revert NotAMember();
        delete members[_memberAddress];

        _revokeRole(MEMBER_ROLE, _memberAddress);

        registry.setCitizenPartyMembershipStatusAsFalse(_nin);

        emit MemberRemoved(_memberAddress);
    }

    function payForCandidateship() external onlyRole(MEMBER_ROLE) nonReentrant{
        if (hasPaidForCandidacy[msg.sender][electionId]) {
            revert AlreadyPaidForCandidacy();
        }

        if (block.timestamp > elections[electionId].candidateRegDeadline) {
        revert CandRegDeadlineReached();
        }
        
        hasPaidForCandidacy[msg.sender][electionId] = true;
        nationalToken.transferFrom(msg.sender, address(this), candidacyFee);
    }

    function registerCandidate(string memory _name, uint _nin) external onlyRole(MEMBER_ROLE) {
        if(isCandidateForElection[msg.sender][electionId]) revert AlreadyACandidateForThisElection(electionId);
        if (!hasPaidForCandidacy[msg.sender][electionId]) {
            revert NotPaidForCandidacy();
        }

        if (block.timestamp > elections[electionId].candidateRegDeadline) {
        revert CandRegDeadlineReached();
        }

        string memory validName = registry.getValidNameForNIN(_nin);

        if (keccak256(abi.encodePacked(validName)) != keccak256(abi.encodePacked(_name)) ) {
            revert InvalidName();
        }

        if (!registry.getValidityOfAddress(msg.sender)) {
            revert NotAuthorizedCitizen();
        }

        if (!registry.getValidityOfNIN(_nin)) {
            revert InvalidNIN();
        }

        totalCandidates[electionId]++;

        Candidate[] storage candidateList = candidates[electionId];

        candidateList.push(
            Candidate({
                id: totalCandidates[electionId],
                name: _name,
                party: partyName,
                voteCount: 0,
                walletAddress: msg.sender
            })
        );
        isCandidateForElection[msg.sender][electionId] = true;
    }

    function removeCandidate(uint256 _electionId, uint256 _candidateId, address _walletAddress)
        external
        onlyRole(PARTY_LEADER)
    {
        Candidate[] storage candidatesArray = candidates[_electionId];
        
        if (candidatesArray.length == 0) {
            revert NoCandidatesRegistered();
        }
        
        if (block.timestamp > elections[_electionId].startTime) {
            revert ElectionStarted(); // Can't remove after election starts
        }
        
        // Find the candidate by ID
        bool found = false;
        uint256 foundIndex;
        for (uint i = 0; i < candidatesArray.length; i++) {
            if (candidatesArray[i].id == _candidateId) {
                foundIndex = i;
                found = true;
                break;
            }
        }
        if (!found) revert InvalidCandidateID();
        Candidate storage candidate = candidatesArray[foundIndex];
        
        // Verify wallet address matches
        if (candidate.walletAddress != _walletAddress) {
            revert InvalidAddress();
        }
        
        // Verify candidate is registered for this election
        if (!isCandidateForElection[candidate.walletAddress][_electionId]) {
            revert CandidateNotRegistered();
        }
        
        // Clear the mapping
        isCandidateForElection[candidate.walletAddress][_electionId] = false;
        
        // Swap with last element and pop
        candidatesArray[foundIndex] = candidatesArray[candidatesArray.length - 1];
        candidatesArray.pop();

        if(totalCandidates[_electionId] > 0 ){
            totalCandidates[_electionId]-= 1;
        }
    }

    function createElection(uint256 _startTime, uint256 _endTime, uint256 _candidateRegDeadline) external onlyRole(PARTY_LEADER) {
        if(_endTime == 0) revert InvalidEndTime();
        if(_startTime > _endTime) revert EndTimeMustBeGreaterThanStartTime();
        if((_endTime - _startTime) < 1800 seconds) revert ElectionDurationMustBeAtLeast30Mins();
        if(_startTime - _candidateRegDeadline < 1800 seconds) revert CandidateRegDeadlineMustBeAtLeast30MinsLessThanStartTime();

        elections[electionId] = ElectionDetails({
            id: electionId,
            partyName: partyName,
            startTime: block.timestamp + _startTime,
            endTime: block.timestamp + _endTime,
            candidateRegDeadline: block.timestamp + _candidateRegDeadline,
            winnerCandidateIndex: 0
     });

    }

    function voteforPrimaryElection(uint256 _candidateId, uint256 _electionId) external onlyRole(MEMBER_ROLE) {
        if(!electionBody.checkIfElectionExist(_electionId)) revert ElectionDoesNotExist();
        Candidate[] storage candidatesArray = candidates[_electionId];

        bool found = false;
        uint256 foundIndex;
        for (uint i = 0; i < candidatesArray.length; i++) {
            if (candidatesArray[i].id == _candidateId) {
                foundIndex = i;
                found = true;
                break;
            }
        }

        if (!found) revert InvalidCandidateID();
        Candidate storage candidate = candidatesArray[foundIndex];

        if (block.timestamp < elections[_electionId].startTime) {
            revert ElectionNotStarted();
        }

        if(!isCandidateForElection[candidate.walletAddress][_electionId]) revert CandidateNotRegistered();
        
        if (block.timestamp > elections[_electionId].endTime) {
            revert ElectionEnded();
        }

        if (hasVoted[_electionId][msg.sender]) {
            revert AlreadyVoted();
        }

        candidate.voteCount++;
        hasVoted[_electionId][msg.sender] = true;
    }

    function declareWinner(uint256 _electionId) 
        external 
        onlyRole(PARTY_LEADER) 
        returns (Candidate memory) 
    {
        ElectionDetails storage election = elections[_electionId];
        
        // Validate election has ended
        if (block.timestamp < election.endTime) {
            revert ElectionIsOngoing();
        }
        
        Candidate[] memory candidateList = candidates[_electionId];
        if (candidateList.length == 0) {
            revert NoCandidatesRegistered();
        }
        
        // Find winner
        uint256 highestVotes = 0;
        uint256 winnerIndex = 0;
        bool isTie = false;
        
        for (uint256 i = 0; i < candidateList.length; i++) {
            // Skip candidates not registered for this election
            if (!isCandidateForElection[candidateList[i].walletAddress][_electionId]) {
                continue;
            }
            
            uint256 currentVotes = candidateList[i].voteCount;
            
            if (currentVotes > highestVotes) {
                // New winner found
                highestVotes = currentVotes;
                winnerIndex = i;
                isTie = false;
            } else if (currentVotes == highestVotes && highestVotes > 0) {
                // Tie detected
                isTie = true;
            }
        }
        
        // Handle case with no valid candidates
        if (highestVotes == 0 && candidateList.length > 0) {
            revert NoValidCandidates();
        }

        if(!isTie){
            elections[_electionId].winnerCandidateIndex = winnerIndex;
            emit DeclareWinner(
            _electionId, 
            elections[_electionId].winnerCandidateIndex,
            isTie, 
            highestVotes
        );
        winnerDeclared[_electionId] = true;
        return candidateList[winnerIndex];
        } else{
            emit DeclareTie(_electionId, highestVotes);
            revert ElectionResultIsATie();
        }
    }

    function registerWinnerWithElectionBody(uint256 _electionId) external onlyRole(PARTY_LEADER) {
        if(!winnerDeclared[_electionId]) revert ElectionIsOngoing(); 
        Candidate memory winner = candidates[_electionId][elections[_electionId].winnerCandidateIndex];

        electionBody.setCandidate(_electionId, winner.name, winner.party, winner.walletAddress);
    }

    function withdraw(address _to, uint _amount) external onlyRole(DEFAULT_ADMIN_ROLE) nonReentrant{
        if(_to == address(0)) revert InvalidAddress();
        if(_amount == 0) revert InvalidAmount();
        if(_amount > nationalToken.balanceOf(address(this))) revert InsufficientContractBal();
        nationalToken.transfer(_to, _amount);
    }

    // VIEW FUNCTIONS

    function getPartyMember(address _walletAddress) external view returns (Member memory) {
        return members[_walletAddress];
    }

    function getPartyCandidate(uint _electionId, uint _candidateId) external view returns (Candidate memory) {
        return candidates[_electionId][_candidateId - 1];
    }

    function getAllPartyCandidates(uint256 _electionId) external view returns (Candidate[] memory) {
        return candidates[_electionId];
    }

    function checkElectionStatus(uint _electionId) external view returns (ElectionDetails memory) {
        return elections[_electionId];
    }
}