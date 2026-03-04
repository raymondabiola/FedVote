// SPDX-License-Identifier: MIT
pragma solidity  ^0.8.30;

import {NationalToken} from "./NationalElectionBody";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

contract NationalElectionBody is AccessControl {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    NationalToken public nationalToken;

    error InvalidPartyId(uint256 providedId, uint256 maxId);
    error PartyNotRegistered(Status status);
    error PartyAlreadyRegistered(Status status);
    error PartyNotApproved(Status status);

    uint256 RegistrationFee = 10000e18;
    uint256 PartyCount;
    uint256 CandidateCount;

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
    mapping (uint256 => CandidateStruct[]) candidate;
    mapping (string => uint256) partyNameToId;




    address tokenAddress;

    event PartyRegistered(uint256 indexed partyId, string name, address partyAddress);
    // event PaymentSuccessful (address indexed _student, uint256 _amount);
    
    constructor(address _address) {
        tokenAddress = _address;
        nationalToken = NationalToken(tokenAddress);

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
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

    function ApproveParty(uint256 _partyId) external onlyRole(ADMIN_ROLE) {
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

        candidate[_partyId].push(CandidateStruct({
            PartyId: _partyId,
            CandidateId: newCandidateCount,
            Name: _candidateName,
            Address: _address,
            Id: newCandidateCount
        }));
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
        return candidate[_partyId];
    }
}