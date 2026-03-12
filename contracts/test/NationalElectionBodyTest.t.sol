//SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import "forge-std/console.sol";
import {NationalToken} from "../src/NationalToken.sol";
import {NationalElectionBody} from "../src/NationalElectionBody1.sol";

contract NationalElectionBodyTest is Test {
    NationalElectionBody public electionBody;
    NationalToken public token;

    uint256 applicationId1;
    uint256 applicationId2;
    uint256 applicationId3;
    uint256 applicationId4;
    uint256 applicationId5;
    uint256 applicationId6;
    uint256 firstElectionId;
    uint256 secondElectionId;
    uint256 newRegistrationFee;

    uint256 partyId1;
    uint256 partyId2;
    uint256 partyId3;
    uint256 balanceBefore;
    uint256 balanceAfter;

    address public admin = makeAddr("admin");
    address public pdpAddress = makeAddr("firstPartyAddress");
    address public lpAddress = makeAddr("secondPartyAddress");
    address public apcAddress = makeAddr("thirdPartyAddress");
    address public emptyAddress = makeAddr("emptyPartyAddress");
    address public apgaAddress = makeAddr("apgaAddress");
    address public pdpCandidateAddress = makeAddr("pdpCandidateAddress");
    address public apcCandidateAddress = makeAddr("apcCandidateAddress");
    address public lpCandidateAddress = makeAddr("lpCandidateAddress");
    address public PartyChairman = makeAddr("partyChairman");
    address centralBank = makeAddr("centralBank");

    uint256 constant REGISTRATION_FEE = 10_000e18;

    function setUp() public {
        vm.startPrank(centralBank);
        token = new NationalToken(centralBank);
        token.mint(pdpAddress, REGISTRATION_FEE * 10);
        token.mint(lpAddress, REGISTRATION_FEE * 10);
        token.mint(apcAddress, REGISTRATION_FEE * 10);
        token.mint(apgaAddress, REGISTRATION_FEE * 10);
        vm.stopPrank();

        
        vm.startPrank(admin);
        electionBody = new NationalElectionBody(address(token));
        //electionBody.grantChairmanRole(PartyChairman);
        electionBody.setElectionId(1);
        vm.stopPrank();

        vm.prank(pdpAddress);
        token.approve(address(electionBody), type(uint256).max);

        vm.prank(lpAddress);
        token.approve(address(electionBody), type(uint256).max);

        vm.prank(apcAddress);
        token.approve(address(electionBody), type(uint256).max);

        vm.prank(apgaAddress);
        token.approve(address(electionBody), type(uint256).max);
        

        applicationId1 = _registerParty("Peoples Democratic Party", 1, "PDP", pdpAddress);
        applicationId2 = _registerParty("Labour Party", 1, "LP", lpAddress);
        applicationId3 = _registerParty("All Progressives Congress", 1, "APC",  apcAddress);
        
    }

    function  _registerParty(string memory name, uint256 electionId, string memory acronym, address addr) internal returns (uint256 applicationId) {
        vm.prank(addr);
        electionBody.RegisterParty(name, electionId, acronym, addr);
        applicationId = electionBody.applicationPartyToId(1, acronym);
    }

    function test_deployment() public {
        assertEq(address(electionBody.nationalToken()), address(token));
    }

    function test_successful_registration_application() public {
       //assertEq(applicationId1, 1);
       vm.expectRevert();
       // Already applied
       applicationId1 = _registerParty("Peoples Democratic Party", 1, "PDP", pdpAddress);
       
       vm.expectRevert();
       applicationId4 = _registerParty("New Nigeria Peoples Party", 2, "NNPP",  emptyAddress);

       vm.prank(admin);
       electionBody.approveAppliedParty("LP");
       uint256 _id = electionBody.partyNameToId("LP");
       console.log("LP: ", _id);

       vm.prank(admin);
       electionBody.approveAppliedParty("PDP");
       uint256 i_d = electionBody.partyNameToId("PDP");
       console.log("PDP: ", i_d);

       
       vm.prank(admin);
       electionBody.setElectionId(2);
       applicationId5 = _registerParty("Labour Party", 2, "LP", lpAddress);
       applicationId6 = _registerParty("Peoples Democratic Party", 2, "PDP", pdpAddress);
       
       vm.prank(admin);
       electionBody.approveAppliedParty("PDP");

       uint256 _partyId = electionBody.partyNameToId("PDP");
       console.log("PDP_second_reg: ", _partyId);
       (uint256 id,,,,NationalElectionBody.Status status) = electionBody.registeredParties(2, _partyId);
       
       assertEq(id, _partyId);
       console.log(uint256(status));
    }


   function test_approve_registration_application() public {
        // Application does not exist because payement of registration fee failed

        vm.expectRevert();
        applicationId4 = _registerParty("New Nigeria Peoples Party", 1, "NNPP",  emptyAddress);
        
        vm.expectRevert();
        electionBody.approveAppliedParty("NNPP");

        // Random person can't Approve Registration
        vm.expectRevert();
        electionBody.approveAppliedParty("PDP");
        
        vm.prank(admin);
        //Only Chairman can Approve Registration
        electionBody.approveAppliedParty("PDP");


        
        (,,,,NationalElectionBody.Status status) = electionBody.appliedParties(1, applicationId1);
        
        assertEq(uint256(status), uint256(NationalElectionBody.Status.approved));
        console.log(uint256(status));
        
        // check party exists for a particular election
        uint256 _partyId1 = electionBody.partyNameToId("PDP");
        (uint256 id1, string memory partyName1, address partyAddress1, string memory partyAcronym1,) = electionBody.registeredParties(1, _partyId1);
        assertEq(partyName1, "Peoples Democratic Party");
        assertEq(partyAddress1, pdpAddress);
        assertEq(partyAcronym1, "PDP");
        assertEq(id1, _partyId1);

        uint256 _partyId2 = electionBody.partyNameToId("NNPP");
        (uint256 id2, string memory partyName2, address partyAddress2, string memory partyAcronym2,) = electionBody.registeredParties(1, _partyId2);
        assertEq(partyName2, "");
        assertEq(partyAddress2, address(0));
        assertEq(partyAcronym2, "");
        assertEq(id2, 0);

    }

    // function test_contract_receives_registration_fee_payment() public {
    //     // Insufficient funds
    //     vm.expectRevert();
    //     applicationId4 = _registerParty("New Nigeria Peoples Party", 1, "NNPP",  emptyAddress);

    //     // Balance of the Election Body is updated
    //     assertEq(token.balanceOf(address(electionBody)), REGISTRATION_FEE * 3);
    // }



//     function test_reject_registration_application() public { 
//         // Application does not exist because payement of registration fee failed
//         vm.expectRevert();
//         applicationId4 = _registerParty("New Nigeria Peoples Party", "Dr. Ajuji Ahmed", "NNPP",  emptyAddress);
//         vm.expectRevert();
//         electionBody.approveAppliedParty(applicationId4);

//         // Random person can't Reject Registration
//         vm.expectRevert();
//         electionBody.rejectPartyRegistration(applicationId1, "Incomplete Credentials");

//         balanceBefore = token.balanceOf(address(apgaAddress));
//         applicationId5 = _registerParty("All Progressives Grand Alliance", "Willie Mmaduaburochukwu Obiano", "APGA",  apgaAddress);      
        
//         // Only Chairman can Approve Registration
//         vm.prank(PartyChairman);
//         electionBody.rejectPartyRegistration(applicationId5, "Incomplete Credentials");
        
//         (,,,,,NationalElectionBody.Status status) = electionBody.appliedParties(applicationId5 - 1);
//         assertEq(uint256(status), uint256(NationalElectionBody.Status.rejected));

//         // Check that fee was refunded
//         balanceAfter = token.balanceOf(address(apgaAddress));
//         assertEq(balanceAfter, balanceBefore);

//         // Check that the party is cleared so they can apply again
//         assertEq(electionBody.applicationPartyToId("APGA"), 0);
//     }

//     function test_add_candidate_for_national_election() public {
//         vm.prank(PartyChairman);
//         electionBody.approveAppliedParty(applicationId1);

//         uint256 registeredPartyId = electionBody.partyNameToId("PDP");

//         vm.expectRevert();
//         electionBody.addCandidateForNationalElection(2, "Atiku Abubakar", pdpCandidateAddress);

//         vm.expectRevert();
//         electionBody.addCandidateForNationalElection(0, "Atiku Abubakar", pdpCandidateAddress);
        
//         electionBody.addCandidateForNationalElection(registeredPartyId, "Atiku Abubakar", pdpCandidateAddress);
//         (uint256 PartyId, uint256 CandidateId, string memory Name, address Address) = electionBody.partyCandidate(registeredPartyId);
        
//         assertEq(PartyId, registeredPartyId);
//         assertEq(CandidateId, 1);
//         assertEq(Name, "Atiku Abubakar");
//         assertEq(Address, pdpCandidateAddress);
//     }

//     function test_get_next_electionId() public {
//         firstElectionId = electionBody.getNextElectionId();
//         secondElectionId = electionBody.getNextElectionId();
        
//         assertEq(firstElectionId, 1);
//         assertEq(secondElectionId, 2);
//     }

//     function test_party_is_registered() public {
//         vm.expectRevert();
//         electionBody.isPartyRegistered("PDP");

//         vm.prank(PartyChairman);
//         electionBody.approveAppliedParty(applicationId1);
//         bool stat = electionBody.isPartyRegistered("PDP");

//         (uint256 id, string memory partyName, address partyAddress, string memory partyAcronym, string memory partyChairman, NationalElectionBody.Status status) = electionBody.registeredParties(0);
//         assertEq(uint256(status), uint256(NationalElectionBody.Status.approved));
//         assertEq(true, stat);
//     }

//     function test_get_party_candidate() public {
//         vm.prank(PartyChairman);
//         electionBody.approveAppliedParty(applicationId1);

//         uint256 registeredPartyId = electionBody.partyNameToId("PDP");
        
//         vm.expectRevert();
//         electionBody.getPartyCandidate("PDP");

//         electionBody.addCandidateForNationalElection(1, "Atiku Abubakar", pdpCandidateAddress);
//         (uint256 PartyId, uint256 CandidateId, string memory Name, address Address) = electionBody.partyCandidate(registeredPartyId);

//         assertEq(PartyId, registeredPartyId);
//         assertEq(CandidateId, 1);
//         assertEq(Name, "Atiku Abubakar");
//         assertEq(Address, pdpCandidateAddress);
//     }

//     function test_get_registered_party_counter() public {
//         vm.prank(PartyChairman);
//         electionBody.approveAppliedParty(applicationId1);

//         vm.prank(PartyChairman);
//         electionBody.approveAppliedParty(applicationId2);

//         vm.prank(PartyChairman);
//         electionBody.approveAppliedParty(applicationId3);

//         assertEq(electionBody.getRegisteredPartyCount(), 3);
//     }

//     function test_get_candidate_count() public {
//         vm.prank(PartyChairman);
//         electionBody.approveAppliedParty(applicationId1);

//         uint256 registeredPartyId1 = electionBody.partyNameToId("PDP");
//         electionBody.addCandidateForNationalElection(registeredPartyId1, "Atiku Abubakar", pdpCandidateAddress);

//         vm.prank(PartyChairman);
//         electionBody.approveAppliedParty(applicationId2);
//         uint256 registeredPartyId2 = electionBody.partyNameToId("LP");
//         electionBody.addCandidateForNationalElection(registeredPartyId2, "Peter Obi", lpCandidateAddress);


//         vm.prank(PartyChairman);
//         electionBody.approveAppliedParty(applicationId3);
//         uint256 registeredPartyId3 = electionBody.partyNameToId("APC");
//         electionBody.addCandidateForNationalElection(registeredPartyId3, "Bola Ahmed Tinubu", apcCandidateAddress);

//         assertEq(electionBody.getCandidateCount(), 3);
//     }

//     function test_change_registration_fee() public {
//         newRegistrationFee = 5000e18;
//         electionBody.changeRegistrationFee(5000e18);
//         assertEq(electionBody.RegistrationFee(), newRegistrationFee);
//     }
}