// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// import "/.test-helpers/VotingTokenTest.sol";
import "../../contracts/VotingToken.sol";

contract VotingTokenTest is VotingToken {
    constructor(
        uint256 _tokenPrice,
        uint256 _buyFee,
        uint256 _sellFee
    ) VotingToken(_tokenPrice, _buyFee, _sellFee) {}

    function giveBalanceForTest(address who, uint256 amount) external {
        balances[who] = amount;
    }

    function addTotalSupplyForTest(uint256 amount) external {
        totalSupply += amount;
    }
}
