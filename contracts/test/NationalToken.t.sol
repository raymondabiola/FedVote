// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import {Test, console} from "forge-std/Test.sol";
import {NationalToken} from "src/NationalToken.sol";

contract NationalTokenTest is Test {
    NationalToken public nationalToken;
    address admin;

    function setUp() public {
        address _admin = makeAddr("1");
        admin = _admin;
        nationalToken = new NationalToken(admin);
    }

    function testGetAddress() public view {
        address centralBank = nationalToken.centralBankAddress();
        console.log("Central Bank Address from test:", centralBank);
    }

    function testMint() public {
        address recipient = makeAddr("owner");

        uint mintAmount = 1000e18;

        vm.prank(admin);

        nationalToken.mint(recipient, 1000e18);

        assertEq(nationalToken.balanceOf(recipient), mintAmount);
    }

    function testGrantRole() public {
        vm.startPrank(admin);
        address users = makeAddr("3");
        nationalToken.grantRole(nationalToken.MINTERS_ROLE(), users);
        vm.stopPrank;
        vm.prank(users);
        bool hasMinterRole = nationalToken.hasRole(
            nationalToken.MINTERS_ROLE(),
            users
        );
        assertTrue(hasMinterRole);
    }

    function testUserCanMint() public {
        address user = makeAddr("4");

        vm.startPrank(admin);

        nationalToken.grantRole(nationalToken.MINTERS_ROLE(), user);

        vm.stopPrank();

        vm.prank(user);

        nationalToken.mint(user, 100);

        assertEq(nationalToken.balanceOf(user), 100);
    }

    function testSetAdminRole() public {
        vm.startPrank(admin);
        nationalToken.setAdminRole(
            nationalToken.MINTERS_ROLE(),
            nationalToken.DEFAULT_ADMIN_ROLE()
        );

        vm.stopPrank();

        assertEq(
            nationalToken.getRoleAdmin(nationalToken.MINTERS_ROLE()),
            nationalToken.DEFAULT_ADMIN_ROLE()
        );
    }
}
