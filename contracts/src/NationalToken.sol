// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract NationalToken is ERC20, Ownable {
    uint public _totalSupply;
    address centralBank;
    error ZeroAmountNotAccepted();

    constructor(address _centralBank) ERC20("NationalToken", "NAT") Ownable(centralBank) {
        centralBank = _centralBank;
    }

    function mint(uint _amount, address _to) public onlyOwner {
        if(_amount == 0){
            revert ZeroAmountNotAccepted();
        }
        _mint(_to, _amount * (10 ** uint(decimals())));
    }

}
