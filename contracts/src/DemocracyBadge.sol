// SPDX-License-Identifier: MIT
pragma solidity  ^0.8.30;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract DemocracyBadge is ERC721, AccessControl{
uint tokenId_;
/* assign role to Elections contract. If a voter votes in an election and their voter streak gets
  to the threshold, then the Elections contract will call the mintDemocracyBadge function to voter address*/
bytes32 public constant ELECTIONS_CONTRACT_ROLE = keccak256("ELECTIONS_CONTRACT_ROLE");

error AlreadyHasDemocracyBadge();
error SoulBoundToken();

constructor(string memory _name, string memory _symbol) ERC721(_name, _symbol){
    _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
}

function mintDemocracyBadge(address to) external onlyRole(ELECTIONS_CONTRACT_ROLE) {
    if(balanceOf(to) != 0) revert AlreadyHasDemocracyBadge();
    ++tokenId_;
    _safeMint(to, tokenId_);
}

function _update(address to, uint tokenId, address auth) internal override returns(address){
    address from = _ownerOf(tokenId);

    if(from != address(0)){
            revert SoulBoundToken();
    }
    return super._update(to, tokenId, auth);
}

function approve(address, uint256) public pure override {
    revert SoulBoundToken();
}

function setApprovalForAll(address, bool) public pure override {
    revert SoulBoundToken();
}

function tokenURI(uint256) public view virtual override returns (string memory){
    return "ipfs://bafkreidbix2i3gnhujrmxccprz4bqjbhuy24rfhzdawdfihtni5tg5b3ba";
}

function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, AccessControl) returns (bool){
    return super.supportsInterface(interfaceId);
}

}