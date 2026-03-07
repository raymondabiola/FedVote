//SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {NationalToken} from "../src/NationalToken.sol";
import {NationalElectionBody} from "../src/NationalElectionBody.sol";

contract NationalElectionBodyTest is Test {
    NationalElectionBody public electionBody;
     NationalToken public token;

    address public admin = makeAddr("admin");
    address public partyAddress = makeAddr("partyAddress");
    address public partyChairman = makeAddr("partyChairman");
    address centralBank = makeAddr("centralBank");

    uint256 constant REGISTRATION_FEE = 10_000e18;

    function setUp() public {
        // centralBank deploys token
        vm.startPrank(centralBank);
        token = new NationalToken(centralBank);
        token.mint(partyAddress, REGISTRATION_FEE);
        vm.stopPrank();

        
        vm.startPrank(admin);
        electionBody = new NationalElectionBody(address(token));
        electionBody.grantChairmanRole(partyChairman);
        vm.stopPrank();

        vm.prank(partyAddress);
        token.approve(address(electionBody), type(uint256).max);
    }

    function  _registerParty(string memory name, string memory acronym, string memory chairman, address addr) internal returns (uint256 partyId) {
        vm.prank(addr);
        electionBody.RegisterParty(name, chairman, acronym, addr);
        partyId = electionBody.partyNameToId(name);
    }

    function test_deployment() public {
        assertEq(address(electionBody.nationalToken()), address(token));
    }
}