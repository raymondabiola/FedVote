// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import "../src/Elections.sol";

// ─────────────────────────────────────────────
//  MOCK CONTRACTS
// ─────────────────────────────────────────────

contract MockRegistry is IRegistry {

    mapping(address => bytes32) public addressToNin;
    mapping(bytes32 => RegisteredVoter) public voters;

    bool public shouldFailIncrement;
    bool public shouldFailReset;

    function setShouldFailIncrement(bool _v) external { shouldFailIncrement = _v; }
    function setShouldFailReset(bool _v)     external { shouldFailReset = _v; }

    function setVoter(
        address  _addr,
        bytes32  _nin,
        bool     _isReg,
        uint256  _streak
    ) external {
        addressToNin[_addr]          = _nin;
        voters[_nin].isRegistered    = _isReg;
        voters[_nin].voterAddress    = _addr;
        voters[_nin].voterStreak     = _streak;
    }

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

    function setElectionId(uint256 _id) external { _electionId = _id; }

    function electionId() external view returns (uint256) {
        return _electionId;
    }

    // Any acronym except "INVALID" is treated as registered
    function isPartyRegistered(
        string memory _partyAcronym,
        uint256 /*_electionId*/
    ) external pure returns (bool) {
        return keccak256(abi.encodePacked(_partyAcronym))
            != keccak256(abi.encodePacked("INVALID"));
    }

    // "EMPTY_PARTY" returns an empty Name to simulate a party with no candidate set
    function getPartyCandidate(
        string memory _partyAcronym,
        uint256 /*_electionId*/
    ) external pure returns (CandidateStruct memory) {
        if (keccak256(abi.encodePacked(_partyAcronym))
            == keccak256(abi.encodePacked("EMPTY_PARTY")))
        {
            return CandidateStruct({
                PartyId:      0,
                Name:         "",
                PartyAcronym: _partyAcronym,
                Address:      address(0)
            });
        }
        return CandidateStruct({
            PartyId:      1,
            Name:         "Valid Candidate",
            PartyAcronym: _partyAcronym,
            Address:      address(0x1)
        });
    }
}

// ─────────────────────────────────────────────
//  TEST SUITE
// ─────────────────────────────────────────────

