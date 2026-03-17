// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import {Test, console} from "forge-std/Test.sol";
import {NationalToken} from "src/NationalToken.sol";

contract NationalTokenTest is Test {
    NationalToken public nationalToken;
    address centralBank;
    address user1;
    address zeroAddress;

    error InvalidAddress();
    error InvalidAmount();
    error AccessControlUnauthorizedAccount(address account, bytes32 neededRole);

    function setUp() public {
        centralBank = makeAddr("1");
        user1 = makeAddr("2");
        zeroAddress = address(0);
        nationalToken = new NationalToken(centralBank);
    }

    function testIfDeploymentWorkedCorrectly() public {
        bytes32 defaultAdmin = nationalToken.DEFAULT_ADMIN_ROLE();
        bytes32 minterRole = nationalToken.MINTER_ROLE();
        assertEq(nationalToken.centralBank(), centralBank);
        assertTrue(nationalToken.hasRole(defaultAdmin, centralBank));
        assertTrue(nationalToken.hasRole(minterRole, centralBank));
        assertGt(address(nationalToken).code.length, 0);
    }

    function testDeploymentEdgeCases() public {
        vm.expectRevert(InvalidAddress.selector);
        nationalToken = new NationalToken(zeroAddress);
    }

    function testMint() public {
        uint mintAmount = 1000e18;
        bytes32 minterRole = nationalToken.MINTER_ROLE();
        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControlUnauthorizedAccount.selector,
                address(this),
                minterRole
            )
        );
        nationalToken.mint(user1, mintAmount);

        vm.startPrank(centralBank);
        vm.expectRevert(InvalidAmount.selector);
        nationalToken.mint(user1, 0);
        nationalToken.mint(user1, mintAmount);
        vm.stopPrank();

        assertEq(nationalToken.balanceOf(user1), mintAmount);
    }
}
