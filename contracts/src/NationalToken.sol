// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

contract NationalToken is ERC20, AccessControl {
    address private centralBank;

    error ZeroAmountNotAccepted();

    bytes32 public constant MINTERS_ROLE = keccak256("MINTERS_ROLE");

    constructor(address _centralBank) ERC20("NationalToken", "NAT") {

        centralBank = _centralBank;

        _grantRole(DEFAULT_ADMIN_ROLE, _centralBank);

        _grantRole(MINTERS_ROLE, _centralBank);
    }

    function mint(address _to, uint _amount) public onlyRole(MINTERS_ROLE){
        if(_amount == 0){
            revert ZeroAmountNotAccepted();
        }
        _mint(_to, _amount);
    }

    function setAdminRole(bytes32 role, bytes32 adminRole) external onlyRole(DEFAULT_ADMIN_ROLE){
        _setRoleAdmin(role,adminRole);
    }

    function centralBankAddress() view returns(address){
        return centralBank;
    }
}