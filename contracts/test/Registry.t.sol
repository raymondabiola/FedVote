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
    error NINAlreadyAuthorized(bytes32 ninHash);
    error AddressAlreadyAuthorized(address addr);
    error ZeroAddressNotAllowed();
    error NotARegisteredVoter();
    error ContractAddressNotAllowed(address addr);
    error InvalidNIN();
    error AlreadyAPartyMember();
    error NotAPartyMember();
    error InvalidGovernmentRegisteredFirstName(string governmentRegisteredFirstName, string inputedName);
    error NINNotFoundInDataBase();
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
assertEq(registry.getValidNINHashForAddress(user3), ninHashes[2]);
assertTrue(registry.getValidityOfAddress(user2));


ninHashes = new bytes32[](3);
names = new string[](3);
addresses = new address[](2);
ninHashes[0] = getNumHash(2345);
ninHashes[1] = getNumHash(3388);
ninHashes[2] = getNumHash(8871);

names[0] = "Alice";
names[1] = "Bob";
names[2] = "Ben";

addresses[0] = user1;
addresses[1] = user2;

vm.expectRevert(ArraysNotSameLength.selector);
registry.authorizeCitizensByBatch(ninHashes, names, addresses);

ninHashes = new bytes32[](1);
names = new string[](1);
addresses = new address[](1);

ninHashes[0] = getNumHash(2345);
names[0] = "Alice";
addresses[0] = zeroAddress;
vm.expectRevert(ZeroAddressNotAllowed.selector);
registry.authorizeCitizensByBatch(ninHashes, names, addresses);

ninHashes = new bytes32[](1);
names = new string[](1);
addresses = new address[](1);

ninHashes[0] = getNumHash(2345);
names[0] = "Bisi";
addresses[0] = user4;

vm.expectRevert(
    abi.encodeWithSelector(
        NINAlreadyAuthorized.selector,
        ninHashes[0]
    )
    );
registry.authorizeCitizensByBatch(ninHashes, names, addresses);

ninHashes = new bytes32[](1);
names = new string[](1);
addresses = new address[](1);

ninHashes[0] = getNumHash(2399);
names[0] = "Alice";
addresses[0] = user1;

vm.expectRevert(
    abi.encodeWithSelector(
        AddressAlreadyAuthorized.selector,
        addresses[0]
    )
    );
registry.authorizeCitizensByBatch(ninHashes, names, addresses);

ninHashes = new bytes32[](1);
names = new string[](1);
addresses = new address[](1);

ninHashes[0] = getNumHash(2399);
names[0] = "Alice";
addresses[0] = address(this);

vm.expectRevert(
    abi.encodeWithSelector(
        ContractAddressNotAllowed.selector,
        addresses[0]
    )
    );
registry.authorizeCitizensByBatch(ninHashes, names, addresses);
}

function testIncrementVoterStreak() public {
    simulateArrayPopulate();
        bytes32 electionsContractRole = registry.ELECTIONS_CONTRACT_ROLE();
        registry.grantRole(electionsContractRole, owner);

        registry.incrementVoterStreak(user1);
        assertEq(registry.getVoterDataViaAddress(user1).voterStreak, 1);
}

function testResetVoterStreak() public {
    simulateArrayPopulate();
        bytes32 electionsContractRole = registry.ELECTIONS_CONTRACT_ROLE();
        registry.grantRole(electionsContractRole, owner);

        registry.incrementVoterStreak(user1);
        registry.incrementVoterStreak(user1);
        registry.resetVoterStreak(user1);
        assertEq(registry.getVoterDataViaAddress(user1).voterStreak, 1);
}

