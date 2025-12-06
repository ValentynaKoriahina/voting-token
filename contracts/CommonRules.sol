// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

abstract contract CommonRules{
    error LockedUntilVotingEnds();
    error OnlyAdmin();

    mapping(uint256 => mapping(address => bool)) public hasVoted;
    uint256 public votingNumber;
    uint256 public votingStartedTime;
    uint256 public constant timeToVote = 3 days;

    modifier notFrozen(address from) {
        if (votingActive() && hasVoted[votingNumber][from])
            revert LockedUntilVotingEnds();
        _;
    }
    
    function votingActive() public view returns (bool) {
        return
            votingStartedTime != 0 &&
            block.timestamp < votingStartedTime + timeToVote;
    }
}
