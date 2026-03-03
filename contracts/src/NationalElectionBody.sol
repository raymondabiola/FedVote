// SPDX-License-Identifier: MIT
pragma solidity  ^0.8.30;

import {NationalToken} from "./NationalElectionBody";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

// interface IElections {
//     uint256 public currentElectionId;
// }

contract NationalElectionBody {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    NationalToken public nationalToken;

    // error InsufficientBalance(uint256 available, uint256 required);
    // error NotAuthorized(address caller);
    error InvalidPartyId(uint256 providedId, uint256 maxId);
    error PartyNotRegistered(Status status)
    error PartyAlreadyRegistered(Status status)
    // error PartyAlreadyRegistered(string name);
    // error ElectionNotActive();
    
    uint256 RegistrationFee = 10000e18;
    uint256 PartyCount;

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
        mapping(uint256 => CandidateStruct) partyrcandidate;
        string partyAcronym;
        string partyChiarman;
        Status status;
    }
    
    Party[] public parties;
    mapping (uint256 => mapping(uint256 => CandidateStruct[])) candidate;
    mapping (string => uint256) partyNameToId;
    //mapping(string => string) partyChiarman;
    //mapping(address => mapping(uint256 => address)) candidate;



    address tokenAddress;

    event PartyRegistered(uint256 indexed partyId, string name, address partyAddress);
    // event PaymentSuccessful (address indexed _student, uint256 _amount);
    
    constructor(address _address) {
        tokenAddress = _address;
        nationalTtoken = NationalToken(tokenAddress);

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);

        //election = IElections(_electionAddress);
    }
    function RegisterParty(string memory _partyName, string memory _chairman, string memory _partyAcronym, address _address ) extanal {
        PartyCount++
        Party memory party = Party({
            id: PartyCounter,
            partyName: _partyName,
            partyAddress: _address,
            partyChiarman: chairman,
            partyAcronym: partyAcronym,
            status: Status.pending
        });
        nationalToken.transferFrom(_address, address(this), RegistrationFee);

        parties.push(party);
        partyNameToId[partyName] = PartyCount;

        emit PaymentSuccessful (PartyCount, _partyName, _address);
    }

    function ApproveParty(uint256 _partyId) external onlyRole(ADMIN_ROLE) {
        if (_partyId > PartyCount) {
            revert InvalidPartyId(_partyId, PartyCount);
        }
        if (_partyIdy == 0) {
            revert InvalidPartyId(_partyId, PartyCount);
        }
        
        Party storage party = parties[parties.length -1];

        if (party.status == Status.approved) {
            revert PartyAlreadyRegistered(party.status);
        }
        if (party.status == Status.rejected) {
            revert PartyNotRegistered(party.status);
        }
        
        party.status = Status.approved;

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