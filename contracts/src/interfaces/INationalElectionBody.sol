// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

interface INationalElectionBody {
    function getElectionId() external view returns (uint256);
    
    function setCandidate(
        uint256 _electionId,
        string memory _candidateName,
        string memory _partyAcronym,
        address _candidateAddress
    ) external onlyRole(PARTY_PRIMARIES_ROLE);

}