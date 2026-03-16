// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {NationalToken} from "./NationalToken.sol";

contract NationalElectionBody is AccessControl {

    //  ROLES

    /// Access Granted to the party primaries contract
    bytes32 public constant PARTY_PRIMARIES_ROLE = keccak256("PARTY_PRIMARIES_ROLE");

    //  STATE

    NationalToken public nationalToken;
    address private tokenAddress;

    uint256 public RegistrationFee = 10_000e18;

    uint256 public electionId;

    uint256 private PartyCount;

    //  ENUMS & STRUCTS

    enum Status { pending, approved, rejected }

    struct Party {
        uint256 id;
        string partyName;
        address partyAddress;
        string partyAcronym;
        Status status;
    }

    struct CandidateStruct {
        uint256 PartyId;
        string Name;
        string PartyAcronym;
        address Address;
    }

    //  MAPPINGS

    // electionId => partyId => pending application
    mapping(uint256 => mapping(uint256 => Party)) public appliedParties;

    // electionId => partyId => approved registration record
    mapping(uint256 => mapping(uint256 => Party)) public registeredParties;

    // electionId => partyAcronym => partyId  (application lookup)
    mapping(uint256 => mapping(string => uint256)) public applicationPartyToId;

    // partyAcronym => permanent global partyId (never changes across elections)
    mapping(string => uint256) public partyNameToId;

    // partyId => electionId => candidate struct
    mapping(uint256 => mapping(uint256 => CandidateStruct)) public partyCandidate;

    // Prevents the same election ID being set twice
    mapping(uint256 => bool) public electionIdExist;

    //  ERRORS

    error InvalidPartyId(uint256 providedId, uint256 maxId);
    error PartyNotRegistered(Status status);
    error PartyAlreadyRegistered(Status status);
    error PartyNotApproved(Status status);
    error PaymentFailed();
    error NotCurrentElection();

    //  EVENTS

    event RegistrationApplication(
        uint256 indexed partyId,
        string partyAcronym,
        address indexed partyAddress,
        string message
    );

    event PartyRegistered(
        uint256 indexed partyId,
        string partyAcronym,
        address indexed partyAddress,
        string message
    );

    event RegistrationRejected(
        uint256 indexed partyId,
        string partyAcronym,
        address indexed partyAddress,
        string reason
    );

    event CandidateSet(
        uint256 indexed partyId,
        uint256 indexed forElectionId,
        string candidateName,
        address candidateAddress
    );

    //  CONSTRUCTOR

    constructor(address _tokenAddress) {
        tokenAddress = _tokenAddress;
        nationalToken = NationalToken(tokenAddress);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    //  ELECTION ID

    function setElectionId(uint256 _electionId) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(!electionIdExist[_electionId], "ElectionId already exists");
        electionId = _electionId;
        electionIdExist[_electionId] = true;
    }

    //  PARTY REGISTRATION

    function registerParty(
        string memory _partyName,
        uint256 _electionId,
        string memory _partyAcronym
    ) external {
        if (_electionId != electionId) revert NotCurrentElection();

        require(
            applicationPartyToId[_electionId][_partyAcronym] == 0,
            "Already applied for this election"
        );

        bool success = nationalToken.transferFrom(msg.sender, address(this), RegistrationFee);
        if (!success) revert PaymentFailed();

        uint256 assignedPartyId;

        if (partyNameToId[_partyAcronym] > 0) {
            // Returning party: reuse permanent global ID
            assignedPartyId = partyNameToId[_partyAcronym];
        } else {
            // New party: mint a permanent ID
            PartyCount++;
            assignedPartyId = PartyCount;
            partyNameToId[_partyAcronym] = assignedPartyId;
        }

        Party memory party = Party({
            id:           assignedPartyId,
            partyName:    _partyName,
            partyAddress: msg.sender,
            partyAcronym: _partyAcronym,
            status:       Status.pending
        });

        appliedParties[_electionId][assignedPartyId]        = party;
        applicationPartyToId[_electionId][_partyAcronym]    = assignedPartyId;

        emit RegistrationApplication(assignedPartyId, _partyAcronym, msg.sender, "Successfully applied");
    }

    //  ADMIN: APPROVE

    // Approves a pending party application for the current election.
    function approveAppliedParty(string memory _partyAcronym) external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 partyId = applicationPartyToId[electionId][_partyAcronym];

        if (partyId == 0 || partyId > PartyCount) {
            revert InvalidPartyId(partyId, PartyCount);
        }

        Party storage application = appliedParties[electionId][partyId];

        if (application.status == Status.approved) revert PartyAlreadyRegistered(application.status);
        if (application.status == Status.rejected)  revert PartyNotRegistered(application.status);

        application.status = Status.approved;

        Party storage registered = registeredParties[electionId][partyId];
        registered.id           = partyId;
        registered.partyName    = application.partyName;
        registered.partyAddress = application.partyAddress;
        registered.partyAcronym = application.partyAcronym;
        registered.status       = Status.approved;

        emit PartyRegistered(partyId, application.partyAcronym, application.partyAddress, "Successfully registered");
    }

    //  REJECT

    function rejectPartyRegistration(
        string memory _partyAcronym,
        string memory _reason
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 partyId = applicationPartyToId[electionId][_partyAcronym];

        if (partyId == 0 || partyId > PartyCount) {
            revert InvalidPartyId(partyId, PartyCount);
        }

        Party storage application = appliedParties[electionId][partyId];

        if (application.status == Status.approved) revert PartyAlreadyRegistered(application.status);
        if (application.status == Status.rejected)  revert PartyNotRegistered(application.status);

        application.status = Status.rejected;

        // Refund to the address that paid at application time
        nationalToken.transfer(application.partyAddress, RegistrationFee);

        emit RegistrationRejected(partyId, application.partyAcronym, application.partyAddress, _reason);
    }

    //  CANDIDATE MANAGEMENT

    function setCandidate(
        uint256 _electionId,
        string memory _candidateName,
        string memory _partyAcronym,
        address _candidateAddress
    ) external onlyRole(PARTY_PRIMARIES_ROLE) {
        uint256 partyId = partyNameToId[_partyAcronym];
        if (partyId == 0) revert InvalidPartyId(partyId, PartyCount);

        // Party must be approved for this specific election before a candidate can be set
        Party storage registered = registeredParties[_electionId][partyId];
        if (registered.status != Status.approved) revert PartyNotApproved(registered.status);

        partyCandidate[partyId][_electionId] = CandidateStruct({
            PartyId:      partyId,
            Name:         _candidateName,
            PartyAcronym: _partyAcronym,
            Address:      _candidateAddress
        });

        emit CandidateSet(partyId, _electionId, _candidateName, _candidateAddress);
    }

    //  VIEW FUNCTIONS
    function getElectionId() external view returns (uint256) {
        return electionId;
    }

    function getPartyCandidate(
        string memory _partyAcronym,
        uint256 _electionId
    ) external view returns (CandidateStruct memory) {
        uint256 partyId = partyNameToId[_partyAcronym];
        return partyCandidate[partyId][_electionId];
    }

    function isPartyRegistered(
        string memory _partyAcronym,
        uint256 _electionId
    ) external view returns (bool) {
        uint256 partyId = partyNameToId[_partyAcronym];
        if (partyId == 0) return false;
        return registeredParties[_electionId][partyId].status == Status.approved;
    }

    function getPartyCount() external view returns (uint256) {
        return PartyCount;
    }
}
