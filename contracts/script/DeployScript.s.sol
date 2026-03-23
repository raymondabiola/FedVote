// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script} from "lib/openzeppelin-contracts/lib/forge-std/src/Script.sol";
import "../src/DemocracyBadge.sol";
import "../src/Elections.sol";
import "../src/NationalElectionBody.sol";
import "../src/NationalToken.sol";
import "../src/PoliticalPartiesManagerFactory.sol";
import "../src/Registry.sol";
import "../src/VoterIncentives.sol";

contract DeployScript is Script {
    DemocracyBadge public democracyBadge;
    Election public elections;
    NationalElectionBody public nationalElectionBody;
    // NationalToken public nationalToken;
    PoliticalPartiesManagerFactory public politicalPartiesManagerFactory;
    Registry public registry;
    // VoterIncentives public voterIncentives;

    // uint baseIncentives = 1000e18;

    uint256 deployerPrivateKey;
    address deployerAddress;

    uint256 centralBankPrivateKey;
    address centralBankAddress;

    uint256 partyAChairmanPrivateKey;
    address partyAChairmanAddress;

    uint256 partyBChairmanPrivateKey;
    address partyBChairmanAddress;

    uint256 partyCChairmanPrivateKey;
    address partyCChairmanAddress;

    address nationalTokenAddress;
    address democracyBadgeAddress;
    address registryAddress;

    function run() external {

        deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        deployerAddress = vm.addr(deployerPrivateKey);

        centralBankPrivateKey = vm.envUint("CENTRAL_BANK_PRIVATE_KEY");
        centralBankAddress = vm.addr(centralBankPrivateKey);

        partyAChairmanPrivateKey = vm.envUint("PARTYA_CHAIRMAN_PKEY");
        partyAChairmanAddress = vm.addr(partyAChairmanPrivateKey);

        partyBChairmanPrivateKey = vm.envUint("PARTYB_CHAIRMAN_PKEY");
        partyBChairmanAddress = vm.addr(partyBChairmanPrivateKey);

        partyCChairmanPrivateKey = vm.envUint("PARTYC_CHAIRMAN_PKEY");
        partyCChairmanAddress = vm.addr(partyCChairmanPrivateKey);

        nationalTokenAddress = vm.envAddress("TOKEN_ADDRESS");
        democracyBadgeAddress = vm.envAddress("DEMOCRACY_ADDRESS");
        registryAddress = vm.envAddress("REGISTRY_ADDRESS");

        // vm.startBroadcast(deployerPrivateKey);
        // deployNationalTokenContract();
        // vm.stopBroadcast();

        vm.startBroadcast(deployerPrivateKey);
        deployElectionsRelatedContracts();
        vm.stopBroadcast();

        // vm.startBroadcast(deployerPrivateKey);
        // deployVoterIncentivesContract();
        // vm.stopBroadcast();

        // vm.startBroadcast(centralBankPrivateKey);
        // grantTokenRelatedContractRoles();
        // vm.stopBroadcast();

        vm.startBroadcast(deployerPrivateKey);
        createPartiesFromFactory();
        grantElectionsRelatedContractRoles();
        nationalElectionBody.setElectionId(1);
        vm.stopBroadcast();
    }

    function deployElectionsRelatedContracts() internal {
        democracyBadge = DemocracyBadge(democracyBadgeAddress);
        registry = Registry(registryAddress);
        politicalPartiesManagerFactory = new PoliticalPartiesManagerFactory();
        nationalElectionBody = new NationalElectionBody(nationalTokenAddress);
        elections = new Election(registryAddress, democracyBadgeAddress, address(nationalElectionBody));
    }

    // function deployNationalTokenContract() internal {
    //     nationalToken = new NationalToken(centralBankAddress);
    // }

    // function deployVoterIncentivesContract() internal {
    //     voterIncentives = new VoterIncentives(address(democracyBadge), address(nationalToken), address(registry), baseIncentives);
    // }

    function createPartiesFromFactory() internal {
        politicalPartiesManagerFactory.createNewPoliticalParty(partyAChairmanAddress, "PartyA", nationalTokenAddress, address(nationalElectionBody), registryAddress);
        politicalPartiesManagerFactory.createNewPoliticalParty(partyBChairmanAddress, "PartyB", nationalTokenAddress, address(nationalElectionBody), registryAddress);
        politicalPartiesManagerFactory.createNewPoliticalParty(partyCChairmanAddress, "PartyC", nationalTokenAddress, address(nationalElectionBody), registryAddress);
    }

    // function grantTokenRelatedContractRoles() internal { 
    //     bytes32 minterRole = nationalToken.MINTER_ROLE();
    //     nationalToken.grantRole(minterRole, address(voterIncentives));
    // }

    function grantElectionsRelatedContractRoles() internal {
        bytes32 electionsContractRoleRegistry = registry.ELECTIONS_CONTRACT_ROLE();
        bytes32 electionsContractRoleDemocracyBadge = democracyBadge.ELECTIONS_CONTRACT_ROLE();
        bytes32 partyContractRole = registry.PARTY_CONTRACT_ROLE();
        bytes32 partiesPrimaryRole = nationalElectionBody.PARTY_PRIMARIES_ROLE();

        registry.grantRole(electionsContractRoleRegistry, address(elections));
        democracyBadge.grantRole(electionsContractRoleDemocracyBadge, address(elections));

        registry.grantRole(partyContractRole, politicalPartiesManagerFactory.addressPoliticalPartyManager(0));
        registry.grantRole(partyContractRole, politicalPartiesManagerFactory.addressPoliticalPartyManager(1));
        registry.grantRole(partyContractRole, politicalPartiesManagerFactory.addressPoliticalPartyManager(2));

        nationalElectionBody.grantRole(partiesPrimaryRole, politicalPartiesManagerFactory.addressPoliticalPartyManager(0));
        nationalElectionBody.grantRole(partiesPrimaryRole, politicalPartiesManagerFactory.addressPoliticalPartyManager(1));
        nationalElectionBody.grantRole(partiesPrimaryRole, politicalPartiesManagerFactory.addressPoliticalPartyManager(2));
    }
}