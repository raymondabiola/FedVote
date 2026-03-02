// SPDX-License-Identifier: MIT
pragma solidity  ^0.8.30;

import {NationalToken} from "./NationalElectionBody";

contract NationalElectionBody {
   uint256 private constant PARTY_ID;
    NationalToken public nationalToken;
    
    uint256 RegistrationFee = 10000e18;

    mapping(string => string) partyChiarman;
    mapping(address => mapping(uint256 => address)) candidate;

    enum Status {
        pending,
        approved,
        rejected
    }

    enum PaymentStatus {
        paid,
        pending
    }
    struct CandidateStruct {
        string candidateName;
        address candidateAddress;
        uint256 id;
    }

    struct Party {
        uint256 id;
        string partyName;
        address partyAddress;
        
        //mapping(uint256 => Can partyrcandidate;
        string partyAcronym;
        string partyChiarman;
        Status status;
        //string constitutionIPFSHash;
        //string manifestoIPFSHash;
    }
    mapping (uint256 => mapping(uint256 => CandidateStruct)) candidate;

    Party[] public parties;

    address tokenAddress;

    event PaymentSuccessful (address indexed _student, uint256 _amount);
    constructor(address _address) {
        tokenAddress = _address;
        nationalTtoken = NationalToken(tokenAddress);
    }
    function RegisterParty(string memory partyName, string memory chairman, string memory partyAcronym, address _address ) public {
        PartyId ++;
        Party memory party = Party({
            id: PartyId,
            partyName: partyName,
            partyAddress: _address,
            partyChiarman: chairman,
            partyAcronym: partyAcronym,
            status: Status.pending
        });
        nationalToken.transferFrom(_address, address(this), RegistrationFee);
        Party storage party = parties[parties.length -1];
        party.status = Status.approved;

        parties.push(party);
        emit PaymentSuccessful (_address, RegistrationFee);
    }
    /*CandidateStruct calldata candidate, */
    function addCandidateForNationaElection(uint256 ElectioID, uint256 partyID, address _address, uint256 id) external {
        //candidates
        CandidateStruct memory candidates = CandidateStruct({
            candidateName: candidates.candidateName,
            id: candidates.id
        });
    }
    function getCandidateForAnElection(uint256 electionID) external view returns(CandidateStruct memory){
        return 
    }

    // function PayForRegistration(address _address) public {
        
    // }


}