import { expect } from "chai";
import { network } from "hardhat";

const { ethers } = await network.connect();

describe("UUPS Proxy Upgrade", function () {

  it("Should change implementation address after upgrade", async function () {
    const [admin] = await ethers.getSigners();

    // 1. Деплой имплементации V1
    const ImplV1 = await ethers.getContractFactory("VotingTokenTest");
    const implV1 = await ImplV1.deploy(
      ethers.parseEther("0.01"),
      100,
      200
    );

    await implV1.waitForDeployment();
    console.log("Implementation V1:", await implV1.getAddress());

    // 4. Деплой имплементации V2
    const ImplV2 = await ethers.getContractFactory("VotingToken");
    const implV2 = await ImplV2.deploy(
      ethers.parseEther("0.01"),
      100,
      200
    );
    await implV2.waitForDeployment();
    console.log("Implementation V2:", await implV2.getAddress());

    // 2. Деплой прокси (ERC1967)
    const Proxy = await ethers.getContractFactory("VotingToken_UUPSproxy");
    const proxy = await Proxy.deploy(
      await implV1.getAddress(),
      admin.address
    );

    await proxy.waitForDeployment();
    console.log("Proxy:", await proxy.getAddress());

    // 3. Привязываем ABI имплементации V1 к адресу прокси
    const token = ImplV1.attach(await proxy.getAddress());

    // EIP-1967 — слот хранения адреса имплементации
    const IMPLEMENTATION_SLOT =
      "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc";

    const implBefore = await ethers.provider.getStorage(
      proxy.getAddress(),
      IMPLEMENTATION_SLOT
    );

    console.log("Implementation BEFORE upgrade:", implBefore);

    // 5. Апгрейд (через прокси → delegatecall → логика)
    await token.connect(admin).upgradeTo(await implV2.getAddress());

    const implAfter = await ethers.provider.getStorage(
      proxy.getAddress(),
      IMPLEMENTATION_SLOT
    );
    console.log("Implementation AFTER upgrade:", implAfter);

    expect(implBefore).to.not.equal(implAfter);
  });

});
