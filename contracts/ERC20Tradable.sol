// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;
import "./ERC20.sol";
import "./UUPSproxyStorage.sol";

contract ERC20Tradable is ERC20 {
    uint256 public tokenPrice;
    uint256 public buyFee;
    uint256 public sellFee;
    uint256 public lastBurnTime;
    uint256 public accumulatedFees;

    event Buy(
        address indexed buyer,
        uint256 ethSpent,
        uint256 netTokens,
        uint256 feeTokens
    );

    function buy() public payable notFrozen(msg.sender) {
        require(msg.value > 0, NoETHsent());
        balances[msg.sender] += netTokens;
        balances[address(this)] += fee;
        totalSupply += tokens;
        accumulatedFees += fee;

        // Mint чистых токенов покупателю
        emit Transfer(address(0), msg.sender, netTokens);

        // Mint комиссии (тоже часть totalSupply)
        emit Transfer(address(0), address(this), fee);

        // Event покупки (чисто для внешних систем)
        emit Buy(msg.sender, msg.value, netTokens, fee);
    }

    modifier nonReentrant() {
        if (_status == _ENTERED) revert ReentrantCall();
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }

    // ограничение на продажу, на сколько важно? [1]
    function sell(uint256 amount) public nonReentrant notFrozen(msg.sender) {
        if (amount == 0) revert ZeroTokenAmount();
        if (balances[msg.sender] < amount) revert InsufficientBalanceToSell();

        uint256 fee = (amount * sellFee) / fee_denominator;
        uint256 netTokens = amount - fee;

        uint256 ethAmount = (netTokens * tokenPrice) / 1e18;

        balances[msg.sender] -= amount;
        balances[address(this)] += fee;
        accumulatedFees += fee;
        totalSupply -= netTokens;
        // call используется для корректной обработки ETH-платежа и контроля его успешности (через ok), в отличие от устаревших transfer/send
        (bool ok, ) = payable(msg.sender).call{value: ethAmount}("");
        if (!ok) revert ETHTransferFailed();

        emit Transfer(msg.sender, address(0), amount);
    }

    function setBuyFee(uint256 _newFee) external onlyAdmin {
        buyFee = _newFee;
    }

    function setSellFee(uint256 _newFee) external onlyAdmin {
        sellFee = _newFee;
    }

    // должна быть без ограничения на админа (?)
    // [4]
    function burnAccumulatedFees() external {
        if (block.timestamp < lastBurnTime + 7 days) revert TooEarlyToBurn();
        totalSupply -= accumulatedFees;
        balances[address(this)] -= accumulatedFees;

        accumulatedFees = 0;
        lastBurnTime = block.timestamp;
        emit Transfer(address(this), address(0), accumulatedFees);
    }
}