contract ElectionTest is Test {

    // ── Contracts ───────────────────────────
    Election         public election;
    MockRegistry     public registry;
    MockBadge        public badge;
    MockElectionBody public electionBody;

    // ── Actors ──────────────────────────────
    address admin    = address(1);
    address officer  = address(2);
    address voter1   = address(3);   // fresh voter,  streak 0
    address voter2   = address(4);   // streak 2, one vote from badge
    address voter3   = address(5);   // standard voter, streak 0
    address nonVoter = address(6);   // not registered in registry

    bytes32 voter1Nin = keccak256("NIN1");
    bytes32 voter2Nin = keccak256("NIN2");
    bytes32 voter3Nin = keccak256("NIN3");

    // ── Time constants ──────────────────────
    // START_TIME = 0  → election opens immediately on creation
    // END_TIME        → election window length
    uint256 constant START_TIME = 0;
    uint256 constant END_TIME   = 24 hours;

    // ─── SETUP ────────────────────────────────────────────────────────────────

    function setUp() public {
        registry     = new MockRegistry();
        badge        = new MockBadge();
        electionBody = new MockElectionBody();

        vm.startPrank(admin);
        election = new Election(
            address(registry),
            address(badge),
            address(electionBody)
        );
        election.grantRole(election.ELECTION_OFFICER_ROLE(), officer);
        vm.stopPrank();

        registry.setVoter(voter1, voter1Nin, true, 0);
        registry.setVoter(voter2, voter2Nin, true, 2);
        registry.setVoter(voter3, voter3Nin, true, 0);
    }

    // ─── INTERNAL HELPERS ─────────────────────────────────────────────────────

    /// Creates a standard two-party election that starts immediately.
    function _createStandardElection() internal {
        string[] memory parties = new string[](2);
        parties[0] = "APC";
        parties[1] = "PDP";
        vm.startPrank(officer);
        election.createElection("General Election", parties, START_TIME, END_TIME);
        vm.stopPrank();
    }

    function _accredit(address _voter) internal {
        vm.prank(_voter);
        election.accreditMyself();
    }

    // ─── ELECTION CREATION ────────────────────────────────────────────────────

    function test_createElection_success() public {
        _createStandardElection();
        uint256 id = election.currentElectionId();

        (
            string memory name,
            uint256 storedElectionId,
            ,
            ,
            bool isActive,
            ,
        ) = election.elections(id);

        assertEq(name, "General Election");
        assertEq(storedElectionId, 1); // MockElectionBody starts at id 1
        assertTrue(isActive);
        assertEq(id, 1);
    }

    function test_createElection_stores_electionBodyId() public {
        _createStandardElection();
        uint256 id = election.currentElectionId();
        (, uint256 storedId, , , , , ) = election.elections(id);
        assertEq(storedId, electionBody.electionId());
    }

    function test_createElection_reverts_for_non_officer() public {
        string[] memory parties = new string[](1);
        parties[0] = "APC";
        vm.prank(voter1);
        vm.expectRevert(); // AccessControl generic revert
        election.createElection("Fake", parties, START_TIME, END_TIME);
    }

    function test_createElection_reverts_no_parties() public {
        string[] memory parties = new string[](0);
        vm.prank(officer);
        vm.expectRevert(
            abi.encodeWithSelector(Election.NoPartiesProvided.selector)
        );
        election.createElection("Empty", parties, START_TIME, END_TIME);
    }

    function test_createElection_reverts_invalid_party() public {
        string[] memory parties = new string[](1);
        parties[0] = "INVALID";
        vm.prank(officer);
        vm.expectRevert(
            abi.encodeWithSelector(Election.PartyNotRegisteredForThisElection.selector)
        );
        election.createElection("Fail", parties, START_TIME, END_TIME);
    }

    function test_createElection_reverts_while_previous_active() public {
        _createStandardElection();
        string[] memory parties = new string[](1);
        parties[0] = "APC";
        vm.prank(officer);
        vm.expectRevert(
            abi.encodeWithSelector(Election.CurrentElectionIsActive.selector)
        );
        election.createElection("Second", parties, START_TIME, END_TIME);
    }

    function test_createElection_reverts_invalid_end_time() public {
        string[] memory parties = new string[](1);
        parties[0] = "APC";
        vm.prank(officer);
        vm.expectRevert(
            abi.encodeWithSelector(Election.InvalidEndTime.selector)
        );
        election.createElection("Bad EndTime", parties, START_TIME, 0);
    }

    function test_createElection_reverts_end_before_start() public {
        string[] memory parties = new string[](1);
        parties[0] = "APC";
        vm.prank(officer);
        // _startTime (5h) > _endTime (2h)
        vm.expectRevert(
            abi.encodeWithSelector(Election.EndTimeMustBeGreaterThanStartTime.selector)
        );
        election.createElection("Bad Order", parties, 5 hours, 2 hours);
    }

    function test_createElection_reverts_duration_too_short() public {
        string[] memory parties = new string[](1);
        parties[0] = "APC";
        vm.prank(officer);
        // endTime - startTime = 1799 < 1800 seconds (30 mins)
        vm.expectRevert(
            abi.encodeWithSelector(Election.ElectionDurationMustBeAtLeast30Mins.selector)
        );
        election.createElection("Too Short", parties, 0, 1799);
    }

    // ─── SELF-ACCREDITATION ───────────────────────────────────────────────────

    function test_accreditMyself_success() public {
        _createStandardElection();
        _accredit(voter1);
        uint256 id = election.currentElectionId();
        assertTrue(election.isAccreditedForElection(id, voter1));
    }

    function test_accreditMyself_reverts_no_election_created() public {
        // currentElectionId is 0 before any election is created
        vm.prank(voter1);
        vm.expectRevert(
            abi.encodeWithSelector(Election.NoActiveElection.selector)
        );
        election.accreditMyself();
    }

    /// Timestamp past endTime — accreditMyself reverts with ElectionEnded.
    function test_accreditMyself_reverts_election_ended_by_timestamp() public {
        _createStandardElection();
        vm.warp(block.timestamp + END_TIME + 1);
        vm.prank(voter1);
        vm.expectRevert(
            abi.encodeWithSelector(Election.ElectionHasEnded.selector)
        );
        election.accreditMyself();
    }

    /// After declareWinner() sets isActive = false, accreditMyself reverts ElectionNotActive.
    function test_accreditMyself_reverts_after_winner_declared() public {
        _createStandardElection();
        vm.warp(block.timestamp + END_TIME + 1);
        vm.prank(officer);
        election.declareWinner();

        vm.prank(voter1);
        vm.expectRevert(
            abi.encodeWithSelector(Election.ElectionNotActive.selector)
        );
        election.accreditMyself();
    }

    function test_accreditMyself_reverts_not_linked_to_nin() public {
        _createStandardElection();
        vm.prank(nonVoter); // nonVoter has no NIN in registry
        vm.expectRevert(
            abi.encodeWithSelector(Election.AddressNotLinkedToNIN.selector)
        );
        election.accreditMyself();
    }

    function test_accreditMyself_reverts_not_registered_voter() public {
        _createStandardElection();
        registry.setVoter(nonVoter, keccak256("NIN99"), false, 0); // NIN linked but isRegistered = false
        vm.prank(nonVoter);
        vm.expectRevert(
            abi.encodeWithSelector(Election.NotARegisteredVoter.selector)
        );
        election.accreditMyself();
    }

    function test_accreditMyself_reverts_already_accredited() public {
        _createStandardElection();
        _accredit(voter1);
        vm.prank(voter1);
        vm.expectRevert(
            abi.encodeWithSelector(Election.AlreadyAccredited.selector)
        );
        election.accreditMyself();
    }

    // ─── VOTING ───────────────────────────────────────────────────────────────

    function test_vote_success() public {
        _createStandardElection();
        _accredit(voter1);
        uint256 id = election.currentElectionId();

        vm.prank(voter1);
        election.vote("APC");

        assertEq(election.voteCounts(id, "APC"), 1);
        assertTrue(election.hasVoted(id, voter1));
    }

    function test_vote_reverts_not_accredited() public {
        _createStandardElection();
        vm.prank(voter1);
        vm.expectRevert(
            abi.encodeWithSelector(Election.NotAccredited.selector)
        );
        election.vote("APC");
    }

    function test_vote_reverts_double_voting() public {
        _createStandardElection();
        _accredit(voter1);
        vm.startPrank(voter1);
        election.vote("APC");
        vm.expectRevert(
            abi.encodeWithSelector(Election.AlreadyVoted.selector)
        );
        election.vote("APC");
        vm.stopPrank();
    }

    function test_vote_reverts_party_not_in_election() public {
        _createStandardElection();
        _accredit(voter1);
        vm.prank(voter1);
        vm.expectRevert(
            abi.encodeWithSelector(Election.PartyNotInThisElectionParticipatingList.selector)
        );
        election.vote("LP"); // LP was not added to this election
    }

    function test_vote_reverts_no_candidate_for_party() public {
        string[] memory parties = new string[](1);
        parties[0] = "EMPTY_PARTY";
        vm.prank(officer);
        election.createElection("Empty Candidate Election", parties, START_TIME, END_TIME);

        _accredit(voter1);
        vm.prank(voter1);
        vm.expectRevert(
            abi.encodeWithSelector(Election.NoCandidateForParty.selector)
        );
        election.vote("EMPTY_PARTY");
    }

    /// When startTime is in the future, voting should revert with ElectionNotStarted.
    function test_vote_reverts_before_start_time() public {
        string[] memory parties = new string[](1);
        parties[0] = "APC";
        vm.prank(officer);
        election.createElection("Future Election", parties, 1 hours, 25 hours);

        _accredit(voter1);
        vm.prank(voter1);
        vm.expectRevert(
            abi.encodeWithSelector(Election.ElectionNotStarted.selector)
        );
        election.vote("APC");
    }

    /// After endTime passes, voting should revert with ElectionEnded.
    function test_vote_reverts_after_end_time() public {
        _createStandardElection();
        _accredit(voter1);
        vm.warp(block.timestamp + END_TIME + 1);
        vm.prank(voter1);
        vm.expectRevert(
            abi.encodeWithSelector(Election.ElectionHasEnded.selector)
        );
        election.vote("APC");
    }

    // ─── STREAKS & BADGES ─────────────────────────────────────────────────────

    function test_streak_increments_on_vote() public {
        _createStandardElection();
        _accredit(voter1);
        vm.prank(voter1);
        election.vote("APC");

        IRegistry.RegisteredVoter memory v = registry.registeredVoter(voter1Nin);
        assertEq(v.voterStreak, 1);
    }

    function test_badge_minted_at_threshold() public {
        // voter2 has streak 2 — voting brings it to 3 (== BADGE_THRESHOLD)
        _createStandardElection();
        _accredit(voter2);

        vm.prank(voter2);
        vm.expectEmit(true, false, false, false);
        emit Election.DemocracyBadgeAwarded(voter2);
        election.vote("APC");

        assertEq(badge.balanceOf(voter2), 1);
    }

    function test_badge_not_minted_twice() public {
        // Election 1 — voter2 reaches threshold and receives badge
        uint256 t1 = block.timestamp;
        _createStandardElection();
        _accredit(voter2);
        vm.prank(voter2);
        election.vote("APC");
        assertEq(badge.balanceOf(voter2), 1);

        vm.warp(t1 + END_TIME + 1);
        vm.prank(officer);
        election.declareWinner();

        // Election 2
        electionBody.setElectionId(2);
        string[] memory parties = new string[](1);
        parties[0] = "APC";
        vm.prank(officer);
        election.createElection("Election 2", parties, START_TIME, END_TIME);

        _accredit(voter2);
        vm.prank(voter2);
        election.vote("APC");

        // Badge balance must still be 1
        assertEq(badge.balanceOf(voter2), 1);
    }

    function test_streak_reset_on_missed_election() public {
        // Election 1 — voter1 votes (streak → 1)
        uint256 t1 = block.timestamp;
        _createStandardElection();
        _accredit(voter1);
        vm.prank(voter1);
        election.vote("APC");

        vm.warp(t1 + END_TIME + 2);
        vm.prank(officer);
        election.declareWinner();

        // Election 2 — voter1 skips entirely
        electionBody.setElectionId(2);
        string[] memory parties = new string[](1);
        parties[0] = "APC";
        uint256 t2 = block.timestamp;
        vm.prank(officer);
        election.createElection("Election 2", parties, START_TIME, END_TIME);

        vm.warp(t2 + END_TIME + 1);
        vm.prank(officer);
        election.declareWinner();

        // Election 3 — voter1 votes again; missed election 2 so streak should reset
        electionBody.setElectionId(3);
        vm.prank(officer);
        election.createElection("Election 3", parties, START_TIME, END_TIME);

        _accredit(voter1);
        vm.prank(voter1);
        vm.expectEmit(true, false, false, false);
        emit Election.StreakReset(voter1);
        election.vote("APC");

        // Streak = 1: reset to 0 then incremented for this vote
        IRegistry.RegisteredVoter memory v = registry.registeredVoter(voter1Nin);
        assertEq(v.voterStreak, 1);
    }

    // ─── TRY/CATCH SILENT FAILURES ────────────────────────────────────────────

    function test_vote_succeeds_if_registry_increment_fails() public {
        _createStandardElection();
        _accredit(voter1);
        registry.setShouldFailIncrement(true);

        vm.prank(voter1);
        election.vote("APC"); // must NOT revert

        uint256 id = election.currentElectionId();
        assertEq(election.voteCounts(id, "APC"), 1);
        // Streak unchanged because increment silently failed
        IRegistry.RegisteredVoter memory v = registry.registeredVoter(voter1Nin);
        assertEq(v.voterStreak, 0);
    }

    function test_vote_succeeds_if_registry_reset_fails() public {
        // Election 1 — voter1 votes
        uint256 t1 = block.timestamp;
        _createStandardElection();
        _accredit(voter1);
        vm.prank(voter1);
        election.vote("APC");

        vm.warp(t1 + END_TIME + 2);
        vm.prank(officer);
        election.declareWinner();

        // Election 2 — voter1 skips
        electionBody.setElectionId(2);
        string[] memory parties = new string[](1);
        parties[0] = "APC";
        uint256 t2 = block.timestamp;
        vm.prank(officer);
        election.createElection("Election 2", parties, START_TIME, END_TIME);

        vm.warp(t2 + END_TIME + 1);
        vm.prank(officer);
        election.declareWinner();

        // Election 3 — reset will fail but vote must still succeed
        electionBody.setElectionId(3);
        vm.prank(officer);
        election.createElection("Election 3", parties, START_TIME, END_TIME);

        _accredit(voter1);
        registry.setShouldFailReset(true);

        vm.prank(voter1);
        election.vote("APC"); // must NOT revert

        assertEq(election.voteCounts(3, "APC"), 1);
    }

    function test_vote_succeeds_if_badge_mint_fails() public {
        _createStandardElection();
        _accredit(voter2); // streak 2
        badge.setShouldFailMint(true);

        vm.prank(voter2);
        election.vote("APC"); // must NOT revert

        uint256 id = election.currentElectionId();
        assertEq(badge.balanceOf(voter2), 0);        // mint silently failed
        assertEq(election.voteCounts(id, "APC"), 1); // vote still recorded
    }

    // ─── DECLARE WINNER & RESULTS ─────────────────────────────────────────────

    function test_declareWinner_clear_winner() public {
        _createStandardElection();
        _accredit(voter1);
        _accredit(voter2);
        _accredit(voter3);

        vm.prank(voter1); election.vote("APC");
        vm.prank(voter2); election.vote("APC");
        vm.prank(voter3); election.vote("PDP");

        uint256 id = election.currentElectionId();
        vm.warp(block.timestamp + END_TIME + 1);

        vm.prank(officer);
        vm.expectEmit(true, false, false, true);
        emit Election.ElectionEnded(id, "APC", 2, false);
        election.declareWinner();

        (string memory winner, bool isTie) = election.getElectionResult(id);
        assertEq(winner, "APC");
        assertFalse(isTie);
    }

    function test_declareWinner_tie() public {
        _createStandardElection();
        _accredit(voter1);
        _accredit(voter2);

        vm.prank(voter1); election.vote("APC");
        vm.prank(voter2); election.vote("PDP");

        uint256 id = election.currentElectionId();
        vm.warp(block.timestamp + END_TIME + 1);

        vm.prank(officer);
        vm.expectEmit(true, false, false, true);
        emit Election.ElectionEnded(id, "No Winner (Tie)", 1, true);
        election.declareWinner();

        (string memory winner, bool isTie) = election.getElectionResult(id);
        assertEq(winner, "No Winner (Tie)");
        assertTrue(isTie);
    }

    function test_declareWinner_no_votes() public {
        _createStandardElection();
        uint256 id = election.currentElectionId();
        vm.warp(block.timestamp + END_TIME + 1);

        vm.prank(officer);
        vm.expectEmit(true, false, false, true);
        emit Election.ElectionEnded(id, "No Votes", 0, false);
        election.declareWinner();

        (string memory winner, bool isTie) = election.getElectionResult(id);
        assertEq(winner, "No Votes");
        assertFalse(isTie);
    }

    function test_declareWinner_reverts_time_not_passed() public {
        _createStandardElection();
        vm.prank(officer);
        vm.expectRevert(
            abi.encodeWithSelector(Election.ElectionNotEnded.selector)
        );
        election.declareWinner();
    }

    function test_declareWinner_reverts_for_non_officer() public {
        _createStandardElection();
        vm.warp(block.timestamp + END_TIME + 1);
        vm.prank(voter1);
        vm.expectRevert(); // AccessControl generic revert
        election.declareWinner();
    }

    function test_declareWinner_reverts_if_called_twice() public {
        _createStandardElection();
        vm.warp(block.timestamp + END_TIME + 1);
        vm.prank(officer);
        election.declareWinner();

        vm.prank(officer);
        vm.expectRevert(
            abi.encodeWithSelector(Election.ElectionNotActive.selector)
        );
        election.declareWinner();
    }

    function test_declareWinner_sets_isActive_false() public {
        _createStandardElection();
        uint256 id = election.currentElectionId();
        vm.warp(block.timestamp + END_TIME + 1);
        vm.prank(officer);
        election.declareWinner();

        (, , , , bool isActive, , ) = election.elections(id);
        assertFalse(isActive);
    }

    function test_getElectionResult_returns_winner_on_chain() public {
        _createStandardElection();
        _accredit(voter1);
        vm.prank(voter1);
        election.vote("PDP");

        uint256 id = election.currentElectionId();
        vm.warp(block.timestamp + END_TIME + 1);
        vm.prank(officer);
        election.declareWinner();

        (string memory winner, ) = election.getElectionResult(id);
        assertEq(winner, "PDP");
    }

    // ─── CA UPDATE FUNCTIONS ──────────────────────────────────────────────────

    function test_updateDemocracyBadgeCA_success() public {
        address newBadge = address(new MockBadge());
        vm.prank(admin);
        election.updateDemocracyBadgeCA(newBadge);
        assertEq(address(election.democracyBadge()), newBadge);
    }

    function test_updateDemocracyBadgeCA_reverts_zero_address() public {
        vm.prank(admin);
        vm.expectRevert(
            abi.encodeWithSelector(Election.InvalidAddress.selector)
        );
        election.updateDemocracyBadgeCA(address(0));
    }

    function test_updateElectionBodyCA_success() public {
        address newBody = address(new MockElectionBody());
        vm.prank(admin);
        election.updateElectionBodyCA(newBody);
        assertEq(address(election.electionBody()), newBody);
    }

    function test_updateElectionBodyCA_reverts_zero_address() public {
        vm.prank(admin);
        vm.expectRevert(
            abi.encodeWithSelector(Election.InvalidAddress.selector)
        );
        election.updateElectionBodyCA(address(0));
    }

    function test_updateRegistryCA_success() public {
        address newReg = address(new MockRegistry());
        vm.prank(admin);
        election.updateRegistryCA(newReg);
        assertEq(address(election.registry()), newReg);
    }

    function test_updateRegistryCA_reverts_zero_address() public {
        vm.prank(admin);
        vm.expectRevert(
            abi.encodeWithSelector(Election.InvalidAddress.selector)
        );
        election.updateRegistryCA(address(0));
    }
}
