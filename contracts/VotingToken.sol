// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "./IERC20.sol";

contract VotingToken is IERC20 {
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

    /* 
    Записать 0 → неноль	20 000 gas	–
    Изменить неноль → другой неноль	5 000 gas	–
    Обнулить (неноль → 0)	5 000 gas – 15 000 refund
    */
    uint256[50] private __gap;
    address public admin;

    uint256 buyFee;
    uint256 sellFee;
    uint256 constant fee_denominator = 10000; // 10000 = масштаб для дробных процентов (1% = 100)
    uint256 public accumulatedFees;
    uint256 public lastBurnTime;

    uint256 public totalSupply;
    uint256 public tokenPrice; // 10000000000000000 wei = 1 ETH

    uint256 public constant timeToVote = 3 days;
    uint256 public votingNumber; // Номер текущего голосования (чтобы не путать разные циклы)
    uint256 public votingStartedTime;

    //  ! выгодно ли очищать маппинги или лучше использовать раунды?

    // votes[номер_раунда][цена] = количество голосов (вес = количество токенов)
    mapping(uint256 => mapping(uint256 => uint256)) public votes;
    // hasVoted[номер_раунда][адрес] = true, если пользователь уже голосовал
    mapping(uint256 => mapping(address => bool)) public hasVoted;
    uint256[] public proposedPrices;

    // Балансы и разрешения по стандарту ERC-20
    mapping(address => uint256) public balances;
    mapping(address => mapping(address => uint256)) public allowances;

    constructor(uint256 _tokenPrice, uint256 _buyFee, uint256 _sellFee) {
        admin = msg.sender;
        tokenPrice = _tokenPrice;
        buyFee = _buyFee;
        sellFee = _sellFee;
        lastBurnTime = block.timestamp;
    }

    // indexed позволяет фильтровать события по номеру голосования в логах.
    event VotingStarted(uint256 indexed votingNumber, uint256 startTime);
    event VotingEnded(uint256 indexed votingNumber, uint256 endTime);

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
    // ! запретить во время голосования?
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
        emit Transfer(_from, _to, _value); // Стандартное событие ERC-20
    }

    // Устанавливаем разрешение для другого адреса тратить токены владельца
    function approve(
        address _spender,
        uint256 _value
    ) external override returns (bool success) {
        if (_spender == address(0)) revert InvalidSpender();
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

    // ! требования к цене - минимум, максимум, кратность (для ограничения размера маппинга)?
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

    /** startVoting должен изменить votingStartedTime, 
    votingNumber, и     вызвать событие VotingStarted. */
    function startVoting() public {
        if (balances[msg.sender] < minTokenForStartVoting())
            revert InefficientTokens();
        if (votingActive()) revert VotingIsActive();
        votingStartedTime = block.timestamp;
        votingNumber++; // новый раунд голосования
        emit VotingStarted(votingNumber, votingStartedTime);
    }

    /*
       Завершение голосования.
       Можно вызвать только после окончания установленного времени.
       стоит ли winningPrice определять оффчейн (// ! безопасно ли?)
       ✅ Как обычно решают

            1️⃣ Ограничивают количество элементов.
            Например, не более 10 предложенных цен.

            2️⃣ Переносят вычисления off-chain.
            Например, результат голосования вычисляется сервером или DAO-скриптом,
            а контракт просто получает winningPrice через транзакцию.

            3️⃣ Разбивают процесс на несколько шагов.
            Вместо одного большого цикла — несколько маленьких функций с частичным подсчётом.

            4️⃣ Используют структуры данных с константным временем (O(1)).
            Например, mapping вместо array,
            чтобы не нужно было перебирать элементы.
    */
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
        if (msg.value < tokenPrice) revert InefficientETHForBuying();

        uint256 tokens = (msg.value * 1e18) / tokenPrice;

        // TODO Проверка если результат округления дал 0 токенов — отклоняем транзакцию
        uint256 fee = (tokens * buyFee) / fee_denominator;
        uint256 netTokens = tokens - fee;

        balances[msg.sender] += netTokens;
        balances[address(this)] += fee;
        totalSupply += tokens;
        accumulatedFees += fee;

        emit Transfer(address(0), msg.sender, netTokens);
    }

    function sell(uint256 amount) public notFrozen(msg.sender) {
        // TODO - модификатор nonReentrant (не даёт функции выполняться повторно, пока она не завершилась)
        if (amount == 0) revert ZeroTokenAmount();
        if (balances[msg.sender] < amount) revert InsufficientBalanceToSell();

        uint256 fee = (amount * sellFee) / fee_denominator;
        uint256 netTokens = amount - fee;

        uint256 ethAmount = (netTokens * tokenPrice) / 1e18;
        if (address(this).balance < ethAmount)
            revert InefficientETHInContract();

        balances[msg.sender] -= amount;
        balances[address(this)] += fee;
        accumulatedFees += fee;
        totalSupply -= netTokens;

        (bool ok, ) = payable(msg.sender).call{value: ethAmount}("");
        if (!ok) revert ETHTransferFailed();

        emit Transfer(msg.sender, address(0), amount);
    }

    function setBuyFee(uint256 _newFee) external {
        if (msg.sender != admin) revert OnlyAdmin();
        buyFee = _newFee;
    }

    function setSellFee(uint256 _newFee) external {
        if (msg.sender != admin) revert OnlyAdmin();
        sellFee = _newFee;
    }

    function burnAccumulatedFees() external {
        if (msg.sender != admin) revert OnlyAdmin();
        if (block.timestamp < lastBurnTime + 7 days) revert TooEarlyToBurn();
        totalSupply -= accumulatedFees;
        balances[address(this)] -= accumulatedFees;

        // практика для обозревателей
        emit Transfer(address(this), address(0), accumulatedFees);

        accumulatedFees = 0;
        lastBurnTime = block.timestamp;
    }
}

