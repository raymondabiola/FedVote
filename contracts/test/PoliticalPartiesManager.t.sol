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

    address chairman = address(3);
    address candidate = address(4);
    address attacker = address(6);

    address public user1;
    address public user2;
    address public user3;

    bytes32[] ninHashes;
    string[] names;
    address[] addresses;

    uint256 fee = 100 * (10 ** 18);
    uint256 electionId = 101;

    // createElection params: startTime=1800s, endTime=7200s, candidateRegDeadline=0
    // satisfies: endTime>0, startTime<=endTime, endTime-startTime>=1800, startTime-deadline>=1800
    uint256 constant START  = 1800;
    uint256 constant END_2H = 7200;
    uint256 constant END_1H = 3600;
    uint256 constant DEADLINE = 0;

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
        vm.prank(chairman);
        partyManager.setCandidacyFee(fee);
        assertEq(partyManager.candidacyFee(), fee);

        vm.prank(attacker);
        vm.expectRevert();
        partyManager.setCandidacyFee(fee);

        uint256 zeroFee = 0;
        vm.prank(chairman);
        vm.expectRevert(PoliticalPartyManager.InvalidAmount.selector);
        partyManager.setCandidacyFee(zeroFee);
    }

    function testSetMembershipFee() public {
        vm.prank(chairman);
        partyManager.setMembershipFee(fee);
        assertEq(partyManager.membershipFee(), fee);

        vm.prank(attacker);
        vm.expectRevert();
        partyManager.setMembershipFee(fee);

        uint256 zeroFee = 0;
        vm.prank(chairman);
        vm.expectRevert(PoliticalPartyManager.InvalidAmount.selector);
        partyManager.setMembershipFee(zeroFee);
    }

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
        partyManager.memberRegistration("Alice", 2345);
        vm.stopPrank();
        assertTrue(partyManager.hasRole(partyManager.MEMBER_ROLE(), user1));
    }

    function testRegisterMemberWithInvalidNameAndNin() public {
        setupValidUser();
        partyManager.payForMembership(2345);
        vm.expectRevert();
        partyManager.memberRegistration("Alce", 235);
        vm.stopPrank();
        assertFalse(partyManager.hasRole(partyManager.MEMBER_ROLE(), user1));
    }

    function testRegisterMemberWithInvalidNin() public {
        setupValidUser();
        partyManager.payForMembership(2345);
        vm.expectRevert();
        partyManager.memberRegistration("Alice", 2350);
        vm.stopPrank();
        assertFalse(partyManager.hasRole(partyManager.MEMBER_ROLE(), user1));
    }

    function testOnlyAdminRemoveMember() public {
        setupValidUser();
        partyManager.payForMembership(2345);
        partyManager.memberRegistration("Alice", 2345);
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
        partyManager.memberRegistration("Alice", 2345);
        vm.stopPrank();

        vm.prank(attacker);
        vm.expectRevert();
        partyManager.removeMember(user1, 2345);
        assertTrue(partyManager.hasRole(partyManager.MEMBER_ROLE(), user1));

        vm.prank(address(this));
        assertTrue(registry.checkIfCitizenIsPartyMember(2345));
    }

    function testOnlyMemberCanPayAndCantPayTwiceForCandidacy() public {
        vm.prank(address(this));
        nationalElectionBody.setElectionId(electionId);
        vm.prank(chairman);
        partyManager.setElectionId();
        vm.prank(chairman);
        partyManager.createElection(START, END_2H, DEADLINE);

        setupValidUser();
        partyManager.payForMembership(2345);
        partyManager.memberRegistration("Alice", 2345);
        vm.stopPrank();

        vm.prank(centralBankAddress);
        nationalToken.mint(user1, 1000 * (10 ** 18));
        vm.prank(user1);
        nationalToken.approve(address(partyManager), fee);
        vm.prank(user1);
        partyManager.payForCandidateship();

        assertTrue(partyManager.hasPaidForCandidacy(user1, electionId));

        vm.prank(user1);
        vm.expectRevert(PoliticalPartyManager.AlreadyPaidForCandidacy.selector);
        partyManager.payForCandidateship();
    }

    function testAttackerCannotPayForCandidacy() public {
        vm.prank(chairman);
        partyManager.setElectionId();
        vm.prank(centralBankAddress);
        nationalToken.mint(attacker, 1000 * (10 ** 18));
        vm.prank(attacker);
        nationalToken.approve(address(partyManager), fee);
        vm.prank(attacker);
        vm.expectRevert();
        partyManager.payForCandidateship();

        assertFalse(partyManager.hasPaidForCandidacy(attacker, electionId));
    }

    function testAdminCanSetElectionId() public {
        uint256 expectedId = nationalElectionBody.getElectionId();
        vm.prank(chairman);
        partyManager.setElectionId();
        assertEq(partyManager.electionId(), expectedId);
    }

    function testAttackerCannotSetElectionId() public {
        vm.prank(attacker);
        vm.expectRevert();
        partyManager.setElectionId();
    }

    function setupValidMember() internal {
        setupValidUser();
        partyManager.payForMembership(2345);
        partyManager.memberRegistration("Alice", 2345);
        vm.stopPrank();

        vm.prank(centralBankAddress);
        nationalToken.mint(user1, 1000 * (10 ** 18));
        vm.prank(user1);
        nationalToken.approve(address(partyManager), fee);
        vm.prank(user1);
        partyManager.payForCandidateship();
    }

    function testMembersCanRegisterAsCandidate() public {
        vm.prank(address(this));
        nationalElectionBody.setElectionId(electionId);
        vm.prank(chairman);
        partyManager.setElectionId();
        vm.prank(chairman);
        partyManager.createElection(START, END_2H, DEADLINE);

        setupValidMember();

        vm.prank(user1);
        partyManager.registerCandidate("Alice", 2345);
        assertTrue(partyManager.isCandidateForElection(user1, electionId));
    }

    function testCantRegisterWithInvalidName() public {
        vm.prank(address(this));
        nationalElectionBody.setElectionId(electionId);
        vm.prank(chairman);
        partyManager.setElectionId();
        vm.prank(chairman);
        partyManager.createElection(START, END_2H, DEADLINE);

        setupValidMember();
        vm.prank(user1);
        vm.expectRevert();
        partyManager.registerCandidate("Alie", 2345);
    }

    function testCantRegisterWithInvalidNin() public {
        vm.prank(address(this));
        nationalElectionBody.setElectionId(electionId);
        vm.prank(chairman);
        partyManager.setElectionId();
        vm.prank(chairman);
        partyManager.createElection(START, END_2H, DEADLINE);

        setupValidMember();
        vm.prank(user1);
        vm.expectRevert();
        partyManager.registerCandidate("Alice", 2349);
    }

    function testAttackerCantRegisterAsCandidate() public {
        vm.prank(address(this));
        nationalElectionBody.setElectionId(electionId);
        vm.prank(chairman);
        partyManager.setElectionId();
        vm.prank(chairman);
        partyManager.createElection(START, END_2H, DEADLINE);

        setupValidMember();
        vm.prank(attacker);
        vm.expectRevert();
        partyManager.registerCandidate("Alice", 2345);
    }

    function testAdminCanRemoveCandidate() public {
        vm.prank(address(this));
        nationalElectionBody.setElectionId(electionId);
        vm.prank(chairman);
        partyManager.setElectionId();
        vm.prank(chairman);
        partyManager.createElection(START, END_2H, DEADLINE);

        setupValidMember();
        vm.prank(user1);
        partyManager.registerCandidate("Alice", 2345);

        vm.prank(chairman);
        partyManager.removeCandidate(electionId, 1, user1);
    }

    function testAdminCantRemoveUnregisteredCandidate() public {
        vm.prank(address(this));
        nationalElectionBody.setElectionId(electionId);
        vm.prank(chairman);
        partyManager.setElectionId();
        vm.prank(chairman);
        partyManager.createElection(START, END_2H, DEADLINE);

        setupValidMember();
        vm.startPrank(user1);
        partyManager.registerCandidate("Alice", 2345);
        vm.stopPrank();

        vm.prank(chairman);
        vm.expectRevert();
        partyManager.removeCandidate(electionId, 5, user1);
    }

    function testAttackerCantRemoveCandidate() public {
        vm.prank(address(this));
        nationalElectionBody.setElectionId(electionId);
        vm.prank(chairman);
        partyManager.setElectionId();
        vm.prank(chairman);
        partyManager.createElection(START, END_2H, DEADLINE);

        setupValidMember();
        vm.prank(user1);
        partyManager.registerCandidate("Alice", 2345);

        vm.prank(attacker);
        vm.expectRevert();
        partyManager.removeCandidate(electionId, 1, user1);
        assertTrue(partyManager.hasPaidForCandidacy(user1, electionId));
    }

    function testAdminCanCreateElection() public {
        vm.prank(address(this));
        nationalElectionBody.setElectionId(electionId);
        vm.prank(chairman);
        partyManager.setElectionId();
        vm.prank(chairman);
        partyManager.createElection(START, END_2H, DEADLINE);
        assertEq(partyManager.checkElectionStatus(electionId).id, 101);
    }

    function testAttackerCantCreateElection() public {
        vm.prank(address(this));
        nationalElectionBody.setElectionId(electionId);
        vm.prank(chairman);
        partyManager.setElectionId();
        vm.prank(chairman);
        partyManager.createElection(START, END_2H, DEADLINE);

        vm.prank(attacker);
        vm.expectRevert();
        partyManager.createElection(START, END_2H, DEADLINE);
        assertEq(partyManager.checkElectionStatus(electionId).id, 101);
    }

    function testMembersCanVoteforPrimaryElection() public {
        vm.prank(address(this));
        nationalElectionBody.setElectionId(electionId);
        vm.prank(chairman);
        partyManager.setElectionId();
        vm.prank(chairman);
        partyManager.createElection(START, END_2H, DEADLINE);

        setupValidMember();
        vm.prank(user1);
        partyManager.registerCandidate("Alice", 2345);

        vm.warp(block.timestamp + START + 1);

        vm.prank(user1);
        partyManager.voteforPrimaryElection(1, electionId);

        assertEq(partyManager.getPartyCandidate(electionId, 1).voteCount, 1);
        assertTrue(partyManager.hasVoted(electionId, user1));
    }

    function testMembersCantVoteTwice() public {
        vm.prank(address(this));
        nationalElectionBody.setElectionId(electionId);
        vm.prank(chairman);
        partyManager.setElectionId();
        vm.prank(chairman);
        partyManager.createElection(START, END_2H, DEADLINE);

        setupValidMember();
        vm.prank(user1);
        partyManager.registerCandidate("Alice", 2345);

        vm.warp(block.timestamp + START + 1);

        vm.prank(user1);
        partyManager.voteforPrimaryElection(1, electionId);

        vm.prank(user1);
        vm.expectRevert();
        partyManager.voteforPrimaryElection(1, electionId);
    }

    function testMemberCantVoteWhenElectionEnded() public {
        vm.prank(chairman);
        partyManager.setElectionId();
        vm.prank(chairman);
        uint256 creationTime = block.timestamp;
        partyManager.createElection(START, END_1H, DEADLINE);

        setupValidMember();
        vm.prank(user1);
        partyManager.registerCandidate("Alice", 2345);

        vm.warp(creationTime + END_1H + 1);

        vm.prank(user1);
        vm.expectRevert();
        partyManager.voteforPrimaryElection(1, electionId);
    }

    function testMemberCantVotewithInvalidCandidateId() public {
        vm.prank(chairman);
        partyManager.setElectionId();
        vm.prank(chairman);
        partyManager.createElection(START, END_2H, DEADLINE);

        setupValidMember();
        vm.startPrank(user1);
        partyManager.registerCandidate("Alice", 2345);
        vm.expectRevert();
        partyManager.voteforPrimaryElection(5, electionId);
        vm.stopPrank();
    }

    function testAttackerCantVoteForPrimaryElection() public {
        vm.prank(address(this));
        nationalElectionBody.setElectionId(electionId);
        vm.prank(chairman);
        partyManager.setElectionId();
        vm.prank(chairman);
        partyManager.createElection(START, END_2H, DEADLINE);

        setupValidMember();
        vm.prank(user1);
        partyManager.registerCandidate("Alice", 2345);

        vm.prank(attacker);
        vm.expectRevert();
        partyManager.voteforPrimaryElection(1, electionId);
        assertEq(partyManager.getPartyCandidate(electionId, 1).voteCount, 0);
    }

    function testAdminCanDeclareWinner() public {
        vm.prank(address(this));
        nationalElectionBody.setElectionId(electionId);
        vm.prank(chairman);
        partyManager.setElectionId();
        vm.startPrank(chairman);
        uint256 creationTime = block.timestamp;
        partyManager.createElection(START, END_1H, DEADLINE);
        vm.stopPrank();

        setupValidMember();
        vm.prank(user1);
        partyManager.registerCandidate("Alice", 2345);

        vm.warp(creationTime + START + 1);

        vm.prank(user1);
        partyManager.voteforPrimaryElection(1, electionId);

        vm.warp(creationTime + END_1H + 1);

        vm.prank(chairman);
        partyManager.declareWinner(electionId);
    }

    function testAdminCantDeclareWinnerWhenElectionisOngoing() public {
        vm.prank(address(this));
        nationalElectionBody.setElectionId(electionId);
        vm.prank(chairman);
        partyManager.setElectionId();
        vm.startPrank(chairman);
        uint256 creationTime = block.timestamp;
        partyManager.createElection(START, END_1H, DEADLINE);
        vm.stopPrank();

        setupValidMember();
        vm.prank(user1);
        partyManager.registerCandidate("Alice", 2345);

        vm.warp(creationTime + START + 1);

        vm.prank(user1);
        partyManager.voteforPrimaryElection(1, electionId);

        vm.prank(chairman);
        vm.expectRevert();
        partyManager.declareWinner(electionId);
    }

    function testAttackerCantDeclareWinner() public {
        vm.prank(address(this));
        nationalElectionBody.setElectionId(electionId);
        vm.prank(chairman);
        partyManager.setElectionId();
        vm.startPrank(chairman);
        uint256 creationTime = block.timestamp;
        partyManager.createElection(START, END_1H, DEADLINE);
        vm.stopPrank();

        setupValidMember();
        vm.prank(user1);
        partyManager.registerCandidate("Alice", 2345);

        vm.warp(creationTime + START + 1);

        vm.prank(user1);
        partyManager.voteforPrimaryElection(1, electionId);

        vm.warp(creationTime + END_1H + 1);

        vm.prank(attacker);
        vm.expectRevert();
        partyManager.declareWinner(electionId);
    }

    function testRegisterWinnerWithElectionBody() public {
        vm.prank(address(this));
        nationalElectionBody.setElectionId(electionId);
        vm.prank(chairman);
        partyManager.setElectionId();
        vm.startPrank(chairman);
        uint256 creationTime = block.timestamp;
        partyManager.createElection(START, END_1H, DEADLINE);
        vm.stopPrank();

        setupValidMember();
        vm.prank(user1);
        partyManager.registerCandidate("Alice", 2345);

        vm.warp(creationTime + START + 1);

        vm.prank(user1);
        partyManager.voteforPrimaryElection(1, electionId);

        vm.warp(creationTime + END_1H + 1);

        // Grant partyManager the PARTY_PRIMARIES_ROLE so it can call setCandidate on NationalElectionBody
        vm.prank(address(this));
        electionBodyInstance.grantRole(electionBodyInstance.PARTY_PRIMARIES_ROLE(), address(partyManager));

        // Register APC as a party in NationalElectionBody and approve it so setCandidate passes the approval check
        vm.prank(centralBankAddress);
        nationalToken.mint(chairman, 100_000 * (10 ** 18));
        vm.startPrank(chairman);
        nationalToken.approve(address(electionBodyInstance), electionBodyInstance.registrationFee());
        electionBodyInstance.registerParty("Apc", electionId, "Apc");
        vm.stopPrank();
        vm.prank(address(this));
        electionBodyInstance.approveAppliedParty("Apc", electionId);

        vm.startPrank(chairman);
        partyManager.declareWinner(electionId);
        partyManager.registerWinnerWithElectionBody(electionId);
        vm.stopPrank();

        assertEq(electionBodyInstance.getPartyCandidate("Apc", electionId).Address, user1);
        assertEq(electionBodyInstance.getPartyCandidate("Apc", electionId).Name, "Alice");
        assertTrue(partyManager.winnerDeclared(electionId));
    }

    function testCantRegisterWinnerBeforeDeclaring() public {
        vm.prank(address(this));
        nationalElectionBody.setElectionId(electionId);
        vm.prank(chairman);
        partyManager.setElectionId();
        vm.prank(chairman);
        partyManager.createElection(START, END_1H, DEADLINE);

        vm.prank(chairman);
        vm.expectRevert(
            abi.encodeWithSelector(PoliticalPartyManager.ElectionIsOngoing.selector)
        );
        partyManager.registerWinnerWithElectionBody(electionId);
    }

    function testAttackerCantRegisterWinnerWithElectionBody() public {
        vm.prank(address(this));
        nationalElectionBody.setElectionId(electionId);
        vm.prank(chairman);
        partyManager.setElectionId();
        vm.startPrank(chairman);
        uint256 creationTime = block.timestamp;
        partyManager.createElection(START, END_1H, DEADLINE);
        vm.stopPrank();

        setupValidMember();
        vm.prank(user1);
        partyManager.registerCandidate("Alice", 2345);

        vm.warp(creationTime + START + 1);
        vm.prank(user1);
        partyManager.voteforPrimaryElection(1, electionId);

        vm.warp(creationTime + END_1H + 1);
        vm.prank(chairman);
        partyManager.declareWinner(electionId);

        vm.prank(attacker);
        vm.expectRevert();
        partyManager.registerWinnerWithElectionBody(electionId);
    }
}
