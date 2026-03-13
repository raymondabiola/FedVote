// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import {Test, console} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {VoterIncentives} from "src/VoterIncentives.sol";
import {NationalToken} from "src/NationalToken.sol";
import {Registry} from "src/Registry.sol";
import {DemocracyBadge} from "src/DemocracyBadge.sol";

contract VoterIncentivesTest is Test {
    VoterIncentives public voterIncentives;
    NationalToken public nationalToken;
    DemocracyBadge public democracyBadge;
    Registry public registry;
    uint public baseIncentives;

    uint256 pKey = 0x450802246;
    address deployer;
    address user1;
    address zeroAddress;

    bytes32[] ninHash;
    string[] name;
    address[] addr;

    string public _name = "DemocracyBadge";
    string public _symbol = "DBADGE";

    error InvalidAddress();
    error StreakNotUpToTheMinimumEligibility(
        uint streak,
        uint minimumEligibility
    );
    error VoterDoNotHaveDemocracyBadge();
    error ContractAddressNotAllowed(address caller);
    error AlreadyClaimedIncentivesForAllThreshold();
    error InvalidAmount();
    error OwnableUnauthorizedAccount(address account);

    function setUp() public {
        deployer = address(this);
        user1 = vm.addr(pKey);
        zeroAddress = address(0);

        console2.log("deployer:", deployer);
        console2.log("user1;", user1);

        vm.startPrank(deployer);
        democracyBadge = new DemocracyBadge(_name, _symbol);
        nationalToken = new NationalToken(deployer);
        registry = new Registry();

        voterIncentives = new VoterIncentives(
            address(democracyBadge),
            address(nationalToken),
            address(registry),
            baseIncentives = 1000e18
        );

        bytes32 registrationOfficer = registry.REGISTRATION_OFFICER_ROLE();
        registry.grantRole(registrationOfficer, deployer);

        vm.stopPrank();
    }

    function testDeploymentExecutedWell() external {
        assertEq(voterIncentives.baseIncentives(), 1000e18);
        assertEq(
            address(voterIncentives.nationalToken()),
            address(nationalToken)
        );
        assertEq(
            address(voterIncentives.democracyBadge()),
            address(democracyBadge)
        );
        assertEq(address(voterIncentives.registry()), address(registry));
        assertEq(voterIncentives.owner(), deployer);
    }

    function testEdgeCasesInConstructor() public {
        // When baseIncentive is set as 0 in constructor
        vm.expectRevert(InvalidAmount.selector);
        VoterIncentives incentives = new VoterIncentives(
            address(democracyBadge),
            address(nationalToken),
            address(registry),
            0
        );

        // When democracyBadge is address 0
        vm.expectRevert(InvalidAddress.selector);
        VoterIncentives incentives1 = new VoterIncentives(
            zeroAddress,     
            address(nationalToken), 
            address(registry),   
            1000e18
            );

        // When nationalToken is address 0
        vm.expectRevert(InvalidAddress.selector);
        VoterIncentives incentives2 = new VoterIncentives(
            address(democracyBadge),        
            zeroAddress, 
            address(registry),   
            1000e18
            );

        // When registry is address 0
        vm.expectRevert(InvalidAddress.selector);
        VoterIncentives incentives3 = new VoterIncentives(
            address(democracyBadge),      
            address(nationalToken), 
            zeroAddress,   
            1000e18
            );   

        // When two contracts were set to address 0
        vm.expectRevert(InvalidAddress.selector);
        VoterIncentives incentives4 = new VoterIncentives(
            zeroAddress,      
            zeroAddress, 
            address(registry),   
            1000e18
            );  

        vm.expectRevert(InvalidAddress.selector);
        VoterIncentives incentives5 = new VoterIncentives(
            address(democracyBadge),        
            zeroAddress, 
            zeroAddress,   
            1000e18
            ); 

        vm.expectRevert(InvalidAddress.selector);
        VoterIncentives incentives6 = new VoterIncentives(
            zeroAddress,        
            address(nationalToken),
            zeroAddress,   
            1000e18
            );

        // when all contracts are set to zero address
        vm.expectRevert(InvalidAddress.selector);
        VoterIncentives incentives7 = new VoterIncentives(
            zeroAddress,        
            zeroAddress, 
            zeroAddress,   
            1000e18
            );
    }

    function testUpdateDemocracyBadgeCA() public {
        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                OwnableUnauthorizedAccount.selector,
                user1,
                deployer
            )
        );
        voterIncentives.updateDemocracyBadgeCA(address(registry));
        voterIncentives.updateDemocracyBadgeCA(address(registry));
        assertEq(address(voterIncentives.democracyBadge()), address(registry));
    }

    function testUpdateNationalTokenCA() public {
        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                OwnableUnauthorizedAccount.selector,
                user1,
                deployer
            )
        );
        voterIncentives.updateNationalTokenCA(address(registry));
        voterIncentives.updateNationalTokenCA(address(registry));
        assertEq(address(voterIncentives.nationalToken()), address(registry));
    }

    function testUpdateRegistryCA() public {
        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                OwnableUnauthorizedAccount.selector,
                user1,
                deployer
            )
        );
        voterIncentives.updateRegistryCA(address(nationalToken));
        voterIncentives.updateRegistryCA(address(nationalToken));
        assertEq(address(voterIncentives.registry()), address(nationalToken));
    }

    function getNumHash(uint _num) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(_num));
    }

    function simulateArrayPopulate() internal {
        ninHash = new bytes32[](1);
        name = new string[](1);
        addr = new address[](1);
        ninHash[0] = getNumHash(2345);

        name[0] = "Alice";

        addr[0] = user1;
        vm.prank(deployer);
        registry.authorizeCitizensByBatch(ninHash, name, addr);

    }

    function testCheckEligibility() external {
        simulateArrayPopulate();

        vm.prank(user1);
        registry.voterSelfRegister(2345, "Alice");

        vm.expectRevert(InvalidAddress.selector);
        voterIncentives.checkEligibility(zeroAddress);

        vm.expectRevert(
            abi.encodeWithSelector(
                ContractAddressNotAllowed.selector,
                address(this)
            )
        );
        voterIncentives.checkEligibility(address(this));

        vm.expectRevert(VoterDoNotHaveDemocracyBadge.selector);
        voterIncentives.checkEligibility(user1);

        // test for a user that doesnt have the minimum eligibility
        // first grant this role below so that we can increment voter streak
        bytes32 electionsContractRole = registry.ELECTIONS_CONTRACT_ROLE();
        registry.grantRole(electionsContractRole, deployer);

        registry.incrementVoterStreak(user1);

        bytes32 slotA = keccak256(abi.encode(user1, uint256(3)));
        vm.store(address(democracyBadge), slotA, bytes32(uint256(1)));

        vm.expectRevert(
            abi.encodeWithSelector(
                StreakNotUpToTheMinimumEligibility.selector,
                1,
                3
            )
        );
        voterIncentives.checkEligibility(user1);
    }

    function testClaimIncentives() external {
        simulateArrayPopulate();
        vm.prank(user1);
        registry.voterSelfRegister(2345, "Alice");

        bytes32 electionsContractRole = registry.ELECTIONS_CONTRACT_ROLE();
        registry.grantRole(electionsContractRole, deployer);

        registry.incrementVoterStreak(user1);
        registry.incrementVoterStreak(user1);
        registry.incrementVoterStreak(user1);

        bytes32 slotA = keccak256(abi.encode(user1, uint256(3)));
        vm.store(address(democracyBadge), slotA, bytes32(uint256(1)));

        bytes32 minterRole = nationalToken.MINTER_ROLE();
        nationalToken.grantRole(minterRole, address(voterIncentives));

        vm.prank(user1);
        voterIncentives.claimIncentives();
        assertEq(nationalToken.balanceOf(user1), 1000e18);
        
        registry.incrementVoterStreak(user1);
        registry.incrementVoterStreak(user1);
        registry.incrementVoterStreak(user1);

        vm.prank(user1);
        voterIncentives.claimIncentives();
        assertEq(nationalToken.balanceOf(user1), 2300e18);

        registry.incrementVoterStreak(user1);
        registry.incrementVoterStreak(user1);
        registry.incrementVoterStreak(user1);

        vm.prank(user1);
        voterIncentives.claimIncentives();
        assertEq(nationalToken.balanceOf(user1), 3990e18);
    }

    function testClaimIncentivesForLazyVoter() public {
        simulateArrayPopulate();
        vm.prank(user1);
        registry.voterSelfRegister(2345, "Alice");

        bytes32 electionsContractRole = registry.ELECTIONS_CONTRACT_ROLE();
        registry.grantRole(electionsContractRole, deployer);

        registry.incrementVoterStreak(user1);
        registry.incrementVoterStreak(user1);
        registry.incrementVoterStreak(user1);

        // point where democracy badge is minted
         bytes32 slotA = keccak256(abi.encode(user1, uint256(3)));
        vm.store(address(democracyBadge), slotA, bytes32(uint256(1)));

        registry.incrementVoterStreak(user1);
        registry.incrementVoterStreak(user1);
        registry.incrementVoterStreak(user1);
        registry.incrementVoterStreak(user1);
        registry.incrementVoterStreak(user1);
        registry.incrementVoterStreak(user1);
        registry.incrementVoterStreak(user1);
        registry.incrementVoterStreak(user1);
        registry.incrementVoterStreak(user1);

        bytes32 minterRole = nationalToken.MINTER_ROLE();
        nationalToken.grantRole(minterRole, address(voterIncentives));

        vm.prank(user1);
        voterIncentives.claimIncentives();
        assertEq(nationalToken.balanceOf(user1), 6187e18);
    }

    function testSetBaseIncentives() external {

        uint baseIncentives1 = 100e18;

        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                OwnableUnauthorizedAccount.selector,
                user1,
                deployer
            )
        );
        voterIncentives.setBaseIncentives(baseIncentives1);
        vm.expectRevert(InvalidAmount.selector);
        voterIncentives.setBaseIncentives(0);
       
        voterIncentives.setBaseIncentives(baseIncentives1);
        assertEq(voterIncentives.baseIncentives(), baseIncentives1);
    }
}