// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import "../src/DemocracyBadge.sol";

contract DemocracyBadgeTest is Test {
DemocracyBadge public democracyBadge;
    address public owner;
    address public zeroAddress;
    uint256 pKey = 0x450802246;
    uint256 pKey2 = 0xF333BB;
    address public user1;
    address public user2;
    address public user3;
    address public user4;

    error AccessControlUnauthorizedAccount(address account, bytes32 neededRole);
    error ERC721NonexistentToken(uint256 tokenId);
    error AlreadyHasDemocracyBadge();
    error SoulBoundToken();

    function setUp() public {
        democracyBadge = new DemocracyBadge("Democracy Badge", "DB");
        owner = address(this);
        zeroAddress = address(0);
        user1 = vm.addr(pKey);
        user2 = vm.addr(pKey2);
        user3 = makeAddr("user3");
        user4 = makeAddr("user4");

        bytes32 electionsContractRole = democracyBadge.ELECTIONS_CONTRACT_ROLE();
        democracyBadge.grantRole(electionsContractRole, user1);
    }

    function testName() public {
        assertEq(democracyBadge.name(), "Democracy Badge");
    }

    function testSymbol() public {
        assertEq(democracyBadge.symbol(), "DB");
    }

    function testOwnerHasDefaultAdminRole() public{
        bytes32 defaultAdminRole = democracyBadge.DEFAULT_ADMIN_ROLE();
        assertTrue(democracyBadge.hasRole(defaultAdminRole, owner));
    }

    function testMintDemocracyBadge() public {
        bytes32 electionsContractRole = democracyBadge.ELECTIONS_CONTRACT_ROLE();
        vm.prank(user2);
        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControlUnauthorizedAccount.selector,
                user2,
                electionsContractRole
            )
        );
        democracyBadge.mintDemocracyBadge(user3);

        vm.prank(user1);
        democracyBadge.mintDemocracyBadge(user3);
        assertEq(democracyBadge.balanceOf(user3), 1);
        assertEq(democracyBadge.balanceOf(user1), 0);

        vm.prank(user1);
        vm.expectRevert(AlreadyHasDemocracyBadge.selector);
        democracyBadge.mintDemocracyBadge(user3);

        assertEq(democracyBadge.tokenId_(), 1);
    }

    function testSoulBoundNatureOfNFT() public {
        bytes32 electionsContractRole = democracyBadge.ELECTIONS_CONTRACT_ROLE();
        vm.prank(user1);
        democracyBadge.mintDemocracyBadge(user3);

        vm.startPrank(user3);
        vm.expectRevert(SoulBoundToken.selector);
        democracyBadge.approve(user2, 1);

        vm.expectRevert(SoulBoundToken.selector);
        democracyBadge.setApprovalForAll(user1, true);

        vm.expectRevert(SoulBoundToken.selector);
        democracyBadge.safeTransferFrom(user3, user2, 1);

        vm.expectRevert(SoulBoundToken.selector);
        democracyBadge.transferFrom(user3, user2, 1);
        vm.stopPrank();
    }

    function testTokenURI() public {
        bytes32 electionsContractRole = democracyBadge.ELECTIONS_CONTRACT_ROLE();
        vm.startPrank(user1);
        democracyBadge.mintDemocracyBadge(user3);
        democracyBadge.mintDemocracyBadge(user4);

        string memory tokenUri = "ipfs://bafkreidbix2i3gnhujrmxccprz4bqjbhuy24rfhzdawdfihtni5tg5b3ba";
        assertEq(democracyBadge.tokenURI(1), tokenUri);
        assertEq(democracyBadge.tokenURI(2), tokenUri);
        vm.expectRevert(
            abi.encodeWithSelector(
                ERC721NonexistentToken.selector,
                3
            )
        );
        democracyBadge.tokenURI(3);
    }

    function testSupportsInterface() public {
             assertTrue(democracyBadge.supportsInterface(type(IERC165).interfaceId));
        assertTrue(
            democracyBadge.supportsInterface(type(IAccessControl).interfaceId)
        );
        assertTrue(
            democracyBadge.supportsInterface(type(IERC721).interfaceId)
        );
    }

    function testBalanceOf() public {
        bytes32 electionsContractRole = democracyBadge.ELECTIONS_CONTRACT_ROLE();
        vm.prank(user1);
        democracyBadge.mintDemocracyBadge(user3);
        assertEq(democracyBadge.balanceOf(user3), 1);

    }
}