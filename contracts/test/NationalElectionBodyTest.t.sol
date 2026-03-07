//SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {NationalToken} from "../src/NationalToken.sol";
import {NationalElectionBody} from "../src/NationalElectionBody.sol";

contract NationalElectionBodyTest is Test {
    NationalElectionBody public electionBody;
     NationalToken public token;

    address public admin = makeAddr("admin");
    address public partyAddress1 = makeAddr("firstPartyAddress");
    address public partyAddress2 = makeAddr("secondPartyAddress");
    address public partyAddress3 = makeAddr("thirdPartyAddress");
    address public partyChairman = makeAddr("partyChairman");
    address centralBank = makeAddr("centralBank");

    uint256 constant REGISTRATION_FEE = 10_000e18;

    function setUp() public {
        // centralBank deploys token
        vm.startPrank(centralBank);
        token = new NationalToken(centralBank);
        token.mint(partyAddress1, REGISTRATION_FEE);
        token.mint(partyAddress2, REGISTRATION_FEE);
        token.mint(partyAddress3, REGISTRATION_FEE);
        vm.stopPrank();

        
        vm.startPrank(admin);
        electionBody = new NationalElectionBody(address(token));
        electionBody.grantChairmanRole(partyChairman);
        vm.stopPrank();

        vm.prank(partyAddress1);
        token.approve(address(electionBody), type(uint256).max);

        vm.prank(partyAddress2);
        token.approve(address(electionBody), type(uint256).max);

        vm.prank(partyAddress3);
        token.approve(address(electionBody), type(uint256).max);
    }

    function  _registerParty(string memory name, string memory acronym, string memory chairman, address addr) internal returns (uint256 partyId) {
        vm.prank(addr);
        electionBody.RegisterParty(name, chairman, acronym, addr);
        partyId = electionBody.partyNameToId(name);
    }

    function test_deployment() public {
        assertEq(address(electionBody.nationalToken()), address(token));
    }

    function
    function test_PartyIdsAreCorrect() public {
       uint256 partyId1 = _registerParty("Peoples Democratic Party", "PDP", "Dr. Kabiru Tanimu Turaki", partyAddress1);
       uint256 partyId2 = _registerParty("APC",    "APC", "Jane", partyAddress2);
       uint256 partyId3 = _registerParty("PDP",    "PDP", "Bob",  partyAddress3);

       assertEq(partyId1, 1);
       assertEq(partyId2, 2);
       assertEq(partyId3, 3);
       assertEq(electionBody.getPartyCount(), 3);
    }
}