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
    NationalToken public nationalToken;
    PoliticalPartiesManagerFactory public politicalPartiesManagerFactory;
    Registry public registry;
    VoterIncentives public voterIncentives;

    uint baseIncentives = 1000e18;

    uint256 electionsOfficerPrivateKey = vm.envUint("ELECTIONS_OFFICER_PRIVATE_KEY");
    address electionsOfficerAddress = vm.addr(electionsOfficerPrivateKey);

    uint256 centralBankPrivateKey = vm.envUint("CENTRAL_BANK_PRIVATE_KEY");
    address centralBankAddress = vm.addr(centralBankPrivateKey);

    uint256 partyAChairmanPrivateKey = vm.envUint("PARTYA_CHAIRMAN_PKEY");
    address partyAChairmanAddress = vm.addr(partyAChairmanPrivateKey);

    uint256 partyBChairmanPrivateKey = vm.envUint("PARTYB_CHAIRMAN_PKEY");
    address partyBChairmanAddress = vm.addr(partyBChairmanPrivateKey);

    uint256 partyCChairmanPrivateKey = vm.envUint("PARTYC_CHAIRMAN_PKEY");
    address partyCChairmanAddress = vm.addr(partyCChairmanPrivateKey);

    function run() external {
        vm.startBroadcast(centralBankPrivateKey);
        deployNationalTokenContract();
        vm.stopBroadcast();

        vm.startBroadcast(electionsOfficerPrivateKey);
        deployElectionsRelatedContracts();
        vm.stopBroadcast();

        vm.startBroadcast(centralBankPrivateKey);
        deployVoterIncentivesContract();
        grantTokenRelatedContractRoles();
        vm.stopBroadcast();

        vm.startBroadcast(electionsOfficerPrivateKey);
        createPartiesFromFactory();
        grantElectionsRelatedContractRoles();
        nationalElectionBody.setElectionId(1);
        vm.stopBroadcast();
    }

    function deployElectionsRelatedContracts() internal {
        democracyBadge = new DemocracyBadge("DEMOCRACYBADGE", "DBADGE");
        registry = new Registry();
        politicalPartiesManagerFactory = new PoliticalPartiesManagerFactory();
        nationalElectionBody = new NationalElectionBody(address(nationalToken));
        elections = new Election(address(registry), address(democracyBadge), address(nationalElectionBody));
    }

    function deployNationalTokenContract() internal {
        nationalToken = new NationalToken(centralBankAddress);
    }

    function deployVoterIncentivesContract() internal {
        voterIncentives = new VoterIncentives(address(democracyBadge), address(nationalToken), address(registry), baseIncentives);
    }

    function createPartiesFromFactory() internal {
        politicalPartiesManagerFactory.createNewPoliticalParty(partyAChairmanAddress, "PartyA", address(nationalToken), address(nationalElectionBody), address(registry));
        politicalPartiesManagerFactory.createNewPoliticalParty(partyBChairmanAddress, "PartyB", address(nationalToken), address(nationalElectionBody), address(registry));
        politicalPartiesManagerFactory.createNewPoliticalParty(partyCChairmanAddress, "PartyC", address(nationalToken), address(nationalElectionBody), address(registry));
    }

    function grantTokenRelatedContractRoles() internal { 
        bytes32 minterRole = nationalToken.MINTER_ROLE();
        nationalToken.grantRole(minterRole, address(voterIncentives));
    }

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