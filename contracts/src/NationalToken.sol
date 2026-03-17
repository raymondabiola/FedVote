// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

contract NationalToken is ERC20, AccessControl{
    address public centralBank;

    error InvalidAddress();
    error InvalidAmount();
    error ContractAddressNotAllowed();

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    constructor(address _centralBank) ERC20("NationalToken", "NAT") {
        if(_centralBank == address(0)) revert InvalidAddress();

        centralBank = _centralBank;

        _grantRole(DEFAULT_ADMIN_ROLE, centralBank);

        _grantRole(MINTER_ROLE, centralBank);
    }

    function mint(address _to, uint _amount) external onlyRole(MINTER_ROLE){
        if(_amount == 0){
            revert InvalidAmount();
        }
        _mint(_to, _amount);
    }
}