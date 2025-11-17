// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./VotingToken_UUPSproxyStorage.sol";
import "./Initializable.sol";
import "./IERC20.sol";

contract VotingToken_Upgradeable_V2 is
    IERC20,
    VotingToken_UUPSproxyStorage,
    Initializable
{
    error InefficientETHForBuying();
    error InefficientETHInContract();
    error ZeroTokenAmount();
    error InefficientTokens();
    error OnlyAdmin();
    error InsufficientBalanceToSell();
    error VotingIsActive();
    error VotingNotActive();
    error InefficientBalance();
    error TooEarlyToBurn();
    error InvalidSpender();
    error LockedUntilVotingEnds();
    error AllowanceExceeded();
    error ETHTransferFailed();
    error NoETHsent();
    error NotAContract();
    error SameImplementation();
    error ReentrantCall();

    /* 
    Записать 0 → неноль	20 000 gas	–
    Изменить неноль → другой неноль	5 000 gas	–
    Обнулить (неноль → 0)	5 000 gas – 15 000 refund
    */

    uint256 public tokenPrice; // wei
    uint256 public buyFee; // wei
    uint256 public sellFee; // wei
    uint256 public lastBurnTime;

    uint256 constant fee_denominator = 10000; // 10000 = масштаб для дробных процентов в "basis points" (bps) (10000 bps = 100%)
    uint256 public accumulatedFees;

    uint256 public totalSupply;

    uint256 public constant timeToVote = 3 days;
    uint256 public votingNumber; // Номер текущего раунда голосования
    uint256 public votingStartedTime;

    // votes[номер_раунда][цена] = количество голосов (вес = количество токенов)
    mapping(uint256 => mapping(uint256 => uint256)) public votes;
    // hasVoted[номер_раунда][адрес] = true, если пользователь уже голосовал
    mapping(uint256 => mapping(address => bool)) public hasVoted;
    uint256[] public proposedPrices;

    // Балансы и разрешения по стандарту ERC-20
    mapping(address => uint256) public balances;
    mapping(address => mapping(address => uint256)) public allowances;

    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status;

    uint256[50] private __gap;

    constructor() {
        _disableInitializers();
    }

    // обязательное требование UUPS/Proxy архитектуры (вместо конструктора)
    function initialize(
        uint256 _tokenPrice,
        uint256 _buyFee,
        uint256 _sellFee
    ) external initializer onlyAdmin {
        tokenPrice = _tokenPrice;
        buyFee = _buyFee;
        sellFee = _sellFee;
        lastBurnTime = block.timestamp;
    }

    event VotingStarted(uint256 indexed votingNumber, uint256 startTime);
    event VotingEnded(uint256 indexed votingNumber, uint256 endTime);
    event Buy(
        address indexed buyer,
        uint256 ethSpent,
        uint256 netTokens,
        uint256 feeTokens
    );

    function balanceOf(
        address _owner
    ) external view override returns (uint256 balance) {
        return (balances[_owner]);
    }

    function transfer(
        address _to,
        uint256 _value
    ) external override returns (bool success) {
        address _from = msg.sender;
        proceedTransfer(_from, _value, _to);
        return (true);
    }

    /*
       transferFrom используется, когда кто-то переводит чужие токены с разрешения владельца.
    */
    function transferFrom(
        address _from,
        address _to,
        uint256 _value
    ) external override returns (bool success) {
        if (allowances[_from][msg.sender] < _value) revert AllowanceExceeded();
        allowances[_from][msg.sender] -= _value; // Уменьшаем лимит после перевода — требование ERC-20
        proceedTransfer(_from, _value, _to);
        return (true);
    }
    function proceedTransfer(
        address _from,
        uint256 _value,
        address _to
    ) internal notFrozen(_from) {
        if (balances[_from] < _value) revert InefficientBalance();
        balances[_from] -= _value;
        balances[_to] += _value;
        emit Transfer(_from, _to, _value);
    }

    // Устанавливаем разрешение для другого адреса тратить токены владельца
    function approve(
        address _spender,
        uint256 _value
    ) external override returns (bool success) {
        address _owner = msg.sender;
        allowances[_owner][_spender] = _value;
        emit Approval(_owner, _spender, _value);
        return (true);
    }

    // Возвращает, сколько токенов spender ещё может потратить у owner
    function allowance(
        address _owner,
        address _spender
    ) external view override returns (uint256 remaining) {
        return (allowances[_owner][_spender]);
    }

    // Минимум 0.05% от totalSupply для участия в голосовании
    function minTokensForVoting()
        internal
        view
        returns (uint256 minTokenAmount)
    {
        return (totalSupply * 5) / 10000; // 0.05 % = 5 / 10000
    }

    // Минимум 0.1% от totalSupply, чтобы иметь право начать голосование
    function minTokenForStartVoting()
        internal
        view
        returns (uint256 minTokenAmount)
    {
        return (totalSupply * 10) / 10000; // 0.1 % = 10 / 10000
    }

    // [3]
    function vote(uint256 price) public notFrozen(msg.sender) {
        if (!votingActive()) revert VotingNotActive();
        if (balances[msg.sender] < minTokensForVoting())
            revert InefficientTokens();
        if (votes[votingNumber][price] == 0) {
            proposedPrices.push(price);
        }
        votes[votingNumber][price] += balances[msg.sender];
        hasVoted[votingNumber][msg.sender] = true;
    }


    function startVoting() public {
        if (balances[msg.sender] < minTokenForStartVoting())
            revert InefficientTokens();
        if (votingActive()) revert VotingIsActive();
        votingStartedTime = block.timestamp;
        votingNumber++; // новый раунд голосования
        emit VotingStarted(votingNumber, votingStartedTime);
    }

    // [3]
    function endVoting() external {
        if (votingActive()) revert VotingIsActive();

        uint256 winningPrice = 0;
        uint256 maxVotes = 0;

        for (uint256 i = 0; i < proposedPrices.length; i++) {
            uint256 price = proposedPrices[i];
            uint256 voteCount = votes[votingNumber][price];

            if (voteCount > maxVotes) {
                maxVotes = voteCount;
                winningPrice = price;
            }
        }

        tokenPrice = winningPrice;

        delete proposedPrices;
        votingStartedTime = 0;
        emit VotingEnded(votingNumber, block.timestamp);
    }

    function votingActive() public view returns (bool) {
        return
            votingStartedTime != 0 &&
            block.timestamp < votingStartedTime + timeToVote;
    }

    modifier notFrozen(address from) {
        if (votingActive() && hasVoted[votingNumber][from])
            revert LockedUntilVotingEnds();
        _;
    }

    function buy() public payable notFrozen(msg.sender) {
        require(msg.value > 0, NoETHsent());

        // Токены ERC-20 тоже имеют 18 знаков "после запятой"
        // https://docs.openzeppelin.com/contracts/4.x/api/token/erc20?utm_source=chatgpt.com#ERC20-decimals--
        uint256 tokens = (msg.value * 1e18) / tokenPrice;

        // подстановки:
        // * tokens =
        // 50_000_000_000_000_000 * 1e18 = 50_000_000_000_000_000_000000000000000000 /
        //                       2_000_000_000_000_000 = 25_000_000_000_000_000_000 (токена в масштабе wei )
        // 25_000_000_000_000_000_000 / 1e18  = 25 токенов

        // * или проверка через простую математику
        // 0.05 ETH / 0.002 ETH = 25 токенов

        // TODO Проверка если результат округления дал 0 токенов — отклоняем транзакцию

        uint256 fee = (tokens * buyFee) / fee_denominator;
        // * fee
        //  = 25_000_000_000_000_000_000 tokens * 500 buyFee = 12_500_000_000_000_000_000_000 /
        //                                 / 10_000 fee_denominator = 1_250_000_000_000_000_000 токена
        //
        // 1_250_000_000_000_000_000 / 1e18 = 1.25
        // * или проверка через простую математику
        // 25 * 0.05 = 1.25

        uint256 netTokens = tokens - fee;
        // * проверка через простую математику
        // 25 токенов - 1,25 fee токенов =>  23.75 * 1e18 = 23,750,000,000,000,000,000 (токена в масштабе wei)

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

    modifier onlyAdmin() {
        require(msg.sender == _getAdmin(), OnlyAdmin());
        _;
    }

    // UUPS: upgrade logic
    function upgradeTo(address newImplementation) external onlyAdmin {
        require(newImplementation.code.length > 0, NotAContract());
        require(
            newImplementation != _getImplementation(),
            SameImplementation()
        );
        _setImplementation(newImplementation);
    }
}

/**
   - ERC-20 совместимый токен с динамической ценой (tokenPrice);
   - Голосования за новую цену (владельцы токенов голосуют, вес = баланс);
   - На период голосования замораживаются транзакции у проголосовавших;
   - Покупка/продажа с комиссией, комиссия накапливается и сжигается раз в неделю;

*/

// ??????
/**
Что, если откат транзакции делает вложенная фукнция
выгодно ли очищать маппинги или лучше использовать раунды?
[1] На период активного голосования запрещается выполнять sell для пользователей, которые уже проголосовали.
    Это сохраняет честный вес голоса. Это делает голосование консистентным и не позволяет манипулировать ценой.

    
 */

//TODO Что дальше
/**
////Использовать TypeChain для генерации типов контрактов в тестах.
//// Контракт должен быть обновляемым (upgradeable).
//// Функцию endVoting может вызвать любой пользователь, но правила
//// должны проверять, что она вызывается только после истечения времени timeToVote.
Контракты должны быть задеплоены в тестовую сеть Sepolia и проверены на Etherscan (sepolia.etherscan.io).
[3]     // ! требования к цене - минимум, максимум, кратность (для ограничения размера маппинга)?
    /*
       Завершение голосования.
      
       Как обычно решают

            Ограничивают количество элементов.
            Например, не более 10 предложенных цен.

            Переносят вычисления off-chain.
            Например, результат голосования вычисляется сервером или DAO-скриптом,
            а контракт просто получает winningPrice через транзакцию.

            Разбивают процесс на несколько шагов.
            Вместо одного большого цикла — несколько маленьких функций с частичным подсчётом.

            Используют структуры данных с константным временем (O(1)).
            Например, mapping вместо array,
            чтобы не нужно было перебирать элементы.
    */

// ограничение на сумму ставки
// ограничить функции правом администратора
// Проверка перед сжиганием комиссий if (balances[address(this)] < accumulatedFees) revert InefficientBalance();
// границы комиссии - Добавить проверку if (_newFee > fee_denominator) revert FeeTooHigh(); в setBuyFee() и setSellFee() чтобы комиссия не превышала 100%.

//TODO Topics that have been learnt:
/**
1.  Formatting (wei, gwei, eth, etc.) 
2.  IERC20, ERC20 
3.  Solidity 
4.  Ethers.js + hardhat 
5.  Gas 
6.  // !Memoization pattern 

[4] // TODO если accumulatedFees > totalSupply (?)


1️ Результат голосования (yes/no или totalVotes)	Итоговое количество голосов для данного votingNumber	Вместо пересчёта каждого раза по mapping(address → voteAmount) можно хранить промежуточные суммы → меньше газа и быстрее итоговая функция endVoting()
2️	Минимальный порог голосов (minTokensForVoting)	Один раз вычислить при startVoting() и сохранить	Не пересчитывать (totalSupply * 5) / 10000 при каждом вызове vote()
3️	Результат tokenPrice или fee перерасчёта	Если формула фиксированная, можно кешировать итог для заданного периода	Сокращает дублируемые арифметические операции при buy() / sell()
4️	Адреса уже проверенных участников	Хранить в mapping(address => bool) результат проверки “участвовал / нет”	При каждом vote() не нужно снова искать в массиве или в другой структуре данных
5️	Итоговое значение balanceOf при блокировке	Кешировать значение баланса, который используется для расчёта веса голоса	Избегает повторных обращений к storage (дорогих по gas)
6️	Timestamp окончания голосования	Вычислить votingStartedTime + timeToVote и сохранить в переменной	При каждом вызове endVoting() не нужно пересчитывать — просто сравнивать с заранее вычисленным временем
Problem solved: 
-  Problem with the cycles, O(N) functions that are dependent on users. 
*/
