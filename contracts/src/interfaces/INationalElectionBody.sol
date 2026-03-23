// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

interface INationalElectionBody {
    function setElectionId(uint256 _electionId) external; 

    function getElectionId() external view returns (uint256);

    function checkIfElectionExist(uint _electionId) external view returns(bool);
    
    function setCandidate(
        uint256 _electionId,
        string memory _candidateName,
        string memory _partyAcronym,
        address _candidateAddress
    ) external;

}