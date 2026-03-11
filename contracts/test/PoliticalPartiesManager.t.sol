// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {PoliticalPartyManager} from "../src/PoliticalPartiesManager.sol";
import {PoliticalPartiesManagerFactory} from "../src/PoliticalPartiesManager.sol";
import {NationalToken} from "../src/NationalToken.sol";

contract PoliticalPartyManagerTest is Test {
    PoliticalPartiesManagerFactory factory;
    PoliticalPartyManager partyManager;
    NationalToken nationalToken;


    address[] public partyManagers;

    address chairman = address(1);
    string partyName = "Apc";
    address tokenAddress = address(2);
    address electionBodyAddress = address(3);
    address registryAddress = address(4);
    address candidate = address(5);

    function setUp() public {
        factory = new PoliticalPartiesManagerFactory();
        factory.createNewPoliticalParty(chairman, partyName, tokenAddress, registryAddress);
        nationalToken = new NationalToken(registryAddress);
        partyManagers = factory.getAllPoliticalParty();
        partyManager = PoliticalPartyManager(partyManagers[0]);
    }

    function testcreateNewPoliticalParty() public {
        assertEq(partyManagers.length, 1);

        partyManager = PoliticalPartyManager(partyManagers[0]);
        assertEq(partyManager.chairman(), chairman);
        assertEq(partyManager.partyName(), "Apc");
        assertEq(address(partyManager.nationalToken()), tokenAddress);
        assertEq(address(partyManager.registry()), registryAddress);
        assertTrue(partyManager.hasRole(partyManager.DEFAULT_ADMIN_ROLE(), chairman));
        assertTrue(partyManager.hasRole(partyManager.PARTY_LEADER(), chairman));
    }

    function testAdminCanSetCandidacyFee() public {
        uint fee = 100 * (10 ** 18);
        vm.prank(chairman);
        partyManager.setCandidacyFee(fee);
        assertEq(partyManager.candidacyFee(), fee);
    }

    function testnonAdminCannotSetCandidacyFee() public {
        uint fee = 100 * (10 ** 18);
        address attacker = address(6);
        vm.prank(attacker);
        vm.expectRevert();
        partyManager.setCandidacyFee(fee);
    }

    function testFeeCannotBeZero() public {
        uint fee = 0;
        vm.prank(chairman);
        vm.expectRevert();
        partyManager.setCandidacyFee(fee);
    }

    function testOnlyMemberCanPayForCandidacy() public {
        uint fee = 100 * (10 ** 18); 
        address attacker = address(6);
        vm.prank(registryAddress);
        nationalToken.mint(attacker, 1000 * (10 ** 18) );
        vm.prank(attacker);
        nationalToken.approve(address(partyManager), fee);
        vm.prank(attacker);
        vm.expectRevert();
        partyManager.setCandidacyFee(fee);
    }
    
    // function onlyEOACanPayForCandidacy() public {
    //     uint fee = 1 ether;
         
    // }

    // function testMember
}