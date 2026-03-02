// SPDX-License-Identifier: MIT
pragma solidity  ^0.8.30;

import {NationalToken} from "./NationalElectionBody";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

interface IElections {
    uint256 public currentElectionId;
}

contract NationalElectionBody {
    uint256 private constant APC_PARTY_ID = 1;
    uint256 private constant PDP_PARTY_ID = 2;
    uint256 private constant LABOUR_PARTY_ID = 3;
    uint256 private ELECTION_ID;


    IElections public election;
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
        uint256 PartyId;
        uint256 ElectionId;
        string Name;
        address Address;
        uint256 Id;
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
        election = IElections(_electionAddress);
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
    function addCandidateForNationaElection(uint256 _candidateId, string _candidateName, address _address) external {
        //candidates
        election_id = election.currentElectionId;

        CandidateStruct memory candidates = CandidateStruct({
            ElectionId: election_id,
            PartyId: _party,
            Name: _candidateName,
            Address: _address;
            Id: _candidateId
        });
    }
    function getCandidateForAnElection(uint256 _candidateId, string _candidateName) external view returns(CandidateStruct memory){

        return 
    }

    // function PayForRegistration(address _address) public {
        
    // }


}