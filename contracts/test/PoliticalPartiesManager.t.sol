// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import "forge-std/console.sol";
import {PoliticalPartyManager} from "../src/PoliticalPartiesManager.sol";
import {PoliticalPartiesManagerFactory} from "../src/PoliticalPartiesManagerFactory.sol";
import {NationalToken} from "../src/NationalToken.sol";
import {Registry} from "../src/Registry.sol";
import {NationalElectionBody} from "../src/NationalElectionBody.sol";
import {INationalElectionBody} from "../src/interfaces/INationalElectionBody.sol";

contract PoliticalPartyManagerTest is Test {
    PoliticalPartiesManagerFactory factory;
    PoliticalPartyManager partyManager;
    NationalToken nationalToken;
    Registry registry;
    NationalElectionBody electionBodyInstance;
    INationalElectionBody nationalElectionBody;

    address[] public partyManagers;

    string partyName = "Apc";
    address electionBodyAddress = address(1);
    address centralBankAddress = address(2);

    // Test Addresses
    address chairman = address(3);
    address candidate = address(4);
    address attacker = address(6);

    address public user1;
    address public user2;
    address public user3;

    bytes32[] ninHashes;
    string[] names;
    address[] addresses;

    // Membership and Candidacy fee
    uint256 fee = 100 * (10 ** 18);

    // ElectionId
    uint256 electionId = 101;

    function setUp() public {
        factory = new PoliticalPartiesManagerFactory();
        nationalToken = new NationalToken(centralBankAddress);
        registry = new Registry();
        electionBodyInstance = new NationalElectionBody(address(nationalToken));
        nationalElectionBody = INationalElectionBody(address(electionBodyInstance));
        factory.createNewPoliticalParty(chairman, partyName, address(nationalToken), address(nationalElectionBody), address(registry));
        partyManagers = factory.getAllPoliticalParty();
        partyManager = PoliticalPartyManager(partyManagers[0]);

        user1 = address(7);
        user2 = address(8);
        user3 = address(9);
    }

    function testcreateNewPoliticalParty() public {
        assertEq(partyManagers.length, 1);

        partyManager = PoliticalPartyManager(partyManagers[0]);
        assertEq(partyManager.chairman(), chairman);
        assertEq(partyManager.partyName(), "Apc");
        assertEq(address(partyManager.nationalToken()), address(nationalToken));
        assertEq(address(partyManager.registry()), address(registry));
        assertTrue(partyManager.hasRole(partyManager.DEFAULT_ADMIN_ROLE(), chairman));
        assertTrue(partyManager.hasRole(partyManager.PARTY_LEADER(), chairman));
    }

    function testSetCandidacyFee() public {
        // Edge case test for Admin can set Candidacy Fee
        vm.prank(chairman);
        partyManager.setCandidacyFee(fee);
        assertEq(partyManager.candidacyFee(), fee);

        // Edge case test for attacker can't set Candidacy Fee
        vm.prank(attacker);
        vm.expectRevert();
        partyManager.setCandidacyFee(fee);

        // Edge case test for Candidacy Fee can't be Zero
        uint256 fee = 0;
        vm.prank(chairman);
        vm.expectRevert(PoliticalPartyManager.InvalidAmount.selector);
        partyManager.setCandidacyFee(fee);
    }

    function testSetMembershipFee() public {
        // Edge case test for Admin can set Membership Fee
        vm.prank(chairman);
        partyManager.setMembershipFee(fee);
        assertEq(partyManager.membershipFee(), fee);

        // Edge case test for attacker can't set Membership Fee
        vm.prank(attacker);
        vm.expectRevert();
        partyManager.setMembershipFee(fee);

        // Edge case test for Membership Fee can't be Zero
        uint256 fee = 0;
        vm.prank(chairman);
        vm.expectRevert(PoliticalPartyManager.InvalidAmount.selector);
        partyManager.setMembershipFee(fee);
    }

    // Test payForMembership
    function getNumHash(uint256 _num) internal pure returns (bytes32) {
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

    function setupValidUser() internal {
    vm.prank(chairman);
    partyManager.setMembershipFee(fee);

    simulateArrayPopulate();

    vm.prank(address(this));
    registry.grantRole(registry.PARTY_CONTRACT_ROLE(), address(partyManager));

    vm.prank(user1);
    registry.voterSelfRegister(2345, "Alice");

    vm.prank(centralBankAddress);
    nationalToken.mint(user1, 1000 * (10 ** 18));

    vm.startPrank(user1);
    nationalToken.approve(address(partyManager), fee);
}

    function testPayForMemebershipWithValidNin() public {
        setupValidUser();
        partyManager.payForMembership(2345);
        vm.stopPrank();
        assertTrue(partyManager.getPartyMember(user1).hasPaidForMembership);
    }

    function testPayForMemebershipWithInvalidNin() public {
        setupValidUser();
        vm.expectRevert();
        partyManager.payForMembership(2375);
        vm.stopPrank();
        assertFalse(partyManager.getPartyMember(user1).hasPaidForMembership);
    }

    function testRegisterMemberWithValidNameAndNin() public {
        setupValidUser();
        partyManager.payForMembership(2345);
        partyManager.registerMember("Alice", 2345);
        vm.stopPrank();
        assertTrue(partyManager.hasRole(partyManager.MEMBER_ROLE(), user1));
    }

    function testRegisterMemberWithInvalidNameAndNin() public {
        setupValidUser();
        partyManager.payForMembership(2345);
        vm.expectRevert();
        partyManager.registerMember("Alce", 235);
        vm.stopPrank();
        assertFalse(partyManager.hasRole(partyManager.MEMBER_ROLE(), user1));
    }

    function testRegisterMemberWithInvalidNin() public {
        setupValidUser();
        partyManager.payForMembership(2345);
        vm.expectRevert();
        partyManager.registerMember("Alice", 2350);
        vm.stopPrank();
        assertFalse(partyManager.hasRole(partyManager.MEMBER_ROLE(), user1));
    }    

    function testOnlyAdminRemoveMember() public {
        setupValidUser();
        partyManager.payForMembership(2345);
        partyManager.registerMember("Alice", 2345);
        vm.stopPrank();

        vm.prank(chairman);
        partyManager.removeMember(user1, 2345);
        assertFalse(partyManager.hasRole(partyManager.MEMBER_ROLE(), user1));

        vm.prank(address(this));
        assertFalse(registry.checkIfCitizenIsPartyMember(2345));
    }

    function testAttackerCantRemoveMember() public {
        setupValidUser();
        partyManager.payForMembership(2345);
        partyManager.registerMember("Alice", 2345);
        vm.stopPrank();

        vm.prank(attacker);
        vm.expectRevert();
        partyManager.removeMember(user1, 2345);
        assertTrue(partyManager.hasRole(partyManager.MEMBER_ROLE(), user1));

        vm.prank(address(this));
        assertTrue(registry.checkIfCitizenIsPartyMember(2345));
    }
    
    function testOnlyMemberCanPayAndCantPayTwiceForCandidacy() public {
        setupValidUser();
        partyManager.payForMembership(2345);
        partyManager.registerMember("Alice", 2345);
        vm.stopPrank();

        vm.prank(centralBankAddress);
        nationalToken.mint(user1, 1000 * (10 ** 18));
        vm.prank(user1);
        nationalToken.approve(address(partyManager), fee);
        vm.prank(user1);
        partyManager.payForCandidateship();

        assertTrue(partyManager.hasPaidForCandidacy(user1));

        // Member Can't Pay Twice
        vm.prank(user1);
        vm.expectRevert(PoliticalPartyManager.AlreadyPaidForCandidacy.selector);
        partyManager.payForCandidateship();
    }
    

    function testAttackerCannotPayForCandidacy() public {
        vm.prank(centralBankAddress);
        nationalToken.mint(attacker, 1000 * (10 ** 18));
        vm.prank(attacker);
        nationalToken.approve(address(partyManager), fee);
        vm.prank(attacker);
        vm.expectRevert();
        partyManager.payForCandidateship();

        assertFalse(partyManager.hasPaidForCandidacy(attacker));
    }

    function testAdminCanSetElectionId() public {
        // uint256 electionId = 101;
        // vm.prank(chairman);
        // nationalElectionBody.getElectionId(electionId);
        // assertEq(partyManager.electionId(), electionId);

        uint256 expectedId = nationalElectionBody.getElectionId();

        vm.prank(chairman);
        partyManager.setElectionId();

        uint256 storedId = partyManager.electionId();

        assertEq(storedId, expectedId);
    }

    function testAttackerCannotSetElectionId() public {
        vm.prank(attacker);
        vm.expectRevert();
        partyManager.setElectionId();
    }

    function setupValidMember() internal {
        setupValidUser();
        partyManager.payForMembership(2345);
        partyManager.registerMember("Alice", 2345);
        vm.stopPrank();

        vm.prank(centralBankAddress);
        nationalToken.mint(user1, 1000 * (10 ** 18));
        vm.prank(user1);
        nationalToken.approve(address(partyManager), fee);
        vm.prank(user1);
        partyManager.payForCandidateship();
    }

    function testMembersCanRegisterAsCandidate() public {
        setupValidMember();
        vm.prank(user1);
        partyManager.registerCandidate("Alice", 2345);
        assertTrue(partyManager.getPartyCandidate(electionId, 1).isRegistered);
    }

    function testCantRegisterWithInvalidName() public {
        setupValidMember();
        vm.prank(user1);
        vm.expectRevert();
        partyManager.registerCandidate("Alie", 2345);
    }

    function testCantRegisterWithInvalidNin() public {
        setupValidMember();
        vm.prank(user1);
        vm.expectRevert();
        partyManager.registerCandidate("Alice", 2349);
    }

    function testAttackerCantRegisterAsCandidate() public {
        setupValidMember();
        vm.prank(attacker);
        vm.expectRevert();
        partyManager.registerCandidate("Alice", 2345);
    }

    function testAdminCanRemoveCandidate() public {
        uint256 electionId = 101;
        vm.prank(address(this));
        nationalElectionBody.setElectionId(electionId);
        vm.prank(chairman);
        partyManager.setElectionId();

        setupValidMember();
        vm.prank(user1);
        partyManager.registerCandidate("Alice", 2345);

        vm.prank(chairman);
        partyManager.removeCandidate(electionId, 1, user1);
        assertFalse(partyManager.hasPaidForCandidacy(user1));
    }

    function testAdminCantRemoveUnregisteredCandidate() public {
        uint256 electionId = 101;
        vm.prank(chairman);
        partyManager.setElectionId();

        setupValidMember();
        vm.prank(user1);
        partyManager.registerCandidate("Alice", 2345);

        vm.prank(chairman);
        vm.expectRevert();
        partyManager.removeCandidate(electionId, 5, user1);
    }

    function testAttackerCantRemoveCandidate() public {
        uint256 electionId = 101;
        vm.prank(chairman);
        partyManager.setElectionId();

        setupValidMember();
        vm.prank(user1);
        partyManager.registerCandidate("Alice", 2345);

        vm.prank(attacker);
        vm.expectRevert();
        partyManager.removeCandidate(electionId, 1, user1);
        assertTrue(partyManager.hasPaidForCandidacy(user1));
    }

    function testAdminCanCreateElection() public {
        uint256 electionId = 101;
        vm.prank(address(this));
        nationalElectionBody.setElectionId(electionId);
        vm.prank(chairman);
        partyManager.setElectionId();
        vm.prank(chairman);
        partyManager.createElection(2);
        assertEq(partyManager.checkElectionStatus(electionId).id, 101);
    }

    function testAttackerCantCreateElection() public {
        uint256 electionId = 101;
        vm.prank(chairman);
        partyManager.setElectionId();
        vm.prank(attacker);
        vm.expectRevert();
        partyManager.createElection(2);
        assertEq(partyManager.checkElectionStatus(electionId).id, 0);
    }

    function testMembersCanVoteforPrimaryElection() public {
        uint256 electionId = 101;
        vm.prank(address(this));
        nationalElectionBody.setElectionId(electionId);
        vm.prank(chairman);
        partyManager.setElectionId();
        vm.prank(chairman);
        partyManager.createElection(2);
    
        setupValidMember();
        vm.startPrank(user1);
        partyManager.registerCandidate("Alice", 2345);
        partyManager.voteforPrimaryElection(1, electionId);
        vm.stopPrank();
        assertEq(partyManager.getPartyCandidate(electionId, 1).voteCount, 1);
        assertTrue(partyManager.getPartyMember(user1).hasVoted);
    }

    function testMembersCantVoteTwice() public {
        uint256 electionId = 101;
        vm.prank(address(this));
        nationalElectionBody.setElectionId(electionId);
        vm.prank(chairman);
        partyManager.setElectionId();
        vm.prank(chairman);
        partyManager.createElection(2);
    
        setupValidMember();
        vm.startPrank(user1);
        partyManager.registerCandidate("Alice", 2345);
        partyManager.voteforPrimaryElection(1, electionId);
        vm.stopPrank();

        vm.prank(user1);
        vm.expectRevert();
        partyManager.voteforPrimaryElection(1, electionId);
    }

    function testMemberCantVoteWhenElectionEnded() public {
        uint256 electionId = 101;
        vm.prank(chairman);
        partyManager.setElectionId();
        vm.prank(chairman);
        uint startTime = block.timestamp; 
        partyManager.createElection(1);
    
        setupValidMember();
        vm.startPrank(user1);
        partyManager.registerCandidate("Alice", 2345);
        vm.warp(startTime + 7203);
        vm.expectRevert();
        partyManager.voteforPrimaryElection(1, electionId);
        vm.stopPrank();
    }

    function testMemberCantVotewithInvalidCandidateId() public {
        uint256 electionId = 101;
        vm.prank(chairman);
        partyManager.setElectionId();
        vm.prank(chairman);
        partyManager.createElection(2);
    
        setupValidMember();
        vm.startPrank(user1);
        partyManager.registerCandidate("Alice", 2345);
        vm.expectRevert();
        partyManager.voteforPrimaryElection(5, electionId);
        vm.stopPrank();
    }

    function testAttackerCantVoteForPrimaryElection() public {
        uint256 electionId = 101;
        vm.prank(chairman);
        partyManager.setElectionId();
        vm.prank(chairman);
        partyManager.createElection(2);
    
        setupValidMember();
        vm.prank(user1);
        partyManager.registerCandidate("Alice", 2345);

        vm.prank(attacker);
        vm.expectRevert();
        partyManager.voteforPrimaryElection(1, electionId);
        assertEq(partyManager.getPartyCandidate(electionId, 1).voteCount, 0);
    }

    function testAdminCanDeclareWinner() public {
        uint256 electionId = 101;
        vm.prank(address(this));
        nationalElectionBody.setElectionId(electionId);
        vm.prank(chairman);
        partyManager.setElectionId();
        vm.startPrank(chairman);
        uint startTime = block.timestamp; 
        partyManager.createElection(1);
        vm.stopPrank();

        setupValidMember();
        vm.startPrank(user1);
        partyManager.registerCandidate("Alice", 2345);
        partyManager.voteforPrimaryElection(1, electionId);
        vm.stopPrank();
        vm.warp(startTime + 7203);

        vm.prank(chairman);
        partyManager.declareWinner(electionId);
    }

    function testAdminCantDeclareWinnerWhenElectionisOngoing() public {
        uint256 electionId = 101;
        vm.prank(address(this));
        nationalElectionBody.setElectionId(electionId);
        vm.prank(chairman);
        partyManager.setElectionId();
        vm.startPrank(chairman);
        partyManager.createElection(1);
        vm.stopPrank();

        setupValidMember();
        vm.startPrank(user1);
        partyManager.registerCandidate("Alice", 2345);
        partyManager.voteforPrimaryElection(1, electionId);
        vm.stopPrank();

        vm.prank(chairman);
        vm.expectRevert();
        partyManager.declareWinner(electionId);
    }

    function testAttackerCantDeclareWinner() public {
        uint256 electionId = 101;
        vm.prank(address(this));
        nationalElectionBody.setElectionId(electionId);
        vm.prank(chairman);
        partyManager.setElectionId();
        vm.startPrank(chairman);
        uint startTime = block.timestamp; 
        partyManager.createElection(1);
        vm.stopPrank();

        setupValidMember();
        vm.startPrank(user1);
        partyManager.registerCandidate("Alice", 2345);
        partyManager.voteforPrimaryElection(1, electionId);
        vm.stopPrank();
        vm.warp(startTime + 7203);

        vm.prank(attacker);
        vm.expectRevert();
        partyManager.declareWinner(electionId);
    }

    // function testRegisterWinnerWithElectionBody() public {
    //     uint256 electionId = 101;
    //     vm.prank(chairman);
    //     partyManager.setElectionId();
    //     vm.startPrank(chairman);
    //     uint startTime = block.timestamp; 
    //     partyManager.createElection(1);
    //     vm.stopPrank();

    //     setupValidMember();
    //     vm.startPrank(user1);
    //     partyManager.registerCandidate("Alice", 2345);
    //     partyManager.voteforPrimaryElection(1, electionId);
    //     vm.stopPrank();
    //     vm.warp(startTime + 7203);

    //     vm.prank(address(this));
    //     nationalElectionBody.grantRole(nationalElectionBody.PARTY_PRIMARIES_ROLE(), address(partyManager));

    //     vm.startPrank(chairman);
    //     partyManager.declareWinner(electionId);
    //     partyManager.registerWinnerWithElectionBody(electionId);
    //     vm.stopPrank();

    //     assertEq(nationalElectionBody.getPartyCandidate("APC", electionId).Address, user1);
    // }   
}
