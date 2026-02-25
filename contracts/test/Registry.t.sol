// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

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

    bytes32[] ninHashes;
    string[] names;
    address[] addresses;

function setUp() public {
    owner = address(this);
    zeroAddress = address(0);
    user1 = vm.addr(pKey);
    user2 = makeAddr("user2");
    user3 = vm.addr(pKey2);

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
ninHashes[0] = getNumHash(2345);
ninHashes[1] = getNumHash(3388);
ninHashes[2] = getNumHash(8871);

names[0] = "Alice";
names[1] = "Bob";
names[2] = "Ben";

addresses[0] = user1;
addresses[1] = user2;
addresses[2] = user3;
vm.prank(owner);
registry.authorizeCitizensByBatch(ninHashes, names, addresses);

}

function testAuthorizeCitizensByBatch() public {

simulateArrayPopulate();
assertTrue(registry.getValidityOfNIN(2345));
assertTrue(registry.getValidityOfNIN(3388));
assertTrue(registry.getValidityOfNIN(8871));

}

function testVoterSelfRegister() public {

}

function testGetVoterRegistrationData() public {

}

function testGetValidityOfNIN() public {

}
}