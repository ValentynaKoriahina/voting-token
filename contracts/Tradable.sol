// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./CommonRules.sol";
import "./customErrors/Errors.sol";

abstract contract Tradable is CommonRules {
    function _getBalance(address owner) internal view virtual returns (uint256);
    function _setBalance(address owner, uint256 amount) internal virtual;
    function _getTotalSupply() internal view virtual returns (uint256);
    function _setTotalSupply(uint256 amount) internal virtual;
    function _tokenPrice() internal view virtual returns (uint256);
    function _emitTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual;

    uint256 public tokenPrice; // wei
    uint256 public buyFee;
    uint256 public sellFee;
    uint256 public lastBurnTime;
    uint256 constant fee_denominator = 10000;
    uint256 public accumulatedFees;

    uint256 private _status;

    event Buy(
        address indexed buyer,
        uint256 ethSpent,
        uint256 netTokens,
        uint256 feeTokens
    );

    function _initializeTradable(
        uint256 tokenPrice_,
        uint256 buyFee_,
        uint256 sellFee_
    ) internal {
        tokenPrice = tokenPrice_;
        buyFee = buyFee_;
        sellFee = sellFee_;
        lastBurnTime = block.timestamp;
    }

    function buy() public payable notFrozen(msg.sender) {
        if (msg.value == 0) revert NoETHsent();

        uint256 tokens = (msg.value * 1e18) / tokenPrice;

        uint256 fee = (tokens * buyFee) / fee_denominator;
        uint256 netTokens = tokens - fee;

        _setBalance(msg.sender, _getBalance(msg.sender) + netTokens);
        _setBalance(address(this), _getBalance(address(this)) + fee);
        _setTotalSupply(_getTotalSupply() + tokens);

        accumulatedFees += fee;

        _emitTransfer(address(0), msg.sender, netTokens);
        _emitTransfer(address(0), address(this), fee);

        emit Buy(msg.sender, msg.value, netTokens, fee);
    }

    modifier nonReentrant() {
        // TODO
        _;
    }

    function sell(uint256 amount) public nonReentrant notFrozen(msg.sender) {
        if (amount == 0) revert ZeroTokenAmount();
        if (_getBalance(msg.sender) < amount)
            revert InsufficientBalanceToSell();

        uint256 fee = (amount * sellFee) / fee_denominator;
        uint256 netTokens = amount - fee;

        uint256 ethAmount = (netTokens * _tokenPrice()) / 1e18;

        _setBalance(msg.sender, _getBalance(msg.sender) - amount);
        _setBalance(address(this), _getBalance(address(this)) + fee);
        accumulatedFees += fee;
        _setTotalSupply(_getTotalSupply() - netTokens);

        (bool ok, ) = payable(msg.sender).call{value: ethAmount}("");
        if (!ok) revert ETHTransferFailed();

        _emitTransfer(msg.sender, address(0), amount);
    }

    // без onlyOwner, просто virtual — доступ контролируем в наследнике

    function setBuyFee(uint256 _newFee) external virtual {
        buyFee = _newFee;
    }

    function setSellFee(uint256 _newFee) external virtual {
        sellFee = _newFee;
    }

    function burnAccumulatedFees() external virtual {
        if (block.timestamp < lastBurnTime + 7 days) revert TooEarlyToBurn();

        _setTotalSupply(_getTotalSupply() - accumulatedFees);
        _setBalance(
            address(this),
            _getBalance(address(this)) - accumulatedFees
        );

        _emitTransfer(address(this), address(0), accumulatedFees);
        accumulatedFees = 0;
        lastBurnTime = block.timestamp;
    }
}