function testSetCitizenPartyMembershipStatus() public {
    simulateArrayPopulate();

        bytes32 electionsContractRole = registry.ELECTIONS_CONTRACT_ROLE();
        registry.grantRole(electionsContractRole, owner);
        bytes32 partyContractRole = registry.PARTY_CONTRACT_ROLE();
        registry.grantRole(partyContractRole, owner);

        registry.setCitizenPartyMembershipStatusAsTrue(2345);
        assertTrue(registry.checkIfCitizenIsPartyMember(2345));

        vm.expectRevert(AlreadyAPartyMember.selector);
        registry.setCitizenPartyMembershipStatusAsTrue(2345);

        registry.setCitizenPartyMembershipStatusAsFalse(2345);
        assertFalse(registry.checkIfCitizenIsPartyMember(2345));

        vm.expectRevert(NotAPartyMember.selector);
        registry.setCitizenPartyMembershipStatusAsFalse(2345);

        // registry.incrementVoterStreak(user1);
        // registry.resetVoterStreak(user1);
        // assertEq(registry.getVoterDataViaAddress(user1).voterStreak, 0);

        vm.expectRevert(InvalidNIN.selector);
        registry.setCitizenPartyMembershipStatusAsTrue(2399);

                vm.expectRevert(InvalidNIN.selector);
        registry.setCitizenPartyMembershipStatusAsFalse(2399);
}

function testVoterSelfRegister() public {
simulateArrayPopulate();

// Edge case test for a valid citizen tries to register with an Invalid NIN
vm.prank(user1);
vm.expectRevert(InvalidNIN.selector);
registry.voterSelfRegister(2346, "Alice");

//Edge case test for when a valid citizen tries to register with an Invalid government registered first name 
vm.prank(user1);
vm.expectRevert(
    abi.encodeWithSelector(
            InvalidGovernmentRegisteredFirstName.selector,
            "Alice",
            "Aliee"
        )
    );
registry.voterSelfRegister(2345, "Aliee");

// Edge case test for a wrong address trying to register with a valid voter information leak.
vm.prank(user4);
vm.expectRevert(
        abi.encodeWithSelector(
            NINNotFoundInDataBase.selector,
            user4
        )
    );
registry.voterSelfRegister(2345, "Alice");

// Edge case for when a valid citizen tries to register with an empty string.
vm.prank(user1);
vm.expectRevert(EmptyStringInputed.selector);
registry.voterSelfRegister(2345, "");

// Test if data of successful registration is correct.
vm.prank(user1);
registry.voterSelfRegister(2345, "Alice");
assertEq(registry.getVoterDataViaNIN(2345).voterAddress, user1);
assertEq(registry.getVoterDataViaNIN(2345).voterStreak, 0);
assertTrue(registry.getVoterDataViaNIN(2345).isRegistered);

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
    vm.expectRevert(
        abi.encodeWithSelector(
            AddressAlreadyAuthorized.selector,
            user2
        )
    );
    registry.changeVoterAddress(2345, user2);

    // Edge case for when a zero address is passed into the change voter address function
    vm.expectRevert(ZeroAddressNotAllowed.selector);
    registry.changeVoterAddress(2345, zeroAddress);

    // Edge case for when a contract address is passed into the change voter address function
    vm.expectRevert(
        abi.encodeWithSelector(
            ContractAddressNotAllowed.selector,
            address(registry)
        )
    );
    registry.changeVoterAddress(2345, address(registry));

    // Edge case for when an invalid NIN is passed into the change voter address function
    vm.expectRevert(InvalidNIN.selector);
    registry.changeVoterAddress(2346, user4);

    // Tests for when the changeVoterAddres function is correctly called
    assertEq(registry.getValidNINHashForAddress(user1), ninHashes[0]);
    registry.changeVoterAddress(2345, user4);
    assertEq(registry.getVoterDataViaNIN(2345).voterAddress, user4);
    assertTrue(registry.getValidityOfAddress(user4));
    assertEq(registry.getValidNINHashForAddress(user1), 0x0000000000000000000000000000000000000000000000000000000000000000);
    assertEq(registry.getValidNINHashForAddress(user4), ninHashes[0]);
    vm.stopPrank();
}

function testGrantRegistrationOfficerRole() public {
    bytes32 registrationOfficer = registry.REGISTRATION_OFFICER_ROLE();
    assertFalse(registry.hasRole(registrationOfficer, user1));
    registry.grantRole(registrationOfficer, user1);
    assertTrue(registry.hasRole(registrationOfficer, user1));
}
}