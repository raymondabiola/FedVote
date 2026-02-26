// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "./NationalToken.sol";

contract primaryPrimaries {

      NationalToken public votingToken;

      // map the chairman to party 
      address public chairman;

      constructor(address _tokenAddress) {
        chairman = msg.sender;
        votingToken = NationalToken(_tokenAddress);
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
    }

    struct Candidate {
        uint id;
        string name;
        string party;
        uint voteCount;
        address walletAddress;
    }

    mapping(uint => Candidate[]) public candidates;
    mapping(uint => Member) public members;
    mapping(bytes32 => bool) private candidateExists;
    mapping(bytes32 => bool) private memberExists;
    mapping (address => bool) public isMember;
    mapping(address => bool) public hasVoted;

    uint8 public candidateCount;
    uint8 public memberId;

    error NotYourParty();
    error InvalidCandidate();
    error AlreadyVoted();

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

        members[memberId] = Member ({
            id: memberId,
            name: _name,
            party: _party,
            walletAddress: _walletAddress
        });

        isMember[_walletAddress] = true;
    }

    // Check if member is part of the party before they can vote
    // check if the candidate input by the member is part of the party 
    function PrimaryElection(uint _candidateId, string memory _party) external onlyMember {
        if(_candidateId < 0 && _candidateId <= candidateCount)
        revert InvalidCandidate();

        if(hasVoted[msg.sender])
        revert AlreadyVoted();
        
        string memory voterParty = members[_candidateId].party
        string memory candidateParty = candidates[_candidateId].party

        if(keccak256(abi.encodePacked(voterParty)) != keccak256(abi.encodePacked(candidateParty)))
        revert NotYourParty();

        candidates[_candidateId].voteCount++;
        hasVoted[msg.sender] = true;

    }

    
    // change wallet address for member and candidate 

    function DeclareWinner()

    
}


