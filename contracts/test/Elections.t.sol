// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import "../src/Elections.sol"; 

// 1. UPDATED MOCK CONTRACTS

contract MockRegistry is IRegistry {
    mapping(address => bytes32) public addressToNin;
    mapping(bytes32 => RegisteredVoter) public voters;
    
    // Control flags to test try/catch blocks
    bool public shouldFailIncrement;
    bool public shouldFailSet;

    function setShouldFailIncrement(bool _status) external {
        shouldFailIncrement = _status;
    }

    function setShouldFailSet(bool _status) external {
        shouldFailSet = _status;
    }

    // Helper to setup mock data
    function setVoter(address _addr, bytes32 _nin, bool _isReg, uint256 _streak) external {
        addressToNin[_addr] = _nin;
        voters[_nin].isRegistered = _isReg;
        voters[_nin].voterAddress = _addr;
        voters[_nin].voterStreak = _streak;
    }

    // Interface Implementation

    function getValidNINHashForAddress(address _addr) external view returns (bytes32) {
        return addressToNin[_addr];
    }

    function registeredVoter(bytes32 _ninHash) external view returns (RegisteredVoter memory) {
        return voters[_ninHash];
    }
    
    // Increment Voter Streak
    function incrementVoterStreak(address _voter) external {
        if (shouldFailIncrement) {
            revert("Registry Increment Failed");
        }
        bytes32 nin = addressToNin[_voter];
        voters[nin].voterStreak++;
    }

    // Setter for resets
    function setVoterStreak(address _voter, uint256 _num) external {
        if (shouldFailSet) {
            revert("Registry Set Failed");
        }
        bytes32 nin = addressToNin[_voter];
        voters[nin].voterStreak = _num;
    }
}

contract MockBadge is IDemocracyBadge {
    mapping(address => uint256) public balances;
    bool public shouldFailMint;

    function setShouldFail(bool _status) external {
        shouldFailMint = _status;
    }
    
    function mintDemocracyBadge(address to) external {
        if (shouldFailMint) {
            revert("Mint Failed");
        }
        balances[to]++;
    }

    function balanceOf(address owner) external view returns (uint256) {
        return balances[owner];
    }
}

contract MockElectionBody is IElectionBody {
    function isPartyRegistered(string memory _partyName) external pure returns (bool) {
        // "INVALID" is a party that doesn't exist
        return keccak256(abi.encodePacked(_partyName)) != keccak256(abi.encodePacked("INVALID"));
    }

    function getPartyCandidate(string memory _partyName, uint256) external pure returns (PartyCandidate memory) {
        // Simulate a party having no candidate
        if (keccak256(abi.encodePacked(_partyName)) == keccak256(abi.encodePacked("EMPTY_PARTY"))) {
            return PartyCandidate({partyName: _partyName, candidateName: ""});
        }
        
        return PartyCandidate({
            partyName: _partyName,
            candidateName: "Valid Candidate"
        });
    }
}

// 2. COMPREHENSIVE TEST SUITE

