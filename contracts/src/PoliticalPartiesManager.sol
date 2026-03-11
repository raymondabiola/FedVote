// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "./NationalToken.sol";
import "./NationalElectionBody.sol";
import "./Registry.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract PoliticalPartiesManagerFactory {
    PoliticalPartyManager[] public politicalpartymanager;
    address[] addressPoliticalPartyManager;

    function createNewPoliticalParty(
        address _chairman,
        string memory _partyName,
        address _tokenAddress,
        // address _electionBodyAddress,
        address _registryAddress
    ) external {
        PoliticalPartyManager politicalparty = new PoliticalPartyManager(
            _chairman, _partyName, _tokenAddress, _registryAddress
        );
        politicalpartymanager.push(politicalparty);

        addressPoliticalPartyManager.push(address(politicalparty));
    }

    function getAllPoliticalParty() external view returns (address[] memory) {
        return addressPoliticalPartyManager;
    }
}

contract PoliticalPartyManager is AccessControl {
    // token used to pay for candidacy
    NationalToken public nationalToken;
    Registry public registry;

    // map the chairman to party
    string public partyName;
    address public chairman;
    uint256 public electionId;
    uint256 public candidacyFee;
    uint256 public membershipFee;
    uint8 public memberId;
    uint256 public lastWinnerId;

    bytes32 public constant PARTY_LEADER = keccak256("PARTY_LEADER");
    bytes32 public constant MEMBER_ROLE = keccak256("MEMBER_ROLE");

    // reference to the election body contract
    // NationalElectionBody public electionBody;

    constructor(
        address _chairman,
        string memory _partyName,
        address _tokenAddress,
        // address _electionBodyAddress,
        address _registryAddress
    ) {
        chairman = _chairman;
        _grantRole(DEFAULT_ADMIN_ROLE, chairman);
        _grantRole(PARTY_LEADER, chairman);
        partyName = _partyName;
        nationalToken = NationalToken(_tokenAddress);
        // electionBody = NationalElectionBody(_electionBodyAddress);
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
        uint256 endTIme;
        bool isActive;
        bool isEnded;
    }

    mapping(uint256 => Candidate[]) public candidates;
    mapping(address => Member) public members;
    mapping(uint => uint) public CandidateId;
    mapping(uint256 => ElectionDetails) public elections;
    mapping(bytes32 => bool) private memberExists;
    mapping(address => bool) public hasPaidForCandidacy;

    address[] public memberAddresses;

    event DeclareWinner(uint electionId, uint winner, bool isTie, uint highestVoteCount);
    event MemberRemoved(address memberAddress); // check how to use event again

    error NotYourParty();
    error InvalidCandidateID();
    error AlreadyVoted();
    error InvalidAmount();
    error CallerMustBeAnEOA();
    error CandidateNotRegistered();
    error NotPaidForCandidacy();
    error CandidateAlreadyExists();
    error NotPaidForMembership();
    error AlreadyPaidForCandidacy();
    error AlreadyPaidForMembership();
    error ElectionEnded();
    error UseValueGreaterThanZero();
    // error InvalidElectionId();
    error NotAuthorizedCitizen();
    error AlreadyAMemberOfAParty();

    function setCandidacyFee(uint256 _candidacyFee) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_candidacyFee == 0) {
            revert InvalidAmount();
        }

        candidacyFee = _candidacyFee;
    }

    function payForCandidateship() external onlyRole(MEMBER_ROLE) {
        uint256 _fee = candidacyFee;

        if (hasPaidForCandidacy[msg.sender]) {
            revert AlreadyPaidForCandidacy();
        }

        if (msg.sender != tx.origin) {
            revert CallerMustBeAnEOA();
        }

        nationalToken.transferFrom(msg.sender, address(this), _fee);

        hasPaidForCandidacy[msg.sender] = true;
    }

    function setElectionId(uint256 _electionId) external onlyRole(DEFAULT_ADMIN_ROLE) {
        // Implement library
        if (_electionId == 0) {
            revert UseValueGreaterThanZero();
        }

        electionId = _electionId;
    }

    function registerCandidate(string memory _name) external onlyRole(MEMBER_ROLE) {
        if (!hasPaidForCandidacy[msg.sender]) {
            revert NotPaidForCandidacy();
        }

        CandidateId[electionId]++;

        Candidate[] storage candidateList = candidates[electionId];

        candidateList.push(Candidate({
            id: CandidateId[electionId],
            name: _name,
            party: partyName,
            voteCount: 0,
            isRegistered: true,
            walletAddress: msg.sender
        }));
    }

    function removeCandidate(uint256 _electionId, uint _candidateId, address _walletAddress) external onlyRole(PARTY_LEADER) {
        Candidate[] storage candidateList = candidates[_electionId];

        if (!candidateList[_candidateId].isRegistered) {
            revert CandidateNotRegistered();
        }

        delete candidateList[_candidateId];

        hasPaidForCandidacy[_walletAddress] = false;
    }

    function payForMembership(uint256 _nin) external {
        if (registry.checkIfCitizenIsPartyMember(_nin)) {
            revert AlreadyAMemberOfAParty();
        }

        if (!registry.getValidityOfAddress(msg.sender)) {
            revert NotAuthorizedCitizen();
        }

        uint256 _fee = membershipFee;

        if (members[msg.sender].hasPaidForMembership) {
            revert AlreadyPaidForMembership();
        }

        if (_fee == 0) {
            revert InvalidAmount();
        }

        if (msg.sender.code.length > 0) {
            revert CallerMustBeAnEOA();
        }

        nationalToken.transferFrom(msg.sender, address(this), _fee);

        members[msg.sender].hasPaidForMembership = true;
    }

    function registerMember(string memory _name, uint256 _nin) external {
        if (members[msg.sender].hasPaidForMembership) {
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

        delete members[_memberAddress];
        
        for (uint i = 0; i < memberAddresses.length; i++) {
            if (memberAddresses[i] == _memberAddress) {
                memberAddresses[i] = memberAddresses[memberAddresses.length- 1];

                memberAddresses.pop();
            }
        }

        registry.setCitizenPartyMembershipStatusAsFalse(_nin);

        emit MemberRemoved(_memberAddress);
    }

    function createElection(uint256 _durationInHours) external onlyRole(PARTY_LEADER) {
        elections[electionId] = ElectionDetails({
            id: electionId,
            partyName: partyName,
            startTime: block.timestamp,
            endTIme: block.timestamp + (_durationInHours * 1 hours),
            isActive: true,
            isEnded: false
        });
    }

    function voteforPrimaryElection(uint256 _candidateId, uint256 _electionId) external onlyRole(MEMBER_ROLE) {
        Member storage voter = members[msg.sender];
        Candidate storage candidate = candidates[_electionId][_candidateId];

        if (block.timestamp > elections[electionId].endTIme || !elections[electionId].isActive) {
            revert ElectionEnded();
        }

        // if (_electionID != candidate.id) {
        //     revert InvalidElectionId();
        // }

        if (_candidateId == 0 || _candidateId > CandidateId[_electionId]) {
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

        if (block.timestamp < election.endTIme || !election.isActive) {
            revert ElectionEnded();
        }

        uint256 highestVotes = 0;
        uint256 winnerId = 0;
        bool isTie = false;
        lastWinnerId = winnerId;

        for (uint256 i = 1; i <= CandidateId[_electionId]; i++) {
            if (!candidates[_electionId][i].isRegistered) continue;

            if (candidates[_electionId][i].voteCount > highestVotes) {
                highestVotes = candidates[_electionId][i].voteCount;
                winnerId = i;
                isTie = false;
            } else if (candidates[_electionId][i].voteCount == highestVotes) {
                isTie = true;
            }
        }

        emit DeclareWinner(_electionId, winnerId, isTie, highestVotes);

        return candidates[_electionId][winnerId];
    }

    // function registerWinnerWithElectionBody(uint256 _electionId) external onlyRole(PARTY_LEADER) {
    //     Candidate storage winner = candidates[lastWinnerId];

    //     electionBody.setCandidate(_electionId, winner.name, winner.party, winner.walletAddress);
    // }

    function getAllPartyMembers() external view returns (Member[] memory) {
        uint length = memberAddresses.length;
        Member[] memory partyMembers = new Member[](length);

        for (uint i = 0; i < length; i++ ){
            partyMembers[i] = members[memberAddresses[i]];
        }
        return partyMembers;
    }

    function getAllPartyCandidates(uint _electionId) external view returns (Candidate[] memory) {
        return candidates[_electionId];
    }
}
