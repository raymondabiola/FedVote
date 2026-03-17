// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import "../src/Elections.sol";

// MOCK CONTRACTS

contract MockRegistry is IRegistry {

    mapping(address => bytes32) public addressToNin;
    mapping(bytes32 => RegisteredVoter) public voters;

    // Failure flags for try/catch coverage
    bool public shouldFailIncrement;
    bool public shouldFailReset;

    function setShouldFailIncrement(bool _v) external { shouldFailIncrement = _v; }
    function setShouldFailReset(bool _v)     external { shouldFailReset = _v; }

    // Test helper
    function setVoter(address _addr, bytes32 _nin, bool _isReg, uint256 _streak) external {
        addressToNin[_addr] = _nin;
        voters[_nin].isRegistered = _isReg;
        voters[_nin].voterAddress = _addr;
        voters[_nin].voterStreak  = _streak;
    }

    // IRegistry implementation
    function getValidNINHashForAddress(address _addr) external view returns (bytes32) {
        return addressToNin[_addr];
    }

    function registeredVoter(bytes32 _ninHash) external view returns (RegisteredVoter memory) {
        return voters[_ninHash];
    }

    function incrementVoterStreak(address _voter) external {
        if (shouldFailIncrement) revert("Registry increment failed");
        voters[addressToNin[_voter]].voterStreak++;
    }

    function resetVoterStreak(address _voter) external {
        if (shouldFailReset) revert("Registry reset failed");
        voters[addressToNin[_voter]].voterStreak = 0;
    }
}

contract MockBadge is IDemocracyBadge {

    mapping(address => uint256) public balances;
    bool public shouldFailMint;

    function setShouldFailMint(bool _v) external { shouldFailMint = _v; }

    function mintDemocracyBadge(address to) external {
        if (shouldFailMint) revert("Mint failed");
        balances[to]++;
    }

    function balanceOf(address owner) external view returns (uint256) {
        return balances[owner];
    }
}

contract MockElectionBody is IElectionBody {

    uint256 private _electionId = 1;

    // Lets tests simulate advancing the election cycle
    function setElectionId(uint256 _id) external { _electionId = _id; }

    function electionId() external view returns (uint256) {
        return _electionId;
    }

    function isPartyRegistered(string memory _partyAcronym, uint256 /*_electionId*/) external pure returns (bool) {
        // "INVALID" simulates an unregistered party
        return keccak256(abi.encodePacked(_partyAcronym)) != keccak256(abi.encodePacked("INVALID"));
    }

    function getPartyCandidate(string memory _partyAcronym, uint256 /*_electionId*/) external pure returns (CandidateStruct memory) {
        // "EMPTY_PARTY" simulates a registered party with no candidate yet
        if (keccak256(abi.encodePacked(_partyAcronym)) == keccak256(abi.encodePacked("EMPTY_PARTY"))) {
            return CandidateStruct({ PartyId: 0, Name: "", PartyAcronym: _partyAcronym, Address: address(0) });
        }
        return CandidateStruct({
            PartyId:      1,
            Name:         "Valid Candidate",
            PartyAcronym: _partyAcronym,
            Address:      address(0x1)
        });
    }
}

// TEST SUITE

