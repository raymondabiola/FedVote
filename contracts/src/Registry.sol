// SPDX-License-Identifier: MIT
pragma solidity  ^0.8.30;

import {AccessControl} from "../lib/openzeppelin-contracts/contracts/access/AccessControl.sol";

contract Registry is AccessControl{

//state variables
bytes32 public constant REGISTRATION_OFFICER_ROLE = keccak256("REGISTRATION_OFFICER_ROLE");
address public headOfRegistrations;

mapping(bytes32 => bool) private isValidNIN;
mapping(bytes32 => string) private validNameForNIN;
mapping(bytes32 => address) private validAddressForNIN;

    struct RegisteredVoter{
        string name;
        address voterAddress;
        uint voterStreak;
        bool isAddressUsed;
        bool isRegistered;
        bool isAccredited;
    }

    // Mappings declaration
    mapping(bytes32 => RegisteredVoter) public registeredVoter;

    event VoterRegisteredOnChain(bytes32 indexed ninHash, address indexed voterAddress, string indexed name);
    event VoterAddressChanged(bytes32 ninHash, address indexed oldAddress, address indexed newAddress);

    error ArraysNotSameLength();
    error ZeroAddressNotAllowed();
    error ContractAddressNotAllowed();
    error InvalidNIN();
    error InvalidGovernmentRegisteredFirstName();
    error AddressNotFoundInDataBase();
    error EmptyStringInputed();
    error CitizenCannotRegisterTwice();
    error AddressAlreadyUsed();

    constructor(){
        headOfRegistrations = msg.sender;
        _grantRole(DEFAULT_ADMIN_ROLE, headOfRegistrations);
        _grantRole(REGISTRATION_OFFICER, headOfRegistrations);
    }

    // authorizes batch of citizen information using saveral mappings
    function authorizeCitizensByBatch(bytes32[] calldata _ninHashes, string[] calldata _names, address[] calldata _addresses) external onlyRole(REGISTRATION_OFFICER_ROLE) {
    if(_ninHashes.length != _names.length && _ninHashes.length != _addresses.length){
        revert ArraysNotSameLength();
    }
    for(uint i = 0; i < _ninHashes.length; i++) {
        if(_addresses[i] == address(0)){
            revert ZeroAddressNotAllowed();
        }
        if(_addresses[i].code.length > 0){
            revert ContractAddressNotAllowed();
        }
        isValidNIN[_ninHashes[i]] = true;
        validNameForNIN[_ninHashes[i]] = _names[i];
        validAddressForNIN[_ninHashes[i]] = _addresses[i];
    }
    }

    function getStringHash(string memory _text) internal pure returns(bytes32){
        return keccak256(abi.encodePacked(_text));
    }

    function getNumHash(uint _num) internal pure returns(bytes32){
        return keccak256(abi.encodePacked(_num));
    }

    /* voterSelfRegister is safe because if someone is aware of a citizen NIN, they do not have the 
     private keys of the address registered in offchain database. The address are only accepted in 
    off-chain data base after the citizen has passed KYC offchain.*/
    function voterSelfRegister(uint _nin, string memory _name) public {
        bytes32 ninHash = getNumHash(_nin);
        if(!isValidNIN[ninHash]){
            revert InvalidNIN();
        }
        if(getStringHash(validNameForNIN[ninHash]) != getStringHash(_name)){
            revert InvalidGovernmentRegisteredFirstName();
        }
        if(validAddressForNIN[ninHash] != msg.sender){
            revert AddressNotFoundInDataBase();
        }
        if(bytes(_name).length == 0){
            revert EmptyStringInputed();
        }
        if(registeredVoter[ninHash].isRegistered){
            revert CitizenCannotRegisterTwice();
        }
        if(registeredVoter[ninHash].isAddressUsed){
            revert AddressAlreadyUsed();
        }


        RegisteredVoter memory newVoter = RegisteredVoter({
            name: _name,
            voterAddress: msg.sender,
            voterStreak: 0,
            isAddressUsed: true,
            isRegistered: true,
            isAccredited: false
        });

        // Do we reset streak count after streak has been broken.

        registeredVoter[ninHash] = newVoter;
        emit VoterRegisteredOnChain(ninHash,msg.sender, _name);
        }

        /* Use function in the case when a voter misplaces their private keys for oldAddress.
         Citizen has to go to voter registration office to make complaint and provide a new address 
         that will replace the old address. 
         Registration_officer can only call this function after doing kyc checks off-chain. */
        function changeVoterAddress(uint _nin, address _newAddress)external onlyRole(REGISTRATION_OFFICER_ROLE){
        bytes32 ninHash = getNumHash(_nin);
        
        if(_newAddress == address(0)){
            revert ZeroAddressNotAllowed();
        }
        if(_newAddress.code.length > 0){
            revert ContractAddressNotAllowed();
        }
        if(!isValidNIN[ninHash]){
            revert InvalidNIN();
        }
    
        address oldAddress = registeredVoter[ninHash].voterAddress;
        registeredVoter[ninHash].voterAddress = _newAddress;
        emit VoterAddressChanged(ninHash, oldAddress, _newAddress);
        }

        function getVoterRegistrationData(uint _nin) external view returns(RegisteredVoter memory){
            return registeredVoter[getNumHash(_nin)];
        }

        function getValidityOfNIN(uint _nin) external view returns(bool){
            return isValidNIN[getNumHash(_nin)];
        }
}