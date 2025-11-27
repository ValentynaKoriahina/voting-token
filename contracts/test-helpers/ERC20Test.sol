// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../ERC20.sol";

contract ERC20Test is ERC20 {
    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_
    ) ERC20(name_, symbol_, decimals_) {}

    function giveBalanceForTest(address who, uint256 amount) external {
        balances[who] = amount;
    }
}
