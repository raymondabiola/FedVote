// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {VoterIncentive} from "../src/VoterIncentives.sol";

contract VoterIncentiveTest is Test {
    VoterIncentive public voterIncentive;

    address constant token = address(0x1);
    function setUp() public {
        voterIncentive = new VoterIncentive(token);
        // counter.setNumber(0);
    }

   
}


