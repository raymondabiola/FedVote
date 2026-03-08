//SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {NationalToken} from "../src/NationalToken.sol";
import {NationalElectionBody} from "../src/NationalElectionBody.sol";

contract NationalElectionBodyTest is Test {
    NationalElectionBody public electionBody;
    NationalToken public token;

    uint256 applicationId1;
    uint256 applicationId2;
    uint256 applicationId3;
    uint256 applicationId4;
    uint256 applicationId5;

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
    address public partyChairman = makeAddr("partyChairman");
    address centralBank = makeAddr("centralBank");

    uint256 constant REGISTRATION_FEE = 10_000e18;

    function setUp() public {
        vm.startPrank(centralBank);
        token = new NationalToken(centralBank);
        token.mint(pdpAddress, REGISTRATION_FEE);
        token.mint(lpAddress, REGISTRATION_FEE);
        token.mint(apcAddress, REGISTRATION_FEE);
        token.mint(apgaAddress, REGISTRATION_FEE);
        vm.stopPrank();

        
        vm.startPrank(admin);
        electionBody = new NationalElectionBody(address(token));
        electionBody.grantChairmanRole(partyChairman);
        vm.stopPrank();

        vm.prank(pdpAddress);
        token.approve(address(electionBody), type(uint256).max);

        vm.prank(lpAddress);
        token.approve(address(electionBody), type(uint256).max);

        vm.prank(apcAddress);
        token.approve(address(electionBody), type(uint256).max);

        vm.prank(apgaAddress);
        token.approve(address(electionBody), type(uint256).max);
        

        applicationId1 = _registerParty("Peoples Democratic Party", "Dr. Kabiru Tanimu Turaki", "PDP", pdpAddress);
        applicationId2 = _registerParty("Labour Party", "Senator Nenadi Usman", "LP", lpAddress);
        applicationId3 = _registerParty("All Progressives Congress", " Professor Nentawe Yilwatda", "APC",  apcAddress);
        
    }

    function  _registerParty(string memory name, string memory chairman, string memory acronym, address addr) internal returns (uint256 applicationId) {
        vm.prank(addr);
        electionBody.RegisterParty(name, acronym, chairman, addr);
        applicationId = electionBody.applicationPartyToId(acronym);
    }

    function test_deployment() public {
        assertEq(address(electionBody.nationalToken()), address(token));
    }
    
    function test_successful_registration_application() public {
       assertEq(applicationId1, 1);
       vm.expectRevert();
       // Already applied
       applicationId1 = _registerParty("Peoples Democratic Party", "Dr. Kabiru Tanimu Turaki", "PDP", pdpAddress);
       
       assertEq(applicationId2, 2);
       assertEq(applicationId3, 3);
    }

    function test_contract_receives_registration_fee_payment() public {
        // Insufficient funds
        vm.expectRevert();
        applicationId4 = _registerParty("New Nigeria Peoples Party", "Dr. Ajuji Ahmed", "NNPP",  emptyAddress);

        // Balance of the Election Body is updated
        assertEq(token.balanceOf(address(electionBody)), REGISTRATION_FEE * 3);
    }

    function test_approve_registration_application() public {
        // Application does not exist because payement of registration fee failed
        vm.expectRevert();
        applicationId4 = _registerParty("New Nigeria Peoples Party", "Dr. Ajuji Ahmed", "NNPP",  emptyAddress);
        vm.expectRevert();
        electionBody.approveAppliedParty(applicationId4);

        // Random person can't Approve Registration
        vm.expectRevert();
        electionBody.approveAppliedParty(applicationId1);

        // Only Chairman can Approve Registration
        vm.prank(partyChairman);
        electionBody.approveAppliedParty(applicationId1);
        
        (,,,,,NationalElectionBody.Status status) = electionBody.appliedParties(applicationId1 - 1);
        assertEq(uint256(status), uint256(NationalElectionBody.Status.approved));

        // check party is inside the registeredParties
        (uint256 id, string memory partyName, address partyAddress, string memory partyAcronym,,) = electionBody.registeredParties(0);
        assertEq(partyName, "Peoples Democratic Party");
        assertEq(partyAddress, pdpAddress);
        assertEq(partyAcronym, "PDP");
        assertEq(id, 1);

    }

    function test_reject_registration_application() public { 
        // Application does not exist because payement of registration fee failed
        vm.expectRevert();
        applicationId4 = _registerParty("New Nigeria Peoples Party", "Dr. Ajuji Ahmed", "NNPP",  emptyAddress);
        vm.expectRevert();
        electionBody.approveAppliedParty(applicationId4);

        // Random person can't Reject Registration
        vm.expectRevert();
        electionBody.rejectPartyRegistration(applicationId1, "Incomplete Credentials");

        balanceBefore = token.balanceOf(address(apgaAddress));
        applicationId5 = _registerParty("All Progressives Grand Alliance", "Willie Mmaduaburochukwu Obiano", "APGA",  apgaAddress);      
        
        // Only Chairman can Approve Registration
        vm.prank(partyChairman);
        electionBody.rejectPartyRegistration(applicationId5, "Incomplete Credentials");
        
        (,,,,,NationalElectionBody.Status status) = electionBody.appliedParties(applicationId5 - 1);
        assertEq(uint256(status), uint256(NationalElectionBody.Status.rejected));

        // Check that fee was refunded
        balanceAfter = token.balanceOf(address(apgaAddress));
        assertEq(balanceAfter, balanceBefore);

        // Check that the party is cleared so they can apply again
        assertEq(electionBody.applicationPartyToId("APGA"), 0);
    }
}