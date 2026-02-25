// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/Registry.sol";

// Look up how to ensure the caller of this script has the role REGISTRATION_OFFICER_ROLE
contract RegisterVoters is Script {
  Registry public registry ;

    function run() external {
        vm.startBroadcast();

        registry = new Registry();

        string memory json = vm.readFile("./data/voters.json");

        uint256 count = vm.parseJsonUint(json, ".length");

       bytes32[] memory ninHashes = new bytes32[](count);
       string[] memory names = new string[](count);
       address[] memory addresses = new address[](count);

        for (uint256 i = 0; i < count; i++) {
            string memory path = string.concat(".", vm.toString(i));

            string memory nin = vm.parseJsonString(json, string.concat(path, ".nin"));
            string memory name = vm.parseJsonString(json, string.concat(path, ".name"));
            address voterAddress = vm.parseJsonAddress(json, string.concat(path, ".address"));

            bytes32 ninHash = keccak256(abi.encodePacked(nin));

            ninHashes[i] = ninHash;
            names[i] = name;
            addresses[i] = voterAddress;
        }

        registry.authorizeCitizensByBatch(ninHashes, names, addresses);
        vm.stopBroadcast();
    }
}