// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./customErrors/Errors.sol";

abstract contract Voting {
    function _getBalance(address owner) internal view virtual returns (uint256);
    function _getTotalSupply() internal view virtual returns (uint256);

    uint256 public constant timeToVote = 3 days;
    uint256 public votingNumber;
    uint256 public votingStartedTime;

    mapping(uint256 => mapping(uint256 => uint256)) public votes;
    mapping(uint256 => mapping(address => bool)) public hasVoted;
    uint256[] public proposedPrices;
    uint256 public currentWinningPrice;
    uint256 public currentWinningWeight;

    // This is the result of voting. It should be used by the Tradable logic.
    uint256 public tokenPrice;

    event VotingStarted(uint256 indexed votingNumber, uint256 startTime);
    event VotingEnded(uint256 indexed votingNumber, uint256 endTime);
    event Vote(
        address indexed voter,
        uint256 indexed proposedPrice,
        uint256 weight
    );

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

    function vote(uint256 price) public notFrozen(msg.sender) {
        if (!votingActive()) revert VotingNotActive();
        if (_getBalance(msg.sender) < minTokensForVoting())
            revert InsufficientTokens();

        if (votes[votingNumber][price] == 0) {
            proposedPrices.push(price);
        }

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
        if (votingActive()) revert VotingIsActive();
        votingStartedTime = block.timestamp;
        votingNumber++;
        emit VotingStarted(votingNumber, votingStartedTime);
    }

    function endVoting() external {
        if (!votingActive() && votingStartedTime != 0) {
            tokenPrice = currentWinningPrice;

            delete proposedPrices;
            votingStartedTime = 0;

            currentWinningPrice = 0;
            currentWinningWeight = 0;

            emit VotingEnded(votingNumber, block.timestamp);
        }
    }

    function minTokensForVoting() internal view returns (uint256) {
        return (_getTotalSupply() * 5) / 10000;
    }

    function minTokenForStartVoting() internal view returns (uint256) {
        return (_getTotalSupply() * 10) / 10000;
    }
}