contract ElectionTest is Test {
    Election election;
    MockRegistry registry;
    MockBadge badge;
    MockElectionBody electionBody;

    address admin = address(1);
    address officer = address(2);
    address voter1 = address(3);
    address voter2 = address(4);
    address voter3 = address(5);
    address nonVoter = address(6);

    bytes32 voter1Nin = keccak256("NIN1");
    bytes32 voter2Nin = keccak256("NIN2");
    bytes32 voter3Nin = keccak256("NIN3");

    function setUp() public {
        // Deploy Mocks
        registry = new MockRegistry();
        badge = new MockBadge();
        electionBody = new MockElectionBody();

        // Deploy Election
        vm.startPrank(admin);
        election = new Election(address(registry), address(badge), address(electionBody));
        
        // Grant Role
        bytes32 officerRole = election.ELECTION_OFFICER_ROLE();
        election.grantRole(officerRole, officer);
        vm.stopPrank();

        // Register Voters in Mock Registry
        // Voter 1: New voter
        registry.setVoter(voter1, voter1Nin, true, 0); 
        // Voter 2: Streak 2 (Ready for Badge)
        registry.setVoter(voter2, voter2Nin, true, 2); 
        // Voter 3: Standard voter
        registry.setVoter(voter3, voter3Nin, true, 0); 
    }

    // SECTION A: ELECTION CREATION

    function test_CreateElection_Success() public {
        vm.startPrank(officer);
        string[] memory parties = new string[](2);
        parties[0] = "PDP";
        parties[1] = "APC";
        
        election.createElection("Test Election", 24, parties);
        
        (string memory name, , , bool isActive, ) = election.electionDetails(1);
        assertEq(name, "Test Election");
        assertTrue(isActive);
        vm.stopPrank();
    }

    function test_CreateElection_Fail_Unauthorized() public {
        vm.prank(voter1);
        string[] memory parties = new string[](1);
        parties[0] = "APC";
        
        vm.expectRevert(); 
        election.createElection("Fake", 24, parties);
    }

    function test_CreateElection_Fail_NoParties() public {
        vm.startPrank(officer);
        string[] memory parties = new string[](0);
        
        vm.expectRevert("No parties provided");
        election.createElection("Fail", 24, parties);
        vm.stopPrank();
    }

    function test_CreateElection_Fail_InvalidParty() public {
        vm.startPrank(officer);
        string[] memory parties = new string[](1);
        parties[0] = "INVALID"; 
        
        vm.expectRevert("Party not registered globally");
        election.createElection("Fail", 24, parties);
        vm.stopPrank();
    }

    // SECTION B: SELF-ACCREDITATION

    function test_AccreditMyself_Success() public {
        _createStandardElection();
        
        vm.prank(voter1);
        election.accreditMyself();
        
        bool isAccredited = election.isAccreditedForElection(1, voter1);
        assertTrue(isAccredited);
    }

    function test_AccreditMyself_Fail_NoActiveElection() public {
        // No election created yet
        vm.prank(voter1);
        vm.expectRevert("No active election");
        election.accreditMyself();
    }

    function test_AccreditMyself_Fail_ElectionEnded() public {
        _createStandardElection();
        
        // Fast forward to end
        vm.warp(block.timestamp + 25 hours);
        vm.prank(officer);
        election.endElection(1);

        vm.prank(voter1);
        vm.expectRevert("Election ended");
        election.accreditMyself();
    }

    function test_AccreditMyself_Fail_NotLinked() public {
        _createStandardElection();
        
        vm.prank(nonVoter); // Address 6 is not in MockRegistry
        vm.expectRevert("Address not linked to NIN");
        election.accreditMyself();
    }

    function test_AccreditMyself_Fail_NotRegistered() public {
        _createStandardElection();
        
        // Add user to map, but set isRegistered = false
        registry.setVoter(nonVoter, keccak256("NIN99"), false, 0);

        vm.prank(nonVoter);
        vm.expectRevert("You are not a registered voter");
        election.accreditMyself();
    }

    function test_AccreditMyself_Fail_AlreadyAccredited() public {
        _createStandardElection();
        
        vm.startPrank(voter1);
        election.accreditMyself();
        
        vm.expectRevert("Already accredited for this election");
        election.accreditMyself();
        vm.stopPrank();
    }

    // VOTING MECHANICS

    function test_Vote_Success() public {
        _createStandardElection();
        _accreditSelf(voter1);

        vm.prank(voter1);
        election.vote(1, "APC");

        assertEq(election.voteCounts(1, "APC"), 1);
        assertTrue(election.hasVoted(1, voter1));
    }

    function test_Vote_Fail_DoubleVoting() public {
        _createStandardElection();
        _accreditSelf(voter1);

        vm.startPrank(voter1);
        election.vote(1, "APC");
        
        vm.expectRevert("Already voted");
        election.vote(1, "APC");
        vm.stopPrank();
    }

    function test_Vote_Fail_NotAccredited() public {
        _createStandardElection();
        // Skip accreditation
        
        vm.prank(voter1);
        vm.expectRevert("Not Accredited");
        election.vote(1, "APC");
    }

    function test_Vote_Fail_InvalidCandidate() public {
        vm.startPrank(officer);
        string[] memory parties = new string[](1);
        parties[0] = "EMPTY_PARTY"; // Mock returns empty candidate name
        election.createElection("Empty", 24, parties);
        vm.stopPrank();

        _accreditSelf(voter1);

        vm.prank(voter1);
        vm.expectRevert("Party invalid");
        election.vote(1, "EMPTY_PARTY");
    }

    // STREAKS & BADGES

    function test_Streak_Increments() public {
        _createStandardElection();
        _accreditSelf(voter1); // Start streak 0

        vm.prank(voter1);
        election.vote(1, "APC");

        // Verify Mock Registry was updated to 1
        IRegistry.RegisteredVoter memory v = registry.registeredVoter(voter1Nin);
        assertEq(v.voterStreak, 1);
    }

    function test_Badge_Minting_At_Threshold() public {
        // Voter2 starts with streak 2. Voting now should hit 3 and mint badge.
        _createStandardElection();
        _accreditSelf(voter2);

        vm.prank(voter2);
        vm.expectEmit(true, false, false, false);
        emit Election.DemocracyBadgeAwarded(voter2);
        election.vote(1, "APC");

        // Verify Badge Balance
        assertEq(badge.balanceOf(voter2), 1);
    }

    function test_Streak_Reset_On_Missed_Election() public {
        // 1. Create Election 1
        _createStandardElection(); // ID 1
        _accreditSelf(voter1);
        vm.prank(voter1);
        election.vote(1, "APC"); // Streak -> 1
        
        // 2. Create Election 2 (User skips this)
        vm.prank(officer);
        string[] memory parties = new string[](1);
        parties[0] = "APC";
        election.createElection("Election 2", 24, parties); // ID 2
        
        // 3. Create Election 3
        vm.prank(officer);
        election.createElection("Election 3", 24, parties); // ID 3
        
        _accreditSelf(voter1); // Accredit for 3
        
        // 4. Vote in Election 3 (Should detect missed #2)
        vm.prank(voter1);
        
        vm.expectEmit(true, false, false, false);
        emit Election.StreakReset(voter1); // Expect Reset Event
        
        election.vote(3, "APC");

        // Registry should show streak 1 because we called setVoterStreak(1)
        IRegistry.RegisteredVoter memory v = registry.registeredVoter(voter1Nin);
        assertEq(v.voterStreak, 1);
    }

    // TRY/CATCH COVERAGE

    function test_Vote_SilentFail_If_RegistryIncrementFails() public {
        _createStandardElection();
        _accreditSelf(voter1);

        registry.setShouldFailIncrement(true);

        vm.prank(voter1);
        // Should NOT revert
        election.vote(1, "APC");
        
        // Vote counted locally
        assertEq(election.voteCounts(1, "APC"), 1);
        // Streak NOT updated (remains 0)
        IRegistry.RegisteredVoter memory v = registry.registeredVoter(voter1Nin);
        assertEq(v.voterStreak, 0);
    }

    function test_Vote_SilentFail_If_RegistrySetFails() public {
        // Setup missed election scenario
        _createStandardElection(); 
        _accreditSelf(voter1);
        vm.prank(voter1); election.vote(1, "APC"); // Voted in 1

        // Skip 2
        vm.prank(officer);
        string[] memory parties = new string[](1);
        parties[0] = "APC";
        election.createElection("Election 2", 24, parties);

        // Vote in 3
        vm.prank(officer);
        election.createElection("Election 3", 24, parties);
        _accreditSelf(voter1);

        registry.setShouldFailSet(true); // Reset will fail

        vm.prank(voter1);
        // Should NOT revert
        election.vote(3, "APC");
        
        // Vote counted
        assertEq(election.voteCounts(3, "APC"), 1);
    }

    function test_Vote_SilentFail_If_MintingFails() public {
        _createStandardElection();
        _accreditSelf(voter2); // Streak 2

        badge.setShouldFail(true);

        vm.prank(voter2);
        election.vote(1, "APC");

        assertEq(badge.balanceOf(voter2), 0); // Mint failed
        assertEq(election.voteCounts(1, "APC"), 1); // Vote succeeded
    }

    // SECTION E: RESULTS & TIES

    function test_EndElection_ClearWinner() public {
        _createStandardElection();
        _accreditSelf(voter1);
        _accreditSelf(voter2);
        _accreditSelf(voter3);

        vm.prank(voter1); election.vote(1, "APC");
        vm.prank(voter2); election.vote(1, "APC");
        vm.prank(voter3); election.vote(1, "PDP");

        vm.warp(block.timestamp + 25 hours);

        vm.prank(officer);
        // Expecting winner="APC", votes=2, isTie=false
        vm.expectEmit(true, false, false, true);
        emit Election.ElectionEnded(1, "APC", 2, false);
        
        election.endElection(1);
    }

    function test_EndElection_Tie() public {
        _createStandardElection();
        _accreditSelf(voter1);
        _accreditSelf(voter2);

        vm.prank(voter1); election.vote(1, "APC");
        vm.prank(voter2); election.vote(1, "PDP");

        vm.warp(block.timestamp + 25 hours);
        vm.prank(officer);
        
        // Expecting winner="No Winner (Tie)", votes=1, isTie=true
        vm.expectEmit(true, false, false, true);
        emit Election.ElectionEnded(1, "No Winner (Tie)", 1, true);
        
        election.endElection(1);
    }

    function test_EndElection_NoVotes() public {
        _createStandardElection();
        vm.warp(block.timestamp + 25 hours);
        
        vm.prank(officer);
        // Expecting winner="No Votes", votes=0, isTie=false
        vm.expectEmit(true, false, false, true);
        emit Election.ElectionEnded(1, "No Votes", 0, false);
        
        election.endElection(1);
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

    function _accreditSelf(address _voter) internal {
        vm.prank(_voter);
        election.accreditMyself();
    }
}