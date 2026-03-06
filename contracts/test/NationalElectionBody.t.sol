// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {NationalToken} from "/src/NationalToken.sol";

contract NationalTokenTest is Test {
    NationalToken public nationalToken;

    function setUp() public {
        nationalToken = new NationalToken();
    }

    function test_Increment() public {
        counter.increment();
        assertEq(counter.number(), 1);
    }

    function testFuzz_SetNumber(uint256 x) public {
        counter.setNumber(x);
        assertEq(counter.number(), x);
    }
}