contract ElectionTest is Test {

    Election election;
    MockRegistry registry;
    MockBadge badge;
    MockElectionBody electionBody;

    address admin    = address(1);
    address officer  = address(2);
    address voter1   = address(3);  // fresh voter, streak 0
    address voter2   = address(4);  // streak 2, ready for badge
    address voter3   = address(5);  // standard voter
    address nonVoter = address(6);  // not in registry

    bytes32 voter1Nin = keccak256("NIN1");
    bytes32 voter2Nin = keccak256("NIN2");
    bytes32 voter3Nin = keccak256("NIN3");

    // SETUP

    function setUp() public {
        registry     = new MockRegistry();
        badge        = new MockBadge();
        electionBody = new MockElectionBody();

        vm.startPrank(admin);
        election = new Election(address(registry), address(badge), address(electionBody));
        election.grantRole(election.ELECTION_OFFICER_ROLE(), officer);
        vm.stopPrank();

        registry.setVoter(voter1, voter1Nin, true, 0);
        registry.setVoter(voter2, voter2Nin, true, 2);
        registry.setVoter(voter3, voter3Nin, true, 0);
    }

    // HELPERS

    function _createStandardElection() internal {
        vm.startPrank(officer);
        string[] memory parties = new string[](2);
        parties[0] = "APC";
        parties[1] = "PDP";
        election.createElection("General Election", 24, parties);
        vm.stopPrank();
    }

    function _accredit(address _voter) internal {
        vm.prank(_voter);
        election.accreditMyself();
    }

    // ELECTION CREATION

    function test_createElection_success() public {
        _createStandardElection();
        (string memory name,,,,bool isActive,,, ) = election.elections(1);
        assertEq(name, "General Election");
        assertTrue(isActive);
        assertEq(election.electionCount(), 1);
    }

    function test_createElection_stores_electionBodyId() public {
        _createStandardElection();
        (, uint256 bodyId,,,,,, ) = election.elections(1);
        assertEq(bodyId, electionBody.electionId());
    }

    function test_createElection_reverts_for_non_officer() public {
        vm.prank(voter1);
        string[] memory parties = new string[](1);
        parties[0] = "APC";
        vm.expectRevert();
        election.createElection("Fake", 24, parties);
    }

    function test_createElection_reverts_no_parties() public {
        vm.startPrank(officer);
        string[] memory parties = new string[](0);
        vm.expectRevert("No parties provided");
        election.createElection("Empty", 24, parties);
        vm.stopPrank();
    }

    function test_createElection_reverts_invalid_party() public {
        vm.startPrank(officer);
        string[] memory parties = new string[](1);
        parties[0] = "INVALID";
        vm.expectRevert("Party not registered for this election");
        election.createElection("Fail", 24, parties);
        vm.stopPrank();
    }

    function test_createElection_reverts_while_previous_active() public {
        _createStandardElection();
        vm.startPrank(officer);
        string[] memory parties = new string[](1);
        parties[0] = "APC";
        vm.expectRevert("Previous election still active");
        election.createElection("Second", 24, parties);
        vm.stopPrank();
    }

    // SELF-ACCREDITATION

    function test_accreditMyself_success() public {
        _createStandardElection();
        _accredit(voter1);
        assertTrue(election.isAccreditedForElection(1, voter1));
    }

    function test_accreditMyself_reverts_no_election_created() public {
        vm.prank(voter1);
        vm.expectRevert(Election.NoActiveElection.selector);
        election.accreditMyself();
    }

    function test_accreditMyself_reverts_election_ended() public {
        _createStandardElection();
        vm.warp(block.timestamp + 25 hours);
        vm.prank(officer);
        election.endElection(1);

        vm.prank(voter1);
        vm.expectRevert(Election.ElectionAlreadyEnded.selector);
        election.accreditMyself();
    }

    function test_accreditMyself_reverts_not_linked_to_nin() public {
        _createStandardElection();
        vm.prank(nonVoter);
        vm.expectRevert(Election.AddressNotLinkedToNIN.selector);
        election.accreditMyself();
    }

    function test_accreditMyself_reverts_not_registered_voter() public {
        _createStandardElection();
        registry.setVoter(nonVoter, keccak256("NIN99"), false, 0);
        vm.prank(nonVoter);
        vm.expectRevert(Election.NotARegisteredVoter.selector);
        election.accreditMyself();
    }

    function test_accreditMyself_reverts_already_accredited() public {
        _createStandardElection();
        _accredit(voter1);
        vm.prank(voter1);
        vm.expectRevert(Election.AlreadyAccredited.selector);
        election.accreditMyself();
    }

    // VOTING

    function test_vote_success() public {
        _createStandardElection();
        _accredit(voter1);
        vm.prank(voter1);
        election.vote(1, "APC");
        assertEq(election.voteCounts(1, "APC"), 1);
        assertTrue(election.hasVoted(1, voter1));
    }

    function test_vote_reverts_not_accredited() public {
        _createStandardElection();
        vm.prank(voter1);
        vm.expectRevert(Election.NotAccredited.selector);
        election.vote(1, "APC");
    }

    function test_vote_reverts_double_voting() public {
        _createStandardElection();
        _accredit(voter1);
        vm.startPrank(voter1);
        election.vote(1, "APC");
        vm.expectRevert(Election.AlreadyVoted.selector);
        election.vote(1, "APC");
        vm.stopPrank();
    }

    function test_vote_reverts_party_not_in_election() public {
        _createStandardElection();
        _accredit(voter1);
        vm.prank(voter1);
        vm.expectRevert("Party not in this election");
        election.vote(1, "LP"); // LP was not added to this election
    }

    function test_vote_reverts_no_candidate_for_party() public {
        // Create an election with EMPTY_PARTY (registered but no candidate)
        vm.startPrank(officer);
        string[] memory parties = new string[](1);
        parties[0] = "EMPTY_PARTY";
        election.createElection("Empty Candidate Election", 24, parties);
        vm.stopPrank();

        _accredit(voter1);
        vm.prank(voter1);
        vm.expectRevert(Election.NoCandidateForParty.selector);
        election.vote(1, "EMPTY_PARTY");
    }

    function test_vote_reverts_election_not_active() public {
        _createStandardElection();
        _accredit(voter1);
        vm.warp(block.timestamp + 25 hours);
        vm.prank(officer);
        election.endElection(1);

        vm.prank(voter1);
        vm.expectRevert(Election.ElectionNotActive.selector);
        election.vote(1, "APC");
    }

    // STREAKS & BADGES

    function test_streak_increments_on_vote() public {
        _createStandardElection();
        _accredit(voter1);
        vm.prank(voter1);
        election.vote(1, "APC");
        IRegistry.RegisteredVoter memory v = registry.registeredVoter(voter1Nin);
        assertEq(v.voterStreak, 1);
    }

    function test_badge_minted_at_threshold() public {
        _createStandardElection();
        _accredit(voter2); // voter2 has streak 2

        vm.prank(voter2);
        vm.expectEmit(true, false, false, false);
        emit Election.DemocracyBadgeAwarded(voter2);
        election.vote(1, "APC");

        assertEq(badge.balanceOf(voter2), 1);
    }

    function test_badge_not_minted_twice() public {
        _createStandardElection();
        _accredit(voter2);
        vm.prank(voter2);
        election.vote(1, "APC");
        assertEq(badge.balanceOf(voter2), 1);

        // Manually bump streak to 5 (threshold - 1 again relative to 6)
        // Simulate a second election to check badge is not re-minted
        vm.warp(block.timestamp + 25 hours);
        vm.prank(officer);
        election.endElection(1);

        electionBody.setElectionId(2);
        vm.startPrank(officer);
        string[] memory parties = new string[](1);
        parties[0] = "APC";
        election.createElection("Election 2", 24, parties);
        vm.stopPrank();

        _accredit(voter2);
        vm.prank(voter2);
        election.vote(2, "APC");

        // Badge balance must still be 1 (not minted again below threshold)
        assertEq(badge.balanceOf(voter2), 1);
    }

    function test_streak_reset_on_missed_election() public {
        // Election 1 — voter1 votes
        _createStandardElection();
        _accredit(voter1);
        vm.prank(voter1);
        election.vote(1, "APC"); // streak -> 1

        // End election 1
        vm.warp(block.timestamp + 25 hours);
        vm.prank(officer);
        election.endElection(1);

        // Election 2 — voter1 skips
        electionBody.setElectionId(2);
        vm.startPrank(officer);
        string[] memory parties = new string[](1);
        parties[0] = "APC";
        election.createElection("Election 2", 24, parties);
        vm.stopPrank();

        vm.warp(block.timestamp + 25 hours);
        vm.prank(officer);
        election.endElection(2);

        // Election 3 — voter1 votes again (missed election 2)
        electionBody.setElectionId(3);
        vm.startPrank(officer);
        election.createElection("Election 3", 24, parties);
        vm.stopPrank();

        _accredit(voter1);
        vm.prank(voter1);
        vm.expectEmit(true, false, false, false);
        emit Election.StreakReset(voter1);
        election.vote(3, "APC");

        // Streak should be 1: reset to 0 then incremented for this vote
        IRegistry.RegisteredVoter memory v = registry.registeredVoter(voter1Nin);
        assertEq(v.voterStreak, 1);
    }

    //  TRY/CATCH SILENT FAILURES

    function test_vote_succeeds_if_registry_increment_fails() public {
        _createStandardElection();
        _accredit(voter1);
        registry.setShouldFailIncrement(true);

        vm.prank(voter1);
        election.vote(1, "APC"); // must not revert

        assertEq(election.voteCounts(1, "APC"), 1);
        // Streak not updated
        IRegistry.RegisteredVoter memory v = registry.registeredVoter(voter1Nin);
        assertEq(v.voterStreak, 0);
    }

    function test_vote_succeeds_if_registry_reset_fails() public {
        // Setup: vote in election 1
        _createStandardElection();
        _accredit(voter1);
        vm.prank(voter1);
        election.vote(1, "APC");

        vm.warp(block.timestamp + 25 hours);
        vm.prank(officer);
        election.endElection(1);

        // Skip election 2
        electionBody.setElectionId(2);
        vm.startPrank(officer);
        string[] memory parties = new string[](1);
        parties[0] = "APC";
        election.createElection("Election 2", 24, parties);
        vm.stopPrank();

        vm.warp(block.timestamp + 25 hours);
        vm.prank(officer);
        election.endElection(2);

        // Election 3 — reset will fail
        electionBody.setElectionId(3);
        vm.startPrank(officer);
        election.createElection("Election 3", 24, parties);
        vm.stopPrank();

        _accredit(voter1);
        registry.setShouldFailReset(true);

        vm.prank(voter1);
        election.vote(3, "APC"); // must not revert

        assertEq(election.voteCounts(3, "APC"), 1);
    }

    function test_vote_succeeds_if_badge_mint_fails() public {
        _createStandardElection();
        _accredit(voter2); // streak 2
        badge.setShouldFailMint(true);

        vm.prank(voter2);
        election.vote(1, "APC"); // must not revert

        assertEq(badge.balanceOf(voter2), 0); // mint silently failed
        assertEq(election.voteCounts(1, "APC"), 1);
    }

    // END ELECTION & RESULTS

    function test_endElection_clear_winner() public {
        _createStandardElection();
        _accredit(voter1);
        _accredit(voter2);
        _accredit(voter3);

        vm.prank(voter1); election.vote(1, "APC");
        vm.prank(voter2); election.vote(1, "APC");
        vm.prank(voter3); election.vote(1, "PDP");

        vm.warp(block.timestamp + 25 hours);
        vm.prank(officer);
        vm.expectEmit(true, false, false, true);
        emit Election.ElectionEnded(1, "APC", 2, false);
        election.endElection(1);

        (string memory winner, bool isTie) = election.getElectionResult(1);
        assertEq(winner, "APC");
        assertFalse(isTie);
    }

    function test_endElection_tie() public {
        _createStandardElection();
        _accredit(voter1);
        _accredit(voter2);

        vm.prank(voter1); election.vote(1, "APC");
        vm.prank(voter2); election.vote(1, "PDP");

        vm.warp(block.timestamp + 25 hours);
        vm.prank(officer);
        vm.expectEmit(true, false, false, true);
        emit Election.ElectionEnded(1, "No Winner (Tie)", 1, true);
        election.endElection(1);

        (string memory winner, bool isTie) = election.getElectionResult(1);
        assertEq(winner, "No Winner (Tie)");
        assertTrue(isTie);
    }

    function test_endElection_no_votes() public {
        _createStandardElection();
        vm.warp(block.timestamp + 25 hours);
        vm.prank(officer);
        vm.expectEmit(true, false, false, true);
        emit Election.ElectionEnded(1, "No Votes", 0, false);
        election.endElection(1);

        (string memory winner, bool isTie) = election.getElectionResult(1);
        assertEq(winner, "No Votes");
        assertFalse(isTie);
    }

    function test_endElection_reverts_time_not_passed() public {
        _createStandardElection();
        vm.prank(officer);
        vm.expectRevert(Election.ElectionTimeNotPassed.selector);
        election.endElection(1);
    }

    function test_endElection_reverts_for_non_officer() public {
        _createStandardElection();
        vm.warp(block.timestamp + 25 hours);
        vm.prank(voter1);
        vm.expectRevert();
        election.endElection(1);
    }

    function test_endElection_reverts_already_ended() public {
        _createStandardElection();
        vm.warp(block.timestamp + 25 hours);
        vm.prank(officer);
        election.endElection(1);

        vm.prank(officer);
        vm.expectRevert(Election.ElectionNotActive.selector);
        election.endElection(1);
    }

    function test_getElectionResult_returns_winner_on_chain() public {
        _createStandardElection();
        _accredit(voter1);
        vm.prank(voter1);
        election.vote(1, "PDP");

        vm.warp(block.timestamp + 25 hours);
        vm.prank(officer);
        election.endElection(1);

        (string memory winner,) = election.getElectionResult(1);
        assertEq(winner, "PDP");
    }
}
