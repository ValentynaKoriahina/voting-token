// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "../Initializable.sol";
import "../VotingToken_UUPSproxyStorage.sol";
import "../VotingToken_Upgradeable.sol";

// Ensure VotingToken_Upgradeable is defined in VotingToken_Upgradeable.sol
contract VotingTokenTest_Upgradeable is VotingToken_Upgradeable {

    function giveBalanceForTest(address who, uint256 amount) external {
        balances[who] = amount;
    }

    function addTotalSupplyForTest(uint256 amount) external {
        totalSupply += amount;
    }
}
