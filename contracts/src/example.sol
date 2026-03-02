// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "./NationalToken.sol";
import "./NationalElectionBody.sol";

contract PoliticalPartiesManager {

// token used to pay for candidacy
NationalToken public nationalToken;

  // map the chairman to party 
  address public chairman;
  uint public candidacyFee;
  uint public leadingCandidateId;
  // reference to the election body contract
  NationalElectionBody public electionBody;


      constructor(address _tokenAddress, address _managerAddress, uint _candidacyFee ) {
        chairman = msg.sender;
        candidacyFee = _candidacyFee;
        nationalToken = NationalToken(_tokenAddress);
        electionBody = NationalElectionBody(_managerAddress);
      }   

        modifier onlyChairman{
            require(chairman == msg.sender , "Must be chairman");
            _;
        }

        modifier onlyMember{
           require(isMember[msg.sender], "Not authorized member");
           _; 
        }
    
    struct Member {
        uint id;
        string name;
        string party;
        address walletAddress;
        bool hasVoted;
    }

    struct Candidate {
        uint id;
        string name;
        string party;
        uint voteCount;
        address walletAddress;
    }

    mapping(uint => Candidate) public candidates;
    mapping(address => Member) public members;
    mapping(bytes32 => bool) private candidateExists;
    mapping(bytes32 => bool) private memberExists;
    mapping (address => bool) public isMember; //use struct to set

    uint8 public candidateCount;
    uint8 public memberId;

    error NotYourParty();
    error InvalidCandidate();
    error AlreadyVoted();
    error InvalidAmount();
    error InsufficientBalance();

    function PayForCandidateship() external onlyMember {
        uint _fee = candidacyFee;

        if (_fee == 0)
            revert InvalidAmount();

        if (nationalToken.balanceOf(msg.sender) < _fee )
            revert InsufficientBalance();

        nationalToken.transferFrom(msg.sender, address(this), _fee);
    }

    function RegisterCandidate(string memory _name, string memory _party, address _walletAddress ) external onlyChairman {
        bytes32 candidateHash = keccak256(abi.encodePacked(_name, _party));
        require(!candidateExists[candidateHash], "Candidate already exists");
                
        candidateCount += 1;
     
        candidates[candidateCount] = Candidate ({
            id: candidateCount,
            name: _name,
            party:_party,
            voteCount: 0,
            walletAddress: _walletAddress
        });

        candidateExists[candidateHash] = true;
    }


    function AddMember(string memory _name, string memory _party, address _walletAddress) external onlyChairman {
        require(!isMember[_walletAddress], "Member Already Exists");
        memberId += 1;

        members[_walletAddress] = Member ({
            id: memberId,
            name: _name,
            party: _party,
            walletAddress: _walletAddress,
            hasVoted: false
        });

        isMember[_walletAddress] = true;
    }

    // Check if member is part of the party before they can vote
    // check if the candidate input by the member is part of the party 
    function PrimaryElection(uint _candidateId) external onlyMember {
        if(_candidateId == 0 || _candidateId > candidateCount)
        revert InvalidCandidate();

        Member storage voter = members[msg.sender];
        Candidate storage candidate = candidates[_candidateId];

        if(voter.hasVoted) 
            revert AlreadyVoted();

        if(keccak256(bytes(voter.party)) != keccak256(bytes(candidate.party)))
        revert NotYourParty();        
        
            candidate.voteCount++;
            voter.hasVoted = true;

        if (candidate.voteCount > candidates[leadingCandidateId].voteCount)
            leadingCandidateId = _candidateId;
           
    }
     
    function DeclareWinner() external view onlyChairman returns (Candidate memory) {
        return candidates[leadingCandidateId];
    }   

    function SendWinner() external onlyChairman {
        Candidate storage winner = candidates[leadingCandidateId];
        electionBody.setCandidate(winner.id, winner.name, winner.party, winner.walletAddress);
    }

    // change wallet address for member and candidate 
    // function ChangeWalletAddress() external onlyChairman{
    //     Candidate storage candidate = can
    // } 
    
    
}