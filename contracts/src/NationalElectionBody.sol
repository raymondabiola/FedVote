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
    error PartyAlreadyRegistered(Status status);
    error PartyNotApproved(Status status);
    error PaymentFailed();
    error NotCurrentElection();

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
        Status status;
    }
    
    mapping(uint256 => mapping(uint256 => Party)) public appliedParties;
    mapping(uint256 => mapping(uint256 => Party)) public registeredParties;
    mapping(uint256 => mapping(uint256 => CandidateStruct)) public partyCandidate;
    mapping(uint256 => mapping(string => uint256)) public applicationPartyToId;
    mapping(string => uint256) public partyNameToId;
    mapping(uint256 => bool) public electionIdExist;

    uint256 PartyCount;
    uint256 RegisteredCount;
    uint256 CandidateCount;

    address tokenAddress;

    event Registration_Application(
        uint256 indexed applicationId,
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
    }

    function setElectionId(uint256 _electionId) public onlyRole(DEFAULT_ADMIN_ROLE) {
        require(!electionIdExist[_electionId], "ElectionId exists");

        electionId = _electionId;
        electionIdExist[_electionId] = true;
    }
    
    function RegisterParty(string memory _partyName, uint256 _electionId, string memory _partyAcronym, address _address) external {
        if (_electionId != electionId){
            revert NotCurrentElection();
        }
        require(applicationPartyToId[_electionId][_partyAcronym] == 0, "Already applied");

        bool success = nationalToken.transferFrom(_address, address(this), RegistrationFee);
        if (!success) {
            revert PaymentFailed();
        }
        if (partyNameToId[_partyAcronym] > 0) {
            uint256 existingPartyId = partyNameToId[_partyAcronym];

            Party memory party = Party({
            id: existingPartyId,
            partyName: _partyName,
            partyAddress: _address,
            partyAcronym: _partyAcronym,
            status: Status.pending
            });
            appliedParties[electionId][PartyCount] = party;
            applicationPartyToId[electionId][_partyAcronym] = PartyCount;
        }
        else {
            PartyCount++;
            
            Party memory party = Party({
            id: PartyCount,
            partyName: _partyName,
            partyAddress: _address,

            partyAcronym: _partyAcronym,
            status: Status.pending
            });

            appliedParties[electionId][PartyCount] = party;
            applicationPartyToId[electionId][_partyAcronym] = PartyCount;
        }
        
        

        emit Registration_Application(PartyCount, _partyName, _address, "Successfully applied");
    }

    function approveAppliedParty(string memory _partyAcronym) external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 _applicationId = applicationPartyToId[electionId][_partyAcronym];
        
        if (_applicationId == 0 || _applicationId > PartyCount) {
            revert InvalidPartyId(_applicationId, PartyCount);
        }

        
       
        Party storage party = appliedParties[electionId][_applicationId];

        if (party.status == Status.approved) {
            revert PartyAlreadyRegistered(party.status);
        }
        if (party.status == Status.rejected) {
            revert PartyNotRegistered(party.status);
        }

        party.status = Status.approved;

        // uint256 ppartyId = partyNameToId[_partyAcronym];
        // Party storage pparty = registeredParties[electionId][ppartyId];

        // pparty.status = Status.approved;

        uint256 partyid;

        if (partyNameToId[_partyAcronym] > 0) {
            uint256 existingPartyId = partyNameToId[_partyAcronym];

            
            
            // _party.status = Status.approved;

            Party storage _party = registeredParties[electionId][existingPartyId];
            _party.partyName = party.partyName;
            _party.partyAddress = party.partyAddress;
            _party.partyAcronym = party.partyAcronym;
            _party.status = Status.approved;
            _party.id = existingPartyId;

        }

        else {
            RegisteredCount++;
            partyid = RegisteredCount;

        }
            
            // Create the new registered party directly in storage
            Party storage pparty = registeredParties[electionId][partyid];

            pparty.id = partyid;
            pparty.partyName = party.partyName;
            pparty.partyAddress = party.partyAddress;
            pparty.partyAcronym = party.partyAcronym;
            pparty.status = Status.approved;

            partyNameToId[_partyAcronym] = partyid;

        emit PartyRegistered(pparty.id, pparty.partyName, pparty.partyAddress, "Successfully registered");
    }

    function rejectPartyRegistration(string memory _partyAcronym, string memory _reason) external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 _applicationId = applicationPartyToId[electionId][_partyAcronym];
        
        if (_applicationId == 0 || _applicationId > PartyCount) {
            revert InvalidPartyId(_applicationId, PartyCount);
        }

        Party storage party = appliedParties[electionId][_applicationId];

        if (party.status == Status.approved) {
            revert PartyAlreadyRegistered(party.status);
        }
        if (party.status == Status.rejected) {
            revert PartyNotRegistered(party.status);
        }

        party.status = Status.rejected;
        if (partyNameToId[_partyAcronym] > 0) {
            uint256 existingPartyId = partyNameToId[_partyAcronym];
            registeredParties[electionId][existingPartyId] = party; 
        }


    // refund the registration fee
        nationalToken.transfer(party.partyAddress, RegistrationFee);

    // clear the name so they can apply again
     //   applicationPartyToId[party.partyAcronym] = 0;


        emit RegistrationRejected(_applicationId, party.partyName, party.partyAddress, _reason);
    }

//     function addCandidateForNationalElection(uint256 _partyId, uint256 _electionId, string memory _candidateName, address _address) external {
//         if (_electionId != electionId) {
//             revert NotCurrentElection();
//         }

//         if (_partyId > RegisteredCount) {
//             revert InvalidPartyId(_partyId, RegisteredCount);
//         }
//         if (_partyId == 0) {
//             revert InvalidPartyId(_partyId, RegisteredCount);
//         }

//         CandidateCount++;
//         uint256 newCandidateCount = CandidateCount;

//         partyCandidate[_partyId][_electionId] = CandidateStruct({
//             PartyId: _partyId,
//             CandidateId: newCandidateCount,
//             Name: _candidateName,
//             Address: _address
//         });

//         emit CandidateAdded(newCandidateCount, _partyId, _candidateName, _address);
    
//     }

//     // function getNextElectionId() external returns (uint256){
//     //     ElectionId++;
//     //     nextElectionId = ElectionId;
//     //     return nextElectionId;
//     // }

//     function isPartyRegistered(string memory _party) external returns(bool) {
//         uint256 partyId = partyNameToId[_party];
        
//         if (partyId <= 0 || partyId > PartyCount) {
//             revert PartyNotRegistered(Status.pending);
//         }
//         Party storage party = registeredParties[partyId - 1];

//         if (party.status != Status.approved) {
//             revert PartyNotRegistered(party.status);
//         }
//         return true;
//     }

//     // function getPartyCandidate(string memory _party) external view returns (CandidateStruct memory) {
//     //     uint256 partyId = partyNameToId[_party];
//     //     CandidateStruct memory candidate = partyCandidate[partyId];
//     //     require(candidate.CandidateId != 0, "No candidate for this party");
//     //     return candidate;
//     // }

//     function getRegisteredPartyCount() external view returns (uint256) {
//         return RegisteredCount;
//     }

//     function getCandidateCount() external view returns (uint256) {
//         return CandidateCount;
//     }

//     function changeRegistrationFee(uint256 _newRegistrationFee) external {
//         RegistrationFee = _newRegistrationFee;
//     }

}