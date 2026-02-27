// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import "../src/Registry.sol";
import "../script/AuthorizeCitizens.s.sol";

contract RegistryTest is Test {
    Registry public registry;
    address public owner;
    address public zeroAddress;
    uint256 pKey = 0x450802246;
    uint256 pKey2 = 0xF333BB;
    address public user1;
    address public user2;
    address public user3;
    address public user4;

    bytes32[] ninHashes;
    string[] names;
    address[] addresses;

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
    error AccessControlUnauthorizedAccount(address account, bytes32 neededRole);

function setUp() public {
    owner = address(this);
    zeroAddress = address(0);
    user1 = vm.addr(pKey);
    user2 = makeAddr("user2");
    user3 = vm.addr(pKey2);
    user4 = makeAddr("user4");

    registry = new Registry();
}

function testHeadOfRegistrations() public {
    assertEq(owner, registry.headOfRegistrations());
}

function getStringHash(string memory _text) internal pure returns(bytes32){
        return keccak256(abi.encodePacked(_text));
}

function getNumHash(uint _num) internal pure returns(bytes32){
        return keccak256(abi.encodePacked(_num));
}

function simulateArrayPopulate() internal {
ninHashes = new bytes32[](3);
names = new string[](3);
addresses = new address[](3);
ninHashes[0] = getNumHash(2345);
ninHashes[1] = getNumHash(3388);
ninHashes[2] = getNumHash(8871);

names[0] = "Alice";
names[1] = "Bob";
names[2] = "Ben";

addresses[0] = user1;
addresses[1] = user2;
addresses[2] = user3;

registry.authorizeCitizensByBatch(ninHashes, names, addresses);
}

function testAuthorizeCitizensByBatch() public {
simulateArrayPopulate();
assertTrue(registry.getValidityOfNIN(2345));
assertTrue(registry.getValidityOfNIN(3388));
assertTrue(registry.getValidityOfNIN(8871));
assertEq(registry.getValidAddressForNIN(8871), user3);
assertTrue(registry.getValidityOfAddress(user2));
}

function testVoterSelfRegister() public {
simulateArrayPopulate();

// Edge case test for a valid citizen tries to register with an Invalid NIN
vm.prank(user1);
vm.expectRevert(InvalidNIN.selector);
registry.voterSelfRegister(2346, "Alice");

//Edge case test for when a valid citizen tries to register with an Invalid government registered first name 
vm.prank(user1);
vm.expectRevert(InvalidGovernmentRegisteredFirstName.selector);
registry.voterSelfRegister(2345, "Aliee");

// Edge case test for a wrong address trying to register with a valid voter information leak.
vm.prank(user4);
vm.expectRevert(AddressNotFoundInDataBase.selector);
registry.voterSelfRegister(2345, "Alice");

// Edge case for when a valid citizen tries to register with an empty string.
vm.prank(user1);
vm.expectRevert(EmptyStringInputed.selector);
registry.voterSelfRegister(2345, "");

// Test if data of successful registration is correct.
vm.prank(user1);
registry.voterSelfRegister(2345, "Alice");
assertEq(registry.getVoterRegistrationData(2345).voterAddress, user1);
assertEq(registry.getVoterRegistrationData(2345).voterStreak, 0);
assertTrue(registry.getVoterRegistrationData(2345).isRegistered);
assertFalse(registry.getVoterRegistrationData(2345).isAccredited);

// Edge case for when a valid citizen tries to register twice.
vm.prank(user1);
vm.expectRevert(CitizenCannotRegisterTwice.selector);
registry.voterSelfRegister(2345, "Alice");

}

function testChangeVoterAddress() public {
    simulateArrayPopulate();
    bytes32 registrationOfficer = registry.REGISTRATION_OFFICER_ROLE();

    vm.prank(user1);
    registry.voterSelfRegister(2345, "Alice");

    // Edge case test for when a user without the registration officer role tries to call the changeVoterAddress function
    vm.prank(user2);
    vm.expectRevert(
        abi.encodeWithSelector(
            AccessControlUnauthorizedAccount.selector,
            user2,
            registrationOfficer
        )
    );
    registry.changeVoterAddress(2345, user4);

    registry.grantRole(registrationOfficer, user3);

    // Edge case test for when a registration officer tries to change voter address to an already Authorized Address.
    vm.startPrank(user3);
    vm.expectRevert(AddressAlreadyAuthorized.selector);
    registry.changeVoterAddress(2345, user1);

    // Edge case for when a zero address is passed into the change voter address function
    vm.expectRevert(ZeroAddressNotAllowed.selector);
    registry.changeVoterAddress(2345, zeroAddress);

    // Edge case for when a contract address is passed into the change voter address function
    vm.expectRevert(ContractAddressNotAllowed.selector);
    registry.changeVoterAddress(2345, address(registry));

    // Edge case for when an invalid NIN is passed into the change voter address function
    vm.expectRevert(InvalidNIN.selector);
    registry.changeVoterAddress(2346, user4);

    // Tests for when the changeVoterAddres function is correctly called
    registry.changeVoterAddress(2345, user4);
    assertEq(registry.getVoterRegistrationData(2345).voterAddress, user4);
    assertTrue(registry.getValidityOfAddress(user4));
    assertEq(registry.getValidAddressForNIN(2345), user4);
    vm.stopPrank();
}

function testGrantRegistrationOfficerRole() public {
    bytes32 registrationOfficer = registry.REGISTRATION_OFFICER_ROLE();
    assertFalse(registry.hasRole(registrationOfficer, user1));
    registry.grantRole(registrationOfficer, user1);
    assertTrue(registry.hasRole(registrationOfficer, user1));
}
}