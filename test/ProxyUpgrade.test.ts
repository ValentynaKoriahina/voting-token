import { expect } from "chai";
import { network } from "hardhat";

const { ethers } = await network.connect();

describe("UUPS Proxy Upgrade", function () {

  it("Should change implementation address after upgrade", async function () {
    const [admin] = await ethers.getSigners();

    // ---------------------------------------------------------
    // 1. Деплой логики (имплементации) версии V1
    // ---------------------------------------------------------
    //
    // В UUPS-паттерне имплементация деплоится БЕЗ конструктора
    // инициализация будет делаться через proxy.
    //
    const ImplV1 = await ethers.getContractFactory("VotingToken_Upgradeable");
    const implV1 = await ImplV1.deploy();
    await implV1.waitForDeployment();

    const implV1addr = await implV1.getAddress();
    console.log("Implementation V1:", implV1addr);


    // ---------------------------------------------------------
    // 2. Деплой UUPS-прокси
    // ---------------------------------------------------------
    //
    // В UUPS-прокси мы передаём:
    //  - адрес логики V1
    //  - admin (кто может делать upgrade)
    //
    // Конструктор прокси ВЫЗЫВАЕТСЯ, а конструктор логики — НЕТ.
    //
    const Proxy = await ethers.getContractFactory("VotingToken_UUPSproxy");
    const proxy = await Proxy.deploy(
      implV1addr,      // адрес логики V1
      admin.address    // админ (тот, кто может вызывать upgradeTo)
    );

    await proxy.waitForDeployment();
    const proxyAddr = await proxy.getAddress();
    console.log("Proxy:", proxyAddr);


    // ---------------------------------------------------------
    // 3. Привязываем ABI логики V1 к адресу прокси
    // ---------------------------------------------------------
    //
    // Это ключевой момент:
    //
    //  - вызываем методы VotingToken_Upgradeable
    //  - но вызовы идут НА ПРОКСИ
    //  - прокси делает delegatecall → логика выполняется в storage прокси
    //
    const proxyAsV1 = await ethers.getContractAt(
      "VotingToken_Upgradeable",
      proxyAddr
    );


    // ---------------------------------------------------------
    // 4. Инициализация контракта
    // ---------------------------------------------------------
    //
    // initialize() вызывается ТОЛЬКО через proxy
    // initialize() никогда нельзя вызывать на имплементации
    //
    // Все переменные записываются в storage прокси,
    // как и должно быть в upgradeable-контракте.
    //
    await proxyAsV1.initialize(
      ethers.parseEther("0.01"),
      100,
      200
    );


    // ---------------------------------------------------------
    // 5. Деплой новой версии логики (V2)
    // ---------------------------------------------------------
    //
    // Тоже без конструктора и без параметров.
    // Menяем только реализацию, storage остаётся у прокси.
    //
    const ImplV2 = await ethers.getContractFactory("VotingToken_Upgradeable_V2");
    const implV2 = await ImplV2.deploy();
    await implV2.waitForDeployment();

    const implV2addr = await implV2.getAddress();
    console.log("Implementation V2:", implV2addr);


    // ---------------------------------------------------------
    // 6. Считываем адрес текущей логики из слота EIP-1967
    // ---------------------------------------------------------
    //
    // Слот жёстко стандартизирован:
    //   bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1)
    //
    // В нём хранится адрес действующей имплементации.
    //
    const IMPLEMENTATION_SLOT =
      "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc";

    const implBefore = await ethers.provider.getStorage(
      proxyAddr,
      IMPLEMENTATION_SLOT
    );

    console.log("Implementation BEFORE upgrade:", implBefore);


    // ---------------------------------------------------------
    // 7. Апгрейд прокси на V2
    // ---------------------------------------------------------
    //
    // Вызываем upgradeTo() ЧЕРЕЗ ПРОКСИ:
    //
    //  proxyAsV1.upgradeTo(implV2)
    //
    // При вызове:
    //  - Прокси получил вызов
    //  - Прокси через fallback делает delegatecall в логику V1
    //  - В логике V1 выполняется upgradeTo()
    //  - upgradeTo() записывает новый адрес в IMPLEMENTATION_SLOT
    //  - Прокси начинает использовать код V2
    //
    await proxyAsV1.upgradeTo(implV2addr);


    // ---------------------------------------------------------
    // 8. Проверяем, что адрес логики действительно изменился
    // ---------------------------------------------------------
    //
    const implAfter = await ethers.provider.getStorage(
      proxyAddr,
      IMPLEMENTATION_SLOT
    );

    console.log("Implementation AFTER upgrade:", implAfter);

    expect(implBefore).to.not.equal(implAfter);
  });

});
