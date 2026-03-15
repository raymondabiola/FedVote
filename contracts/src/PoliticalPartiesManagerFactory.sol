import "./PoliticalPartiesManager.sol";

contract PoliticalPartiesManagerFactory {
    PoliticalPartyManager[] public politicalpartymanager;
    address[] public addressPoliticalPartyManager;

    function createNewPoliticalParty(
        address _chairman,
        string memory _partyName,
        address _nationaTokenAddress,
        address _electionBodyAddress,
        address _registryAddress
    ) external {
        PoliticalPartyManager politicalparty =
            new PoliticalPartyManager(_chairman, _partyName, _nationaTokenAddress, _electionBodyAddress, _registryAddress);
        politicalpartymanager.push(politicalparty);

        addressPoliticalPartyManager.push(address(politicalparty));
    }

    function getAllPoliticalParty() external view returns (address[] memory) {
        return addressPoliticalPartyManager;
    }
}