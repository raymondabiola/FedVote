// SPDX-License-Identifier: MIT
pragma solidity  ^0.8.30;

import {AccessControl} from "../lib/openzeppelin-contracts/contracts/access/AccessControl.sol";

contract Registry is AccessControl {

    // state variables
    bytes32 public constant REGISTRATION_OFFICER_ROLE = keccak256("REGISTRATION_OFFICER_ROLE");
    address public headOfRegistrations;

    mapping(bytes32 => bool) private isValidNIN;
    mapping(address => bool) private isValidAddress;
    mapping(bytes32 => string) private validNameForNIN;
    mapping(bytes32 => address) private validAddressForNIN;

    struct RegisteredVoter{
            string name;
            address voterAddress;
            uint voterStreak;
            bool isRegistered;
            bool isAccredited;
    }

    mapping(bytes32 => RegisteredVoter) public registeredVoter;

    event VoterRegisteredOnChain(bytes32 indexed ninHash, address indexed voterAddress, string indexed name);
    event VoterAddressChanged(bytes32 ninHash, address indexed oldAddress, address indexed newAddress);

    error ArraysNotSameLength();
    error NINAlreadyAuthorized();
    error AddressAlreadyAuthorized();
    error ZeroAddressNotAllowed();
    error ContractAddressNotAllowed();
    error InvalidNIN();
    error InvalidGovernmentRegisteredFirstName();
    error AddressNotFoundInDataBase();
    error EmptyStringInputed();
    error CitizenCannotRegisterTwice();

    constructor(){
        headOfRegistrations = msg.sender;
        _grantRole(DEFAULT_ADMIN_ROLE, headOfRegistrations);
        _grantRole(REGISTRATION_OFFICER_ROLE, headOfRegistrations);
    }

    // authorizes batch of citizen information from the registration office database using saveral mappings
    function authorizeCitizensByBatch(bytes32[] calldata _ninHashes, string[] calldata _names, address[] calldata _addresses) external onlyRole(REGISTRATION_OFFICER_ROLE) {
        if(_ninHashes.length != _names.length && _ninHashes.length != _addresses.length){
            revert ArraysNotSameLength();
        }
        for(uint i = 0; i < _ninHashes.length; i++) {
            if(_addresses[i] == address(0)) revert ZeroAddressNotAllowed();
            if(isValidNIN[_ninHashes[i]]) revert NINAlreadyAuthorized();
            if(isValidAddress[_addresses[i]]) revert AddressAlreadyAuthorized();
            if(_addresses[i].code.length > 0) revert ContractAddressNotAllowed();
            isValidNIN[_ninHashes[i]] = true;
            isValidAddress[_addresses[i]] = true;
            validNameForNIN[_ninHashes[i]] = _names[i];
            validAddressForNIN[_ninHashes[i]] = _addresses[i];
        }
    }

    // Internal helper functions
    function getStringHash(string memory _text) internal pure returns(bytes32){
        return keccak256(abi.encodePacked(_text));
    }

    function getNumHash(uint _num) internal pure returns(bytes32){
        return keccak256(abi.encodePacked(_num));
    }

    /* safe voterSelfRegister even when an attacker is aware of a citizen NIN and name, they do not have the 
    private keys of the address registered in the offchain database. An address is accepted in the off-chain database 
    only if the citizen has passed KYC offchain.*/
    function voterSelfRegister(uint _nin, string memory _name) public {
        bytes32 ninHash = getNumHash(_nin);
        if(!isValidNIN[ninHash]){
            revert InvalidNIN();
        }

        if(bytes(_name).length == 0){
            revert EmptyStringInputed();
        }

        if(getStringHash(validNameForNIN[ninHash]) != getStringHash(_name)){
            revert InvalidGovernmentRegisteredFirstName();
        }
        if(validAddressForNIN[ninHash] != msg.sender){
            revert AddressNotFoundInDataBase();
        }

        if(registeredVoter[ninHash].isRegistered){
            revert CitizenCannotRegisterTwice();
        }

        RegisteredVoter memory newVoter = RegisteredVoter({
            name: _name,
            voterAddress: msg.sender,
            voterStreak: 0,
            isRegistered: true,
            isAccredited: false
        });

        registeredVoter[ninHash] = newVoter;
        emit VoterRegisteredOnChain(ninHash,msg.sender, _name);
    }

    /* Use function in the case when a voter misplaces their private keys for oldAddress.
        The citizen must go to the voter registration office to issue a complaint and provide a new address 
        that will replace the compromised address. 
        Registration_officer can only call this function after doing kyc checks off-chain. */
    function changeVoterAddress(uint _nin, address _newAddress)external onlyRole(REGISTRATION_OFFICER_ROLE){
        bytes32 ninHash = getNumHash(_nin);
        
        if(isValidAddress[_newAddress]) revert AddressAlreadyAuthorized();
        if(_newAddress == address(0)) revert ZeroAddressNotAllowed();
        if(_newAddress.code.length > 0) revert ContractAddressNotAllowed();
        if(!isValidNIN[ninHash]) revert InvalidNIN();
    
        address compromisedAddress = registeredVoter[ninHash].voterAddress;
        registeredVoter[ninHash].voterAddress = _newAddress;
        isValidAddress[_newAddress] = true;
        validAddressForNIN[ninHash] = _newAddress;
        emit VoterAddressChanged(ninHash, compromisedAddress, _newAddress);
    }

    // View Functions
    function getVoterRegistrationData(uint _nin) external view returns(RegisteredVoter memory){
            return registeredVoter[getNumHash(_nin)];
    }

    function getValidityOfNIN(uint _nin) external view returns(bool){
        return isValidNIN[getNumHash(_nin)];
    }

    function getValidityOfAddress(address _address) external view returns(bool){
        return isValidAddress[_address];
    }

    function getValidAddressForNIN(uint _nin) external view returns(address){
        return validAddressForNIN[getNumHash(_nin)];
    }
}