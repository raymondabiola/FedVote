// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {NationalToken} from "./NationalToken.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract NationalElectionBody is AccessControl, ReentrancyGuard {

    //  ROLES

    /// Access Granted to the party primaries contract
    bytes32 public constant PARTY_PRIMARIES_ROLE = keccak256("PARTY_PRIMARIES_ROLE");

    //  STATE

    NationalToken public nationalToken;

    uint256 public registrationFee = 10_000e18;

    uint256 public electionId;

    uint256 private PartyCount;

    //  ENUMS & STRUCTS

    enum Status { pending, approved, rejected }

    struct Party {
        uint256 id;
        string partyName;
        address partyAddress;
        string partyAcronym;
        uint256 feePaid;
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
    mapping(string => uint256) public partyAcronymToId;

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
    error InsufficientContractBal();
    error InvalidAmount();
    error InvalidAddress();
    error ElectionExists();
    error AlreadyAppliedForThisElection();

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
        nationalToken = NationalToken(_tokenAddress);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function updateNationalTokenCA(address _nationalToken) external onlyRole(DEFAULT_ADMIN_ROLE){
          if (_nationalToken == address(0)) revert InvalidAddress();
        nationalToken = NationalToken(_nationalToken);
    }

    function updateRegFee(uint _amount) external onlyRole(DEFAULT_ADMIN_ROLE){
        if(_amount == 0) revert InvalidAmount();
        registrationFee = _amount;
    }

    //  ELECTION ID

    function setElectionId(uint256 _electionId) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if(electionIdExist[_electionId])revert  ElectionExists();
        electionId = _electionId;
        electionIdExist[_electionId] = true;
    }

    //  PARTY REGISTRATION

    function registerParty(
        string memory _partyName,
        uint256 _electionId,
        string memory _partyAcronym
    ) external nonReentrant{
        if (_electionId != electionId) revert NotCurrentElection();

        if(applicationPartyToId[_electionId][_partyAcronym] != 0) revert AlreadyAppliedForThisElection();

        uint256 assignedPartyId;

        if (partyAcronymToId[_partyAcronym] > 0) {
            // Returning party: reuse permanent global ID
            assignedPartyId = partyAcronymToId[_partyAcronym];
        } else {
            // New party: mint a permanent ID
            PartyCount++;
            assignedPartyId = PartyCount;
            partyAcronymToId[_partyAcronym] = assignedPartyId;
        }

        Party memory party = Party({
            id:           assignedPartyId,
            partyName:    _partyName,
            partyAddress: msg.sender,
            partyAcronym: _partyAcronym,
            feePaid: registrationFee,
            status:       Status.pending
        });

        appliedParties[_electionId][assignedPartyId]        = party;
        applicationPartyToId[_electionId][_partyAcronym]    = assignedPartyId;

        bool success = nationalToken.transferFrom(msg.sender, address(this), registrationFee);
        if (!success) revert PaymentFailed();

        emit RegistrationApplication(assignedPartyId, _partyAcronym, msg.sender, "Successfully applied");
    }

    //  ADMIN: APPROVE

    // Approves a pending party application for the current election.
    function approveAppliedParty(string memory _partyAcronym, uint256 _electionId) external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 partyId = applicationPartyToId[_electionId][_partyAcronym];

        if (partyId == 0 || partyId > PartyCount) {
            revert InvalidPartyId(partyId, PartyCount);
        }

        Party storage application = appliedParties[_electionId][partyId];

        if (application.status == Status.approved) revert PartyAlreadyRegistered(application.status);
        if (application.status == Status.rejected)  revert PartyNotRegistered(application.status);

        application.status = Status.approved;

        Party storage registered = registeredParties[_electionId][partyId];
        registered.id           = partyId;
        registered.partyName    = application.partyName;
        registered.partyAddress = application.partyAddress;
        registered.partyAcronym = application.partyAcronym;
        registered.feePaid = application.feePaid;
        registered.status       = Status.approved;

        emit PartyRegistered(partyId, application.partyAcronym, application.partyAddress, "Successfully registered");
    }

    //  REJECT

    function rejectPartyRegistration(
        string memory _partyAcronym,
        uint256 _electionId,
        string memory _reason
    ) external onlyRole(DEFAULT_ADMIN_ROLE) nonReentrant {
        uint256 partyId = applicationPartyToId[_electionId][_partyAcronym];

        if (partyId == 0 || partyId > PartyCount) {
            revert InvalidPartyId(partyId, PartyCount);
        }

        Party storage application = appliedParties[_electionId][partyId];

        if (application.status == Status.approved) revert PartyAlreadyRegistered(application.status);
        if (application.status == Status.rejected)  revert PartyNotRegistered(application.status);

        application.status = Status.rejected;
        delete applicationPartyToId[_electionId][_partyAcronym];

        // Refund to the address that paid at application time
        bool success = nationalToken.transfer(application.partyAddress, application.feePaid);
        if (!success) revert PaymentFailed();

        emit RegistrationRejected(partyId, application.partyAcronym, application.partyAddress, _reason);
    }

    //  CANDIDATE MANAGEMENT

    function setCandidate(
        uint256 _electionId,
        string memory _candidateName,
        string memory _partyAcronym,
        address _candidateAddress
    ) external onlyRole(PARTY_PRIMARIES_ROLE) {
        uint256 partyId = partyAcronymToId[_partyAcronym];
        if(_electionId != electionId) revert NotCurrentElection();
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

    function withdraw(address _to, uint _amount) external onlyRole(DEFAULT_ADMIN_ROLE)nonReentrant{
        if(_to == address(0)) revert InvalidAddress();
        if(_amount == 0) revert InvalidAmount();
        if(_amount > nationalToken.balanceOf(address(this))) revert InsufficientContractBal();
        bool success = nationalToken.transfer(_to, _amount);
        if (!success) revert PaymentFailed();
    }

    //  VIEW FUNCTIONS
    function getElectionId() external view returns (uint256) {
        return electionId;
    }

    function getPartyCandidate(
        string memory _partyAcronym,
        uint256 _electionId
    ) external view returns (CandidateStruct memory) {
        uint256 partyId = partyAcronymToId[_partyAcronym];
        return partyCandidate[partyId][_electionId];
    }

    function isPartyRegistered(
        string memory _partyAcronym,
        uint256 _electionId
    ) external view returns (bool) {
        uint256 partyId = partyAcronymToId[_partyAcronym];
        if (partyId == 0) return false;
        return registeredParties[_electionId][partyId].status == Status.approved;
    }

    function getPartyCount() external view returns (uint256) {
        return PartyCount;
    }

    function checkIfElectionExist(uint _electionId) external view returns(bool){
        return electionIdExist[_electionId];
    }
}
