// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "./NationalToken.sol";
import "./NationalElectionBody.sol";
import "./Registry.sol";

contract PoliticalPartiesManager {

// token used to pay for candidacy
NationalToken public nationalToken;
Registry public registry;

  // map the chairman to party 
  string public partyName;
  address public chairman;
  uint public electionId;
  uint public candidacyFee;
  uint public membershipFee;
  uint8 public candidateId;
  uint8 public memberId;
  uint public lastWinnerId; 

  // reference to the election body contract
  NationalElectionBody public electionBody;

 


      constructor(string memory _partyName, address _tokenAddress, address _electionBodyAddress, address _registryAddress) {
        chairman = msg.sender;
        partyName = _partyName;
        nationalToken = NationalToken(_tokenAddress);
        electionBody = NationalElectionBody(_electionBodyAddress);
        registry = Registry(_registryAddress)
      }   

        modifier onlyChairman{
            require(chairman == msg.sender , "Must be chairman");
            _;
        }

        modifier onlyMember{
           require(members[msg.sender].isMember, "Not authorized member");
           _; 
        }

        // bytes32 public constant MEMBER_ROLE = keccak256("MEMBER_ROLE");
    
    struct Member {
        uint id;
        string name;
        string party;
        address walletAddress;
        bool hasPaidForMembership;
        bool hasVoted;
        bool isMember;
    }

    struct Candidate {
        uint id;
        string name;
        string party;
        uint voteCount;
        bool isRegistered;
        address walletAddress;
    }

    struct ElectionDetails {
        uint   id;
        string partyName;
        uint startTime;
        uint endTIme;
        bool isActive;
        bool isEnded;
    }


    mapping(uint => Candidate) public candidates;
    mapping(address => Member) public members;
    mapping(uint => ElectionDetails) public elections;
    mapping(bytes32 => bool) private memberExists;
    mapping(address => bool) public hasPaidForCandidacy; 
    
    event DeclareWinner(electionId, winner, isTie, highestVoteCount);
    event MemberRemoved(memberAddress) // check how to use event again

    error NotYourParty();
    error InvalidCandidateID();
    error AlreadyVoted();
    error InvalidAmount();
    error InsufficientBalance();
    error MustBeAnEOA(); 
    error NotPaidForCandidacy(); 
    error CandidateAlreadyExists();
    error NotPaidForMembership();
    error AlreadyPaidForCandidacy();
    error AlreadyMember();
    error ElectionEnded();
    error UseValueGreaterThanZero();
    error InvalidElectionId();
    error NotAuthorizedCitizen();
    error MustBeAMember();

    function setCandidacyFee(uint _candidacyFee) external onlyChairman {
        if (_candidacyFee == 0)
            revert InvalidAmount();

        candidacyFee = _candidacyFee;
    }

    function payForCandidateship() external onlyMember {
        uint _fee = candidacyFee;   

        if (hasPaidForCandidacy[msg.sender])
            revert AlreadyPaidForCandidacy(); 

        if (_fee == 0) 
            revert InvalidAmount();

        if(msg.sender.code.length > 0) 
            revert MustBeAnEOA(); 

        if (nationalToken.balanceOf(msg.sender) < _fee )
            revert InsufficientBalance();

        nationalToken.transferFrom(msg.sender, address(this), _fee);

        hasPaidForCandidacy[msg.sender] = true;
    }

    function setElectionId(uint _electionId) external onlyRole(DEFAULT_ADMIN_ROLE){ // Implement library
        if (_electionId == 0 )
            revert UseValueGreaterThanZero();

        electionId = _electionId;
    }

    function registerCandidate(string memory _name) external onlyMember {

        if (!members[msg.sender].isMember)
            revert MustBeAMember();

        if (!hasPaidForCandidacy[msg.sender])
            revert NotPaidForCandidacy();   

        candidateId += 1;
     
        candidates[candidateId] = Candidate ({
            id: electionId,
            name: _name,
            party: partyName,
            voteCount: 0,
            isRegistered: true,
            walletAddress: msg.sender
        });

    }

    function removeCandidate(uint _candidateId, address _walletAddress) external onlyChairman {
        Candidate storage candidate = candidates[_candidateId];

        if (!candidate.isRegistered)
            revert CandidateNotRegistered();

        delete candidates[_candidateId];

        hasPaidForCandidacy[_walletAddress] = false;

    }

    function payForMembership(uint _nin) external { 
       if (registry.checkIfCitizenIsPartyMember(_nin))
            revert AlreadyMember();

       if(!registry.getValidityOfAddress(msg.sender))
            revert NotAuthorizedCitizen();

       uint _fee = membershipFee;   

        if (members[msg.sender].hasPaidForMembership)
            revert AlreadyPaidForMembership();

        if (_fee == 0)
            revert InvalidAmount();

        if(msg.sender.code.length > 0) 
            revert MustBeAnEOA(); 

        if (nationalToken.balanceOf(msg.sender) < _fee )
            revert InsufficientBalance();

        nationalToken.transferFrom(msg.sender, address(this), _fee);

        members[msg.sender].hasPaidForMembership = true;
    }

    function registerMember(string memory _name, uint _nin) external {

        if (members[msg.sender].hasPaidForMembership)
            revert NotPaidForMembership();

        if (members[msg.sender].isMember)
            revert AlreadyMember();
        
        memberId++;

        members[msg.sender] = Member ({
            id: memberId,
            name: _name,
            party: partyName,
            walletAddress: msg.sender,
            hasPaidForMembership: true,
            hasVoted: false,
            isMember: true
        });

        register.setCitizenPartyMembershipStatusAsTrue(_nin);
    
    }

    function removeMember(address _memberAddress, uint _nin) external onlyChairman {
        Member storage member = members[_memberAddress];

        if (!member.isMember)
            revert MustBeAMember();

            delete members[_memberAddress];

            register.setCitizenPartyMembershipStatusAsFalse(_nin);

            emit MemberRemoved(_memberAddress)
    }

    function createElection(uint _durationInHours) external onlyChairman {
        elections[electionId] = ElectionDetails ({
            id:        electionId,
            name:      partyName,
            startTime: block.timestamp,
            endTIme:   block.timestamp + (_durationInHours * 1 hours),  
            isActive:  true,
            isEnded:   false
        });
    }


    function voteforPrimaryElection(uint _candidateId, uint _electionID) external onlyMember {
        Member storage voter = members[msg.sender];
        Candidate storage candidate = candidates[_candidateId];

        if (block.timestamp > elections[electionId].endTIme || !elections[electionId].isActive)
            revert ElectionEnded();

        if (_electionID != candidate.id)
            revert InvalidElectionId();

        if(_candidateId == 0 || _candidateId > candidateId)
            revert InvalidCandidateID();

        if(voter.hasVoted) 
            revert AlreadyVoted();       
        
            candidate.voteCount++;
            voter.hasVoted = true;
    }
     
    function declareWinner(uint _electionId)
    external
    onlyChairman
    returns (Candidate memory)
{
    ElectionDetails storage election = elections[_electionId];

    if (block.timestamp < election.endTIme || !election.isActive)
        revert ElectionEnded();

    uint highestVotes = 0;
    uint winnerId = 0;
    bool isTie = false;
    lastWinnerId = winnerId;

    for (uint i = 1; i <= candidateId; i++) {
        if (!candidates[i].isRegistered) continue;

        if (candidates[i].voteCount > highestVotes) {
            highestVotes = candidates[i].voteCount;
            winnerId = i;
            isTie = false;
        } else if (candidates[i].voteCount == highestVotes) {
            isTie = true;
        }
    }



    emit DeclareWinner(_electionId, winnerId, isTie, highestVotes);

    return candidates[winnerId];
}   

    function registerWinnerWithElectionBody(uint _electionId) external onlyChairman {
    Candidate storage winner = candidates[lastWinnerId];

    electionBody.setCandidate(
        _electionId,
        winner.name,
        winner.party,
        winner.walletAddress
    );
}

    // change wallet address for member and candidate 
    // function ChangeWalletAddress() external onlyChairman{
    //     Candidate storage candidate = can
    // } 
    
    // get members and candidate functions
}


