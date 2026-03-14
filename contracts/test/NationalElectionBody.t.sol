// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import "forge-std/console.sol";
import {NationalToken} from "../src/NationalToken.sol";
import {NationalElectionBody} from "../src/NationalElectionBody.sol";

contract NationalElectionBodyTest is Test {

    NationalElectionBody public electionBody;
    NationalToken public token;

    //  ACTORS

    address public admin       = makeAddr("admin");
    address public centralBank = makeAddr("centralBank");
    address public primaries   = makeAddr("primariesContract");
    address public randomUser  = makeAddr("randomUser");

    address public pdpAddress  = makeAddr("pdpAddress");
    address public apcAddress  = makeAddr("apcAddress");
    address public lpAddress   = makeAddr("lpAddress");
    address public apgaAddress = makeAddr("apgaAddress");
    address public emptyAddress = makeAddr("emptyAddress"); 

    address public pdpCandidate = makeAddr("pdpCandidate");
    address public apcCandidate = makeAddr("apcCandidate");

    uint256 constant REGISTRATION_FEE = 10_000e18;

    //  SETUP

    function setUp() public {
        // Deploy token and mint to parties
        vm.startPrank(centralBank);
        token = new NationalToken(centralBank);
        token.mint(pdpAddress,  REGISTRATION_FEE * 10);
        token.mint(apcAddress,  REGISTRATION_FEE * 10);
        token.mint(lpAddress,   REGISTRATION_FEE * 10);
        token.mint(apgaAddress, REGISTRATION_FEE * 10);
        vm.stopPrank();

        // Deploy election body, set election ID
        vm.startPrank(admin);
        electionBody = new NationalElectionBody(address(token));
        electionBody.grantRole(electionBody.PARTY_PRIMARIES_ROLE(), primaries);
        electionBody.setElectionId(1);
        vm.stopPrank();

        // All parties approve max spend
        _approveMax(pdpAddress);
        _approveMax(apcAddress);
        _approveMax(lpAddress);
        _approveMax(apgaAddress);
    }

    function _approveMax(address _addr) internal {
        vm.prank(_addr);
        token.approve(address(electionBody), type(uint256).max);
    }

    function _register(address _addr, string memory _name, uint256 _eid, string memory _acronym) internal {
        vm.prank(_addr);
        electionBody.registerParty(_name, _eid, _acronym);
    }

    //  DEPLOYMENT

    function test_deployment() public view {
        assertEq(address(electionBody.nationalToken()), address(token));
        assertEq(electionBody.electionId(), 1);
    }

    //  ELECTION ID MANAGEMENT

    function test_setElectionId_success() public {
        vm.prank(admin);
        electionBody.setElectionId(2);
        assertEq(electionBody.electionId(), 2);
    }

    function test_setElectionId_reverts_on_reuse() public {
        vm.prank(admin);
        vm.expectRevert("ElectionId already exists");
        electionBody.setElectionId(1);
    }

    function test_setElectionId_reverts_for_non_admin() public {
        vm.prank(randomUser);
        vm.expectRevert();
        electionBody.setElectionId(2);
    }

    //  PARTY REGISTRATION

    function test_registerParty_success() public {
        _register(pdpAddress, "Peoples Democratic Party", 1, "PDP");

        uint256 partyId = electionBody.partyNameToId("PDP");
        assertEq(partyId, 1);

        (uint256 id, string memory name,, string memory acronym, NationalElectionBody.Status status) =
            electionBody.appliedParties(1, partyId);

        assertEq(id, 1);
        assertEq(name, "Peoples Democratic Party");
        assertEq(acronym, "PDP");
        assertEq(uint256(status), uint256(NationalElectionBody.Status.pending));
    }

    function test_registerParty_reverts_wrong_election_id() public {
        vm.prank(pdpAddress);
        vm.expectRevert(NationalElectionBody.NotCurrentElection.selector);
        electionBody.registerParty("Peoples Democratic Party", 99, "PDP");
    }

    function test_registerParty_reverts_duplicate_application() public {
        _register(pdpAddress, "Peoples Democratic Party", 1, "PDP");
        vm.prank(pdpAddress);
        vm.expectRevert("Already applied for this election");
        electionBody.registerParty("Peoples Democratic Party", 1, "PDP");
    }

    function test_registerParty_reverts_insufficient_tokens() public {
        vm.prank(emptyAddress);
        vm.expectRevert();
        electionBody.registerParty("Empty Party", 1, "EP");
    }

    function test_registerParty_fee_transferred_to_contract() public {
        uint256 before = token.balanceOf(address(electionBody));
        _register(pdpAddress, "Peoples Democratic Party", 1, "PDP");
        assertEq(token.balanceOf(address(electionBody)), before + REGISTRATION_FEE);
    }

    function test_registerParty_permanent_id_reused_across_elections() public {
        // Election 1
        _register(pdpAddress, "Peoples Democratic Party", 1, "PDP");
        uint256 idElection1 = electionBody.partyNameToId("PDP");

        // Advance to election 2
        vm.prank(admin);
        electionBody.setElectionId(2);

        _register(pdpAddress, "Peoples Democratic Party", 2, "PDP");
        uint256 idElection2 = electionBody.partyNameToId("PDP");

        // Permanent ID must not change
        assertEq(idElection1, idElection2);
    }

    function test_registerParty_new_parties_get_sequential_ids() public {
        _register(pdpAddress,  "Peoples Democratic Party",   1, "PDP");
        _register(apcAddress,  "All Progressives Congress",  1, "APC");
        _register(lpAddress,   "Labour Party",               1, "LP");

        assertEq(electionBody.partyNameToId("PDP"), 1);
        assertEq(electionBody.partyNameToId("APC"), 2);
        assertEq(electionBody.partyNameToId("LP"),  3);
    }

    //  APPROVE

    function test_approveAppliedParty_success() public {
        _register(pdpAddress, "Peoples Democratic Party", 1, "PDP");

        vm.prank(admin);
        electionBody.approveAppliedParty("PDP");

        uint256 partyId = electionBody.partyNameToId("PDP");

        (,,,,NationalElectionBody.Status appStatus) = electionBody.appliedParties(1, partyId);
        assertEq(uint256(appStatus), uint256(NationalElectionBody.Status.approved));

        (uint256 id, string memory name, address addr, string memory acronym, NationalElectionBody.Status regStatus) =
            electionBody.registeredParties(1, partyId);
        assertEq(id, partyId);
        assertEq(name, "Peoples Democratic Party");
        assertEq(addr, pdpAddress);
        assertEq(acronym, "PDP");
        assertEq(uint256(regStatus), uint256(NationalElectionBody.Status.approved));
    }

    function test_approveAppliedParty_reverts_for_non_admin() public {
        _register(pdpAddress, "Peoples Democratic Party", 1, "PDP");
        vm.prank(randomUser);
        vm.expectRevert();
        electionBody.approveAppliedParty("PDP");
    }

    function test_approveAppliedParty_reverts_unknown_party() public {
        vm.prank(admin);
        vm.expectRevert();
        electionBody.approveAppliedParty("UNKNOWN");
    }

    function test_approveAppliedParty_reverts_already_approved() public {
        _register(pdpAddress, "Peoples Democratic Party", 1, "PDP");
        vm.prank(admin);
        electionBody.approveAppliedParty("PDP");

        vm.prank(admin);
        vm.expectRevert();
        electionBody.approveAppliedParty("PDP");
    }

    function test_approve_across_two_elections_same_party() public {
        // Election 1: register and approve PDP
        _register(pdpAddress, "Peoples Democratic Party", 1, "PDP");
        vm.prank(admin);
        electionBody.approveAppliedParty("PDP");

        uint256 partyId = electionBody.partyNameToId("PDP");
        (uint256 id1,,,,NationalElectionBody.Status s1) = electionBody.registeredParties(1, partyId);
        assertEq(id1, partyId);
        assertEq(uint256(s1), uint256(NationalElectionBody.Status.approved));

        // Election 2: register and approve the same party
        vm.prank(admin);
        electionBody.setElectionId(2);
        _register(pdpAddress, "Peoples Democratic Party", 2, "PDP");

        vm.prank(admin);
        electionBody.approveAppliedParty("PDP");

        (uint256 id2,,,,NationalElectionBody.Status s2) = electionBody.registeredParties(2, partyId);
        assertEq(id2, partyId);
        assertEq(uint256(s2), uint256(NationalElectionBody.Status.approved));

        // Election 1 record must be untouched
        (uint256 stillId1,,,,NationalElectionBody.Status stillS1) = electionBody.registeredParties(1, partyId);
        assertEq(stillId1, partyId);
        assertEq(uint256(stillS1), uint256(NationalElectionBody.Status.approved));
    }

    //  REJECT

    function test_rejectPartyRegistration_success() public {
        _register(pdpAddress, "Peoples Democratic Party", 1, "PDP");

        uint256 balanceBefore = token.balanceOf(pdpAddress);

        vm.prank(admin);
        electionBody.rejectPartyRegistration("PDP", "Incomplete credentials");

        uint256 partyId = electionBody.partyNameToId("PDP");
        (,,,,NationalElectionBody.Status status) = electionBody.appliedParties(1, partyId);
        assertEq(uint256(status), uint256(NationalElectionBody.Status.rejected));

        // Fee refunded
        assertEq(token.balanceOf(pdpAddress), balanceBefore + REGISTRATION_FEE);
    }

    function test_rejectPartyRegistration_reverts_for_non_admin() public {
        _register(pdpAddress, "Peoples Democratic Party", 1, "PDP");
        vm.prank(randomUser);
        vm.expectRevert();
        electionBody.rejectPartyRegistration("PDP", "reason");
    }

    function test_rejectPartyRegistration_reverts_already_rejected() public {
        _register(pdpAddress, "Peoples Democratic Party", 1, "PDP");
        vm.prank(admin);
        electionBody.rejectPartyRegistration("PDP", "reason");

        vm.prank(admin);
        vm.expectRevert();
        electionBody.rejectPartyRegistration("PDP", "reason again");
    }

    function test_reject_does_not_corrupt_prior_approved_record() public {
        // Election 1: approve PDP
        _register(pdpAddress, "Peoples Democratic Party", 1, "PDP");
        vm.prank(admin);
        electionBody.approveAppliedParty("PDP");

        uint256 partyId = electionBody.partyNameToId("PDP");

        // Election 2: register and reject PDP
        vm.prank(admin);
        electionBody.setElectionId(2);
        _register(pdpAddress, "Peoples Democratic Party", 2, "PDP");

        vm.prank(admin);
        electionBody.rejectPartyRegistration("PDP", "reason");

        // Election 1 registeredParties record must still be approved
        (,,,,NationalElectionBody.Status s1) = electionBody.registeredParties(1, partyId);
        assertEq(uint256(s1), uint256(NationalElectionBody.Status.approved));
    }

    //  CANDIDATE MANAGEMENT

    function test_setCandidate_success() public {
        _register(pdpAddress, "Peoples Democratic Party", 1, "PDP");
        vm.prank(admin);
        electionBody.approveAppliedParty("PDP");

        vm.prank(primaries);
        electionBody.setCandidate(1, "Atiku Abubakar", "PDP", pdpCandidate);

        NationalElectionBody.CandidateStruct memory c = electionBody.getPartyCandidate("PDP", 1);
        assertEq(c.Name, "Atiku Abubakar");
        assertEq(c.Address, pdpCandidate);
        assertEq(c.PartyAcronym, "PDP");
        assertEq(c.PartyId, electionBody.partyNameToId("PDP"));
    }

    function test_setCandidate_reverts_for_non_primaries_role() public {
        _register(pdpAddress, "Peoples Democratic Party", 1, "PDP");
        vm.prank(admin);
        electionBody.approveAppliedParty("PDP");

        vm.prank(randomUser);
        vm.expectRevert();
        electionBody.setCandidate(1, "Atiku Abubakar", "PDP", pdpCandidate);
    }

    function test_setCandidate_reverts_for_unknown_party() public {
        vm.prank(primaries);
        vm.expectRevert();
        electionBody.setCandidate(1, "Some Person", "UNKNOWN", pdpCandidate);
    }

    function test_setCandidate_reverts_if_party_not_approved() public {
        _register(pdpAddress, "Peoples Democratic Party", 1, "PDP");
        // Not approved yet
        vm.prank(primaries);
        vm.expectRevert();
        electionBody.setCandidate(1, "Atiku Abubakar", "PDP", pdpCandidate);
    }

    function test_setCandidate_can_be_overwritten_before_election() public {
        _register(pdpAddress, "Peoples Democratic Party", 1, "PDP");
        vm.prank(admin);
        electionBody.approveAppliedParty("PDP");

        vm.prank(primaries);
        electionBody.setCandidate(1, "First Candidate", "PDP", pdpCandidate);

        vm.prank(primaries);
        electionBody.setCandidate(1, "Corrected Candidate", "PDP", apcCandidate);

        NationalElectionBody.CandidateStruct memory c = electionBody.getPartyCandidate("PDP", 1);
        assertEq(c.Name, "Corrected Candidate");
        assertEq(c.Address, apcCandidate);
    }

    function test_candidates_are_isolated_per_election() public {
        // Election 1
        _register(pdpAddress, "Peoples Democratic Party", 1, "PDP");
        vm.prank(admin);
        electionBody.approveAppliedParty("PDP");
        vm.prank(primaries);
        electionBody.setCandidate(1, "Candidate A", "PDP", pdpCandidate);

        // Election 2
        vm.prank(admin);
        electionBody.setElectionId(2);
        _register(pdpAddress, "Peoples Democratic Party", 2, "PDP");
        vm.prank(admin);
        electionBody.approveAppliedParty("PDP");
        vm.prank(primaries);
        electionBody.setCandidate(2, "Candidate B", "PDP", apcCandidate);

        NationalElectionBody.CandidateStruct memory c1 = electionBody.getPartyCandidate("PDP", 1);
        NationalElectionBody.CandidateStruct memory c2 = electionBody.getPartyCandidate("PDP", 2);

        assertEq(c1.Name, "Candidate A");
        assertEq(c2.Name, "Candidate B");
    }

    //  VIEW FUNCTIONS

    function test_isPartyRegistered_returns_true_when_approved() public {
        _register(pdpAddress, "Peoples Democratic Party", 1, "PDP");
        vm.prank(admin);
        electionBody.approveAppliedParty("PDP");
        assertTrue(electionBody.isPartyRegistered("PDP", 1));
    }

    function test_isPartyRegistered_returns_false_when_pending() public {
        _register(pdpAddress, "Peoples Democratic Party", 1, "PDP");
        assertFalse(electionBody.isPartyRegistered("PDP", 1));
    }

    function test_isPartyRegistered_returns_false_when_rejected() public {
        _register(pdpAddress, "Peoples Democratic Party", 1, "PDP");
        vm.prank(admin);
        electionBody.rejectPartyRegistration("PDP", "reason");
        assertFalse(electionBody.isPartyRegistered("PDP", 1));
    }

    function test_isPartyRegistered_returns_false_for_unknown() public {
        assertFalse(electionBody.isPartyRegistered("GHOST", 1));
    }

    function test_isPartyRegistered_is_election_specific() public {
        _register(pdpAddress, "Peoples Democratic Party", 1, "PDP");
        vm.prank(admin);
        electionBody.approveAppliedParty("PDP");

        // Approved for election 1 but not election 2
        assertTrue(electionBody.isPartyRegistered("PDP", 1));
        assertFalse(electionBody.isPartyRegistered("PDP", 2));
    }

    function test_getPartyCandidate_returns_empty_when_not_set() public {
        _register(pdpAddress, "Peoples Democratic Party", 1, "PDP");
        vm.prank(admin);
        electionBody.approveAppliedParty("PDP");

        NationalElectionBody.CandidateStruct memory c = electionBody.getPartyCandidate("PDP", 1);
        assertEq(bytes(c.Name).length, 0);
    }

    function test_getPartyCount() public {
        _register(pdpAddress, "Peoples Democratic Party", 1, "PDP");
        _register(apcAddress, "All Progressives Congress", 1, "APC");
        assertEq(electionBody.getPartyCount(), 2);
    }
}