/**
   - ERC-20 совместимый токен с динамической ценой (tokenPrice);
   - Голосования за новую цену (владельцы токенов голосуют, вес = баланс);
   - На период голосования замораживаются транзакции у проголосовавших;
   - Покупка/продажа с комиссией, комиссия накапливается и сжигается раз в неделю;

*/

// ?
/**
Что делать, если откат транзакции делает вложенная фукнция
 */

//TODO Что дальше
/**
////Использовать TypeChain для генерации типов контрактов в тестах.
Контракт должен быть обновляемым (upgradeable).
//// Функцию endVoting может вызвать любой пользователь, но правила
//// должны проверять, что она вызывается только после истечения времени timeToVote.
Контракты должны быть задеплоены в тестовую сеть Sepolia и проверены на Etherscan (sepolia.etherscan.io).



ограничение на сумму ставки
ограничить функции правом администратора
Проверка перед сжиганием комиссий if (balances[address(this)] < accumulatedFees) revert InefficientBalance();
границы комиссии - Добавить проверку if (_newFee > fee_denominator) revert FeeTooHigh(); в setBuyFee() и setSellFee() чтобы комиссия не превышала 100%.
*/
//TODO Topics that have been learnt:
/**
1.  Formatting (wei, gwei, eth, etc.) 
2.  IERC20, ERC20 
3.  Solidity 
4.  Ethers.js + hardhat 
5.  Gas 
6.  Memoization pattern 
1️⃣	Результат голосования (yes/no или totalVotes)	Итоговое количество голосов для данного votingNumber	Вместо пересчёта каждого раза по mapping(address → voteAmount) можно хранить промежуточные суммы → меньше газа и быстрее итоговая функция endVoting()
2️⃣	Минимальный порог голосов (minTokensForVoting)	Один раз вычислить при startVoting() и сохранить	Не пересчитывать (totalSupply * 5) / 10000 при каждом вызове vote()
3️⃣	Результат tokenPrice или fee перерасчёта	Если формула фиксированная, можно кешировать итог для заданного периода	Сокращает дублируемые арифметические операции при buy() / sell()
4️⃣	Адреса уже проверенных участников	Хранить в mapping(address => bool) результат проверки “участвовал / нет”	При каждом vote() не нужно снова искать в массиве или в другой структуре данных
5️⃣	Итоговое значение balanceOf при блокировке	Кешировать значение баланса, который используется для расчёта веса голоса	Избегает повторных обращений к storage (дорогих по gas)
6️⃣	Timestamp окончания голосования	Вычислить votingStartedTime + timeToVote и сохранить в переменной	При каждом вызове endVoting() не нужно пересчитывать — просто сравнивать с заранее вычисленным временем
Problem solved: 
-  Problem with the cycles, O(N) functions that are dependent on users. 
*/
