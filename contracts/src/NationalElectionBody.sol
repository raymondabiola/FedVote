// SPDX-License-Identifier: MIT
pragma solidity  ^0.8.30;

import {NationalToken} from "./NationalToken.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

contract NationalElectionBody is AccessControl {
    NationalToken public nationalToken;
    
    bytes32 public constant PARTY_CHAIRMAN_ROLE = keccak256("PARTY_CHAIRMAN_ROLE");

    uint256 public RegistrationFee = 10000e18;
    uint256 public electionId;

    error InvalidPartyId(uint256 providedId, uint256 maxId);
    error PartyNotRegistered(Status status);
    error PartyAlreadyApproved(Status status);
    error PartyNotApproved(Status status);
    error PaymentFailed();
    error NotCurrentElection();
    error AlreadyAppliedThisElection();

    enum Status {pending, approved, rejected}

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
        Status status;
    }

    // permanent party id that never changes across elections
    mapping(string => uint256) public permanentPartyId;

    // electionId => list of parties that applied this election
    mapping(uint256 => Party[]) public appliedPartiesPerElection;

    // electionId => list of parties registered this election
    mapping(uint256 => Party[]) public registeredPartiesPerElection;

    // electionId => partyAcronym => partyId (tracks applications per election)
    mapping(uint256 => mapping(string => uint256)) public applicationPartyToId;

    // electionId => partyAcronym => partyId (tracks approvals per election)
    mapping(uint256 => mapping(string => uint256)) public partyNameToId;

    // partyId => electionId => CandidateStruct
    mapping(uint256 => mapping(uint256 => CandidateStruct)) public partyCandidate;

    uint256 PartyCount;
    uint256 CandidateCount;

    // tracks registered count per election
    mapping(uint256 => uint256) public registeredCountPerElection;

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
        address candidateAddress
    );

    constructor(address _address) {
        tokenAddress = _address;
        nationalToken = NationalToken(tokenAddress);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function setElectionId(uint256 _electionId) public onlyRole(DEFAULT_ADMIN_ROLE) {
        electionId = _electionId;
    }

    function RegisterParty(
        string memory _partyName,
        uint256 _electionId,
        string memory _partyAcronym,
        address _address
    ) external {
        // must be current election
        if (_electionId != electionId) {
            revert NotCurrentElection();
        }

        // cannot apply twice in same election
        if (applicationPartyToId[electionId][_partyAcronym] > 0) {
            revert AlreadyAppliedThisElection();
        }

        nationalToken.transferFrom(msg.sender, address(this), RegistrationFee);

        uint256 partyId;

        if (permanentPartyId[_partyAcronym] > 0) {
            // returning party from a previous election — keep their permanent ID
            partyId = permanentPartyId[_partyAcronym];
        } else {
            // brand new party — assign a new permanent ID
            PartyCount++;
            partyId = PartyCount;
            permanentPartyId[_partyAcronym] = partyId;
        }

        Party memory party = Party({
            id: partyId,
            partyName: _partyName,
            partyAddress: _address,
            partyAcronym: _partyAcronym,
            status: Status.pending
        });

        appliedPartiesPerElection[electionId].push(party);
        applicationPartyToId[electionId][_partyAcronym] = partyId;

        emit Registration_Application(partyId, _partyName, _address, "Successfully applied");
    }

    function approveAppliedParty(uint256 _applicationIndex) external {
        Party[] storage parties = appliedPartiesPerElection[electionId];

        // _applicationIndex is 1-based
        if (_applicationIndex == 0 || _applicationIndex > parties.length) {
            revert InvalidPartyId(_applicationIndex, parties.length);
        }

        Party storage party = parties[_applicationIndex - 1];

        if (party.status == Status.approved) {
            revert PartyAlreadyApproved(party.status);
        }
        if (party.status == Status.rejected) {
            revert PartyNotRegistered(party.status);
        }

        party.status = Status.approved;

        registeredCountPerElection[electionId]++;
        registeredPartiesPerElection[electionId].push(party);

        // mark as approved in this election's partyNameToId
        partyNameToId[electionId][party.partyAcronym] = party.id;

        emit PartyRegistered(party.id, party.partyName, party.partyAddress, "Successfully registered");
    }

    function rejectPartyRegistration(
        uint256 _applicationIndex,
        string memory _reason
    ) external onlyRole(PARTY_CHAIRMAN_ROLE) {
        Party[] storage parties = appliedPartiesPerElection[electionId];

        if (_applicationIndex == 0 || _applicationIndex > parties.length) {
            revert InvalidPartyId(_applicationIndex, parties.length);
        }

        Party storage party = parties[_applicationIndex - 1];

        if (party.status == Status.approved) {
            revert PartyAlreadyApproved(party.status);
        }
        if (party.status == Status.rejected) {
            revert PartyNotRegistered(party.status);
        }

        party.status = Status.rejected;

        // refund the registration fee
        nationalToken.transfer(party.partyAddress, RegistrationFee);

        // clear application so they can reapply if needed
        applicationPartyToId[electionId][party.partyAcronym] = 0;

        emit RegistrationRejected(_applicationIndex, party.partyName, party.partyAddress, _reason);
    }

    function addCandidateForNationalElection(
        uint256 _partyId,
        uint256 _electionId,
        string memory _candidateName,
        address _address
    ) external {
        if (_electionId != electionId) {
            revert NotCurrentElection();
        }

        uint256 registeredCount = registeredCountPerElection[electionId];

        if (_partyId == 0 || _partyId > registeredCount) {
            revert InvalidPartyId(_partyId, registeredCount);
        }

        CandidateCount++;

        partyCandidate[_partyId][_electionId] = CandidateStruct({
            PartyId: _partyId,
            CandidateId: CandidateCount,
            Name: _candidateName,
            Address: _address
        });

        emit CandidateAdded(CandidateCount, _partyId, _candidateName, _address);
    }

    function isPartyRegistered(string memory _party) external view returns (bool) {
        uint256 partyId = partyNameToId[electionId][_party];

        if (partyId == 0) {
            revert PartyNotRegistered(Status.pending);
        }

        Party[] storage parties = registeredPartiesPerElection[electionId];
        // find the party in registered list
        for (uint256 i = 0; i < parties.length; i++) {
            if (parties[i].id == partyId) {
                if (parties[i].status != Status.approved) {
                    revert PartyNotApproved(parties[i].status);
                }
                return true;
            }
        }

        revert PartyNotRegistered(Status.pending);
    }

    function getRegisteredPartyCount() external view returns (uint256) {
        return registeredCountPerElection[electionId];
    }

    function getCandidateCount() external view returns (uint256) {
        return CandidateCount;
    }

    function changeRegistrationFee(uint256 _newRegistrationFee) external onlyRole(DEFAULT_ADMIN_ROLE) {
        RegistrationFee = _newRegistrationFee;
    }
}
