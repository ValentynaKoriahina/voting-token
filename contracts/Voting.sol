// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./customErrors/Errors.sol";
import "./CommonRules.sol";

abstract contract Voting is CommonRules {
    function _getBalance(address owner) internal view virtual returns (uint256);
    function _getTotalSupply() internal view virtual returns (uint256);
    function _applyNewPrice(uint256 price) internal virtual;

    uint256 public timeToVote;
    uint256 public votingNumber;
    uint256 public votingStartedTime;

    mapping(uint256 => mapping(uint256 => uint256)) public votes;
    mapping(uint256 => mapping(address => bool)) public hasVoted;

    uint256 public currentWinningPrice;
    uint256 public currentWinningWeight;

    // This is the result of voting. It should be used by the Tradable logic.
    uint256 public newTokenPrice;

    function votingActive(
        uint256 timeToVote_,
        uint256 votingStartedTime_
    ) public view returns (bool) {
        return
            votingStartedTime_ != 0 &&
            block.timestamp < votingStartedTime_ + timeToVote_;
    }

    function _isFrozen(address user) internal view override returns (bool) {
        return
            votingActive(timeToVote, votingStartedTime) &&
            hasVoted[votingNumber][user];
    }

    event VotingStarted(uint256 indexed votingNumber, uint256 startTime);
    event VotingEnded(uint256 indexed votingNumber, uint256 endTime);
    event Vote(
        address indexed voter,
        uint256 indexed proposedPrice,
        uint256 weight
    );

    function _initializeVote(uint256 timeToVote_) internal {
        timeToVote = timeToVote_;
    }

    function vote(uint256 price) public notFrozen(msg.sender) {
        if (!votingActive(timeToVote, votingStartedTime))
            revert VotingNotActive();
        if (_getBalance(msg.sender) < minTokensForVoting())
            revert InsufficientTokens();

        uint256 senderBalance = _getBalance(msg.sender);
        votes[votingNumber][price] += senderBalance;

        uint256 newWeight = votes[votingNumber][price];

        if (newWeight > currentWinningWeight) {
            currentWinningWeight = newWeight;
            currentWinningPrice = price;
        }

        hasVoted[votingNumber][msg.sender] = true;
        emit Vote(msg.sender, price, senderBalance);
    }

    function startVoting() public {
        if (_getBalance(msg.sender) < minTokenForStartVoting())
            revert InsufficientTokens();
        if (votingActive(timeToVote, votingStartedTime))
            revert VotingIsActive();
        votingStartedTime = block.timestamp;
        votingNumber++;
        emit VotingStarted(votingNumber, votingStartedTime);
    }

    function endVoting() external {
        if (votingActive(timeToVote, votingStartedTime)) {
            revert VotingIsActive();
        }
        if (votingStartedTime == 0) {
            revert VotingNotActive();
        }

        newTokenPrice = currentWinningPrice;

        _applyNewPrice(currentWinningPrice);

        votingStartedTime = 0;
        currentWinningPrice = 0;
        currentWinningWeight = 0;

        emit VotingEnded(votingNumber, block.timestamp);
    }

    function minTokensForVoting() public view returns (uint256) {
        return (_getTotalSupply() * 5) / 10000;
    }

    function minTokenForStartVoting() public view returns (uint256) {
        return (_getTotalSupply() * 10) / 10000;
    }
}
