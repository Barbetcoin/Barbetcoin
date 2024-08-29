// SPDX-License-Identifier: No License

pragma solidity ^0.8.19;

import {ERC20} from "./ERC20.sol";
import {Ownable2Step} from "./Ownable2Step.sol";

abstract contract Mintable is ERC20, Ownable2Step {

    uint256 public maxSupply;

    error MintCannotExceedMaxSupply();

    constructor(uint256 _maxSupply) {
        maxSupply = _maxSupply * (10 ** decimals()) / 10;
    }

    function mint(address to, uint256 amount) public onlyOwner {
        if (totalSupply() + amount > maxSupply) revert MintCannotExceedMaxSupply();

        _mint(to, amount);
    }
}