// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;
import "./PoliticalPartiesManager.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract PoliticalPartiesManagerFactory is Ownable {
    PoliticalPartyManager[] public politicalpartymanager;
    address[] public addressPoliticalPartyManager;

    constructor() Ownable(msg.sender) {}

    function createNewPoliticalParty(
        address _chairman,
        string memory _partyName,
        address _nationaTokenAddress,
        address _electionBodyAddress,
        address _registryAddress
    ) external onlyOwner {
        PoliticalPartyManager politicalparty =
            new PoliticalPartyManager(_chairman, _partyName, _nationaTokenAddress, _electionBodyAddress, _registryAddress);
        politicalpartymanager.push(politicalparty);

        addressPoliticalPartyManager.push(address(politicalparty));
    }

    function getAllPoliticalParty() external view returns (address[] memory) {
        return addressPoliticalPartyManager;
    }
}