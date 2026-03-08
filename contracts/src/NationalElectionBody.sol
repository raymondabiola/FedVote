// SPDX-License-Identifier: MIT
pragma solidity  ^0.8.30;

import {NationalToken} from "./NationalToken.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

contract NationalElectionBody is AccessControl {
    NationalToken public nationalToken;
    
    bytes32 public constant PARTY_CHAIRMAN_ROLE = keccak256("PARTY_CHAIRMAN_ROLE");

    uint256 public RegistrationFee = 10000e18;
    uint256 public ElectionId;
    uint256 public nextElectionId;

    error InvalidPartyId(uint256 providedId, uint256 maxId);
    error PartyNotRegistered(Status status);
    error PartyAlreadyRegistered(Status status);
    error PartyNotApproved(Status status);
    error PaymentFailed();

    enum Status {pending, approved,rejected}
    struct CandidateStruct {
        uint256 PartyId;
        uint256 CandidateId;
        string Name;
        address Address;
    }

    struct Party {
        uint256 id;
        string partyName;
        address partyAddress;
        string partyAcronym;
        string partyChiarman;
        Status status;
    }
    
    Party[] public registeredParties;
    Party[] public appliedParties;
    mapping(uint256 => CandidateStruct) public partyCandidate;
    mapping(string => uint256) public applicationPartyToId;
    mapping (string => uint256) public partyNameToId;

    uint256 PartyCount;
    uint256 RegisteredCount;
    uint256 CandidateCount;

    address tokenAddress;

    event Registration_Application(
        uint256 indexed partyId,
        string partyName,
        address indexed partyAddress,
        string message
    );

    event PartyRegistered(
        uint256 indexed registeredId,
        string partyName,
        address indexed partyAddress,
        string message
    );

    event RegistrationRejected(
        uint256 indexed applicationId,
        string partyName,
        address indexed partyAddress,
        string reason
    );

    event CandidateAdded(
        uint256 indexed candidateId, 
        uint256 indexed partyId, 
        string name, 
        address candidateAddress);

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

    function RegisterParty(string memory _partyName, string memory _partyAcronym, string memory _chairman, address _address) external {
        require(applicationPartyToId[_partyAcronym] == 0, "Already applied");
        require(partyNameToId[_partyAcronym] == 0, "Already registered");

        bool success = nationalToken.transferFrom(_address, address(this), RegistrationFee);
        if (!success) {
            revert PaymentFailed();
        }

        PartyCount++;

        Party memory party = Party({
            id: PartyCount,
            partyName: _partyName,
            partyAddress: _address,
            partyChiarman: _chairman,
            partyAcronym: _partyAcronym,
            status: Status.pending
        });


        appliedParties.push(party);
        applicationPartyToId[_partyAcronym] = PartyCount;

        emit Registration_Application(PartyCount, _partyName, _address, "Successfully applied");
    }

    function approveAppliedParty(uint256 _applicationId) external onlyRole(PARTY_CHAIRMAN_ROLE) {
        if (_applicationId == 0 || _applicationId > PartyCount) {
            revert InvalidPartyId(_applicationId, PartyCount);
        }

        Party storage party = appliedParties[_applicationId - 1];

        if (party.status == Status.approved) {
            revert PartyAlreadyRegistered(party.status);
        }
        if (party.status == Status.rejected) {
            revert PartyNotRegistered(party.status);
        }

        party.status = Status.approved;

        RegisteredCount++;
        party.id = RegisteredCount;

        registeredParties.push(party);
        partyNameToId[party.partyAcronym] = RegisteredCount;

        emit PartyRegistered(RegisteredCount, party.partyName, party.partyAddress, "Successfully registered");
    }

    function rejectPartyRegistration(uint256 _applicationId, string memory _reason) external onlyRole(PARTY_CHAIRMAN_ROLE) {
        if (_applicationId == 0 || _applicationId > PartyCount) {
            revert InvalidPartyId(_applicationId, PartyCount);
        }

        Party storage party = appliedParties[_applicationId - 1];

        if (party.status == Status.approved) {
            revert PartyAlreadyRegistered(party.status);
        }
        if (party.status == Status.rejected) {
            revert PartyNotRegistered(party.status);
        }

        party.status = Status.rejected;

    // refund the registration fee
        nationalToken.transfer(party.partyAddress, RegistrationFee);

    // clear the name so they can apply again
        applicationPartyToId[party.partyAcronym] = 0;

        emit RegistrationRejected(_applicationId, party.partyName, party.partyAddress, _reason);
    }

    function addCandidateForNationalElection(uint256 _partyId, string memory _candidateName, address _address) external {
        if (_partyId > RegisteredCount) {
            revert InvalidPartyId(_partyId, RegisteredCount);
        }
        if (_partyId == 0) {
            revert InvalidPartyId(_partyId, RegisteredCount);
        }

        CandidateCount++;
        uint256 newCandidateCount = CandidateCount;

        partyCandidate[_partyId] = CandidateStruct({
            PartyId: _partyId,
            CandidateId: newCandidateCount,
            Name: _candidateName,
            Address: _address
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
        Party storage party = registeredParties[partyId - 1];

        if (party.status != Status.approved) {
            revert PartyNotRegistered(party.status);
        }
        return true;
    }

    function getPartyCandidate(string memory _party) external view returns (CandidateStruct memory) {
        uint256 partyId = partyNameToId[_party];
        CandidateStruct memory candidate = partyCandidate[partyId];
        require(candidate.CandidateId != 0, "No candidate for this party");
        return candidate;
    }

    function getRegisteredPartyCount() external view returns (uint256) {
        return RegisteredCount;
    }

    function getCandidateCount() external view returns (uint256) {
        return CandidateCount;
    }

    function changeRegistrationFee(uint256 _newRegistrationFee) external {
        RegistrationFee = _newRegistrationFee;
    }

}