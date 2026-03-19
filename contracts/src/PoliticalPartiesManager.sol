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
    uint256 public lastWinnerId;

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
        bool hasVoted;
    }

    struct Candidate {
        uint256 id;
        string name;
        string party;
        uint256 voteCount;
        bool isRegistered;
        address walletAddress;
    }

    struct ElectionDetails {
        uint256 id;
        string partyName;
        uint256 startTime;
        uint256 endTime;
    }

    mapping(uint256 => Candidate[]) public candidates;
    mapping(address => Member) public members;
    mapping(uint256 => uint256) public totalCandidates;
    mapping(uint256 => ElectionDetails) public elections;
    mapping(bytes32 => bool) private memberExists;
    mapping(address => mapping(uint => bool)) public hasPaidForCandidacy;
    mapping(address => mapping(uint => bool)) public isCandidateForElection;

    address[] public memberAddresses;

    event DeclareWinner(uint256 electionId, uint256 winner, bool isTie, uint256 highestVoteCount);
    event MemberRemoved(address memberAddress); 

    error NotYourParty();
    error InvalidName();
    error InvalidNIN();
    error InvalidCandidateID();
    error AlreadyVoted();
    error InvalidAmount();
    error InvalidAddress();
    error CallerMustBeAnEOA();
    error CandidateNotRegistered();
    error NotPaidForCandidacy();
    error CandidateAlreadyExists();
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

        if (msg.sender.code.length > 0) {
            revert CallerMustBeAnEOA();
        }

        members[msg.sender].hasPaidForMembership = true;
        nationalToken.transferFrom(msg.sender, address(this), _fee);
    }

    function registerMember(string memory _name, uint256 _nin) external {
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
        revert AlreadyAMember(); // Add this error
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
            hasPaidForMembership: true,
            hasVoted: false
        });

        memberAddresses.push(msg.sender);

        registry.setCitizenPartyMembershipStatusAsTrue(_nin);
        _grantRole(MEMBER_ROLE, msg.sender);
    }

    function removeMember(address _memberAddress, uint256 _nin) external onlyRole(PARTY_LEADER) {
        if(!hasRole(MEMBER_ROLE, _memberAddress)) revert NotAMember();
        delete members[_memberAddress];

        _revokeRole(MEMBER_ROLE, _memberAddress);

        for (uint256 i = 0; i < memberAddresses.length; i++) {
            if (memberAddresses[i] == _memberAddress) {
                memberAddresses[i] = memberAddresses[memberAddresses.length - 1];

                memberAddresses.pop();
            }
        }

        registry.setCitizenPartyMembershipStatusAsFalse(_nin);

        emit MemberRemoved(_memberAddress);
    }

    function payForCandidateship() external onlyRole(MEMBER_ROLE) nonReentrant{
        uint256 _fee = candidacyFee;

        if (hasPaidForCandidacy[msg.sender][electionId]) {
            revert AlreadyPaidForCandidacy();
        }

        if (block.timestamp > elections[electionId].endTime) {
        revert ElectionEnded();
        }
        
        hasPaidForCandidacy[msg.sender][electionId] = true;
        nationalToken.transferFrom(msg.sender, address(this), _fee);
    }

    function registerCandidate(string memory _name, uint _nin) external onlyRole(MEMBER_ROLE) {
        if(isCandidateForElection[msg.sender][electionId]) revert AlreadyACandidateForThisElection(electionId);
        if (!hasPaidForCandidacy[msg.sender][electionId]) {
            revert NotPaidForCandidacy();
        }

        if (block.timestamp > elections[electionId].endTime) {
        revert ElectionEnded();
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
                isRegistered: true,
                walletAddress: msg.sender
            })
        );
        isCandidateForElection[msg.sender][electionId] = true;
    }

    function removeCandidate(uint256 _electionId, uint256 _candidateId, address _walletAddress)
        external
        onlyRole(PARTY_LEADER)
    {
        Candidate[] storage candidateList = candidates[_electionId];

        if (!candidateList[_candidateId - 1].isRegistered) {
            revert CandidateNotRegistered();
        }

        if (block.timestamp > elections[_electionId].endTime) {
        revert ElectionEnded(); // Can't remove after election ends
        }

        candidateList[_candidateId - 1] = candidateList[candidateList.length - 1];
        candidateList.pop();
    }

    function createElection(uint256 _durationInHours) external onlyRole(PARTY_LEADER) {
        elections[electionId] = ElectionDetails({
            id: electionId,
            partyName: partyName,
            startTime: block.timestamp,
            endTime: block.timestamp + (_durationInHours * 1 hours)   
     });

    }

    function voteforPrimaryElection(uint256 _candidateId, uint256 _electionId) external onlyRole(MEMBER_ROLE) {
        if(!electionBody.checkIfElectionExist(_electionId)) revert ElectionDoesNotExist();
        Member storage voter = members[msg.sender];
        Candidate storage candidate = candidates[_electionId][_candidateId - 1];

         if (!candidate.isRegistered) {
        revert CandidateNotRegistered();
        }

        if (block.timestamp > elections[_electionId].endTime) {
            revert ElectionEnded();
        }

        if (_candidateId == 0 || _candidateId > totalCandidates[_electionId]) {
            revert InvalidCandidateID();
        }

        if (voter.hasVoted) {
            revert AlreadyVoted();
        }

        candidate.voteCount++;
        voter.hasVoted = true;
    }

    function declareWinner(uint256 _electionId) external onlyRole(PARTY_LEADER) returns (Candidate memory) {
        ElectionDetails storage election = elections[_electionId];

        if (block.timestamp < election.endTime) {
            revert ElectionIsOngoing();
        }

        uint256 highestVotes = 0;
        uint256 winnerId = 0;
        bool isTie = false;

        for (uint256 i = 0; i < candidates[_electionId].length; i++) {
            if (!candidates[_electionId][i].isRegistered) continue;

            if (candidates[_electionId][i].voteCount > highestVotes) {
                highestVotes = candidates[_electionId][i].voteCount;
                winnerId = i;
                isTie = false;
            } else if (candidates[_electionId][i].voteCount == highestVotes) {
                isTie = true;
            }
        }

        lastWinnerId = winnerId;

        emit DeclareWinner(_electionId, winnerId, isTie, highestVotes);

        return candidates[_electionId][winnerId];
    }

    function registerWinnerWithElectionBody(uint256 _electionId) external onlyRole(PARTY_LEADER) {
        Candidate memory winner = candidates[_electionId][lastWinnerId];

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

    function getAllPartyMembers() external view returns (Member[] memory) {
        uint256 length = memberAddresses.length;
        Member[] memory partyMembers = new Member[](length);

        for (uint256 i = 0; i < length; i++) {
            partyMembers[i] = members[memberAddresses[i]];
        }
        return partyMembers;
    }

    function getAllPartyCandidates(uint256 _electionId) external view returns (Candidate[] memory) {
        return candidates[_electionId];
    }

    function checkElectionStatus(uint _electionId) external view returns (ElectionDetails memory) {
        return elections[_electionId];
    }
}
