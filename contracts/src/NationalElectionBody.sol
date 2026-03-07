// SPDX-License-Identifier: MIT
pragma solidity  ^0.8.30;

import {NationalToken} from "./NationalToken.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

contract NationalElectionBody is AccessControl {
    NationalToken public nationalToken;
    
    bytes32 public constant PARTY_CHAIRMAN_ROLE = keccak256("PARTY_CHAIRMAN_ROLE");

    uint256 RegistrationFee = 10000e18;
    uint256 public ElectionId;
    uint256 public nextElectionId;

    error InvalidPartyId(uint256 providedId, uint256 maxId);
    error PartyNotRegistered(Status status);
    error PartyAlreadyRegistered(Status status);
    error PartyNotApproved(Status status);

    enum Status {pending, approved,rejected}
    struct CandidateStruct {
        uint256 PartyId;
        uint256 CandidateId;
        string Name;
        address Address;
        uint256 Id;
    }

    struct Party {
        uint256 id;
        string partyName;
        address partyAddress;
        string partyAcronym;
        string partyChiarman;
        Status status;
    }
    
    Party[] public parties;
    mapping(uint256 => CandidateStruct) public partyCandidate;
    mapping (string => uint256) public partyNameToId;

    uint256 PartyCount;
    uint256 CandidateCount;

    address tokenAddress;

    event PartyRegistered(uint256 indexed partyId, string name, address partyAddress);
    event PartyApproved(uint256 indexed partyId);
    event CandidateAdded(uint256 indexed candidateId, uint256 indexed partyId, string name, address candidateAddress);
    
    constructor(address _address) {
        tokenAddress = _address;
        nationalToken = NationalToken(tokenAddress);

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PARTY_CHAIRMAN_ROLE, msg.sender);
        nextElectionId = 1;
    }

    function grantChairmanRole(address _chairman) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(PARTY_CHAIRMAN_ROLE, _chairman);
    }

    function RegisterParty(string memory _partyName, string memory _chairman, string memory _partyAcronym, address _address) external {
        PartyCount++;
        Party memory party = Party({
            id: PartyCount,
            partyName: _partyName,
            partyAddress: _address,
            partyChiarman: _chairman,
            partyAcronym: _partyAcronym,
            status: Status.pending
        });
        nationalToken.transferFrom(_address, address(this), RegistrationFee);

        parties.push(party);
        partyNameToId[_partyName] = PartyCount;

        emit PartyRegistered(PartyCount, _partyName, _address);
    }

    function approveParty(uint256 _partyId) external onlyRole(PARTY_CHAIRMAN_ROLE) {
        if (_partyId > PartyCount) {
            revert InvalidPartyId(_partyId, PartyCount);
        }
        if (_partyId == 0) {
            revert InvalidPartyId(_partyId, PartyCount);
        }
        
        Party storage party = parties[_partyId - 1];

        if (party.status == Status.approved) {
            revert PartyAlreadyRegistered(party.status);
        }
    
        if (party.status == Status.rejected) {
            revert PartyNotRegistered(party.status);
        }
        
        party.status = Status.approved;

        emit PartyApproved(_partyId);
    }

    function addCandidateForNationalElection(uint256 _partyId, string memory _candidateName, address _address) external {
        if (_partyId > PartyCount) {
            revert InvalidPartyId(_partyId, PartyCount);
        }
        if (_partyId == 0) {
            revert InvalidPartyId(_partyId, PartyCount);
        }
        
        Party storage party = parties[_partyId - 1];

        if (party.status != Status.approved) {
            revert PartyNotApproved(party.status);
        }

        CandidateCount++;
        uint256 newCandidateCount = CandidateCount;

        partyCandidate[_partyId] = CandidateStruct({
            PartyId: _partyId,
            CandidateId: newCandidateCount,
            Name: _candidateName,
            Address: _address,
            Id: newCandidateCount
        });

        emit CandidateAdded(newCandidateCount, _partyId, _candidateName, _address);
    
    }

    function getNextElectionId() external returns (uint256){
        ElectionId++;
        nextElectionId = ElectionId;
        return nextElectionId;
    }

    function isPartyRegistered(string memory _party) external returns(bool) {
        uint256 partyId = partyNameToId[_party];
        
        if (partyId <= 0 || partyId > PartyCount) {
            revert PartyNotRegistered(Status.pending);
        }
        Party storage party = parties[partyId - 1];

        if (party.status != Status.approved) {
            revert PartyNotRegistered(party.status);
        }
        return true;
    }

    function getPartyCandidate(string memory _party) external view returns (CandidateStruct memory) {
        uint256 partyId = partyNameToId[_party];
        CandidateStruct memory candidate = partyCandidate[partyId];
        require(candidate.Id != 0, "No candidate for this party");
        return candidate;
    }

    function getPartyCount() external view returns (uint256) {
        return PartyCount;
    }

    function getCandidateCount() external view returns (uint256) {
        return CandidateCount;
    }

    function changeRegistrationFee(uint256 _newRegistrationFee) external {
        RegistrationFee = _newRegistrationFee;
    }
}