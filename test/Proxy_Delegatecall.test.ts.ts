import { expect } from "chai";
import type { VotingTokenTest } from "../typechain-types/index.js"; // важно использовать import type 
import type { VotingTokenTest_Upgradeable } from "../typechain-types/index.js";
import { network } from "hardhat";
const { ethers } = await network.connect();

let token: VotingTokenTest_Upgradeable;
let logic, proxy;
let [admin, addr1, addr2] = await ethers.getSigners();
const tokenPrice = ethers.parseEther("0.1");
const buyFee = 10; // 0.1 * 100 = 10
const sellFee = 5;

async function deployProxyWithLogic() {
  const [admin] = await ethers.getSigners();

  // 1) Деплой логики БЕЗ аргументов конструктора
  const Logic = await ethers.getContractFactory("VotingTokenTest_Upgradeable");
  const logic = await Logic.deploy();        // ✅ без аргументов
  await logic.waitForDeployment();

  // 2) Деплой прокси, передаём адрес логики и администратора
  const Proxy = await ethers.getContractFactory("VotingToken_UUPSproxy");
  const proxy = await Proxy.deploy(
    await logic.getAddress(),
    admin.address
  );
  await proxy.waitForDeployment();

  // 3) Привязываем ABI логики к адресу прокси
  const token = await ethers.getContractAt(
    "VotingTokenTest_Upgradeable",
    await proxy.getAddress()
  );

  // 4) Вызываем initialize вместо конструктора (один раз)
  await token.connect(admin).initialize(
    tokenPrice,
    buyFee,
    sellFee
  );

  return { token, logic, proxy, admin };
}

describe("VotingTokenTest_Upgradeable - Additional requirements", function () {
  before(async function () {
    ({ token, logic, proxy, admin } = await deployProxyWithLogic());
  });

  it("sell() should revert if tokens are not specified", async function () {
    await expect(token.connect(addr1).sell(0n)).to.be.revertedWithCustomError(
      token,
      "ZeroTokenAmount"
    );
  });
});

describe("VotingToken - startVoting()", function () {
  let receipt: any, blockTime: bigint;

  beforeEach(async function () {
    ({ token } = await deployProxyWithLogic());
    await (await token.addTotalSupplyForTest(100000n)).wait();
    await (await token.giveBalanceForTest(addr1.address, 200n)).wait();

    const txPromise = token.connect(addr1).startVoting();
    await expect(
      token.connect(addr1).startVoting()
    ).to.not.be.revertedWithCustomError(token, "InefficientTokens");

    receipt = await (await txPromise).wait();

    const block = await ethers.provider.getBlock(receipt.blockNumber);
    blockTime = BigInt(block!.timestamp);
  });

  it("should set votingStartedTime correctly", async function () {
    expect(await token.votingStartedTime()).to.equal(blockTime);
  });

  it("should increment votingNumber", async function () {
    expect(await token.votingNumber()).to.equal(1n);
  });

  it("should emit VotingStarted event", async function () {
    const iface = new ethers.Interface([
      "event VotingStarted(uint256 indexed votingNumber, uint256 startTime)",
    ]);
    const event = iface.parseLog(receipt.logs[0]);
    expect(event!.name).to.equal("VotingStarted");
    expect(event!.args.votingNumber).to.equal(1n);
    expect(event!.args.startTime).to.equal(blockTime);
  });
});

describe("VotingToken - vote()", function () {
  let receipt: any;

  beforeEach(async function () {
    ({ token } = await deployProxyWithLogic());
    await (await token.addTotalSupplyForTest(100000)).wait();
    await (await token.giveBalanceForTest(addr1.address, 200n)).wait();
    await (await token.giveBalanceForTest(addr2.address, 10n)).wait();

    await token.connect(addr1).startVoting();
    const txPromise = token.connect(addr1).vote(ethers.parseEther("0.11"));
    receipt = await (await txPromise).wait();
  });

  it("Should prevent double participation through transfer", async function () {
    await expect(
      token.connect(addr1).transfer(addr2.address, 5n)
    ).to.be.revertedWithCustomError(token, "LockedUntilVotingEnds");
  });

  it("Vote transaction succeeds only if user holds ≥ 0.05 % of total supply", async function () {
    await expect(
      token.connect(addr2).vote(ethers.parseEther("0.21"))
    ).to.be.revertedWithCustomError(token, "InefficientTokens");

    await expect(
      token.connect(addr1).vote(ethers.parseEther("0.12"))
    ).to.not.be.revertedWithCustomError(token, "InefficientTokens");
  });
});

describe("VotingToken - endVoting()", function () {

  let timeToVote: bigint;

  beforeEach(async function () {
    ({ token } = await deployProxyWithLogic());
    await (await token.addTotalSupplyForTest(100000n)).wait();
    await (await token.giveBalanceForTest(addr1.address, 200n)).wait();
    await (await token.connect(addr1).startVoting()).wait();
    timeToVote = await token.timeToVote();
  });

  it("should revert if called before timeToVote elapsed", async function () {
    await expect(
      token.connect(addr1).endVoting()
    ).to.be.revertedWithCustomError(token, "VotingIsActive");
  });

  it("should allow anyone to call endVoting after timeToVote elapsed", async function () {
    await ethers.provider.send("evm_increaseTime", [Number(timeToVote) + 1000]);
    await ethers.provider.send("evm_mine");

    await expect(token.connect(addr2).endVoting()).to.emit(
      token,
      "VotingEnded"
    );
  });

  it("should correctly finalize voting, transfers should become unlocked", async function () {
    await ethers.provider.send("evm_increaseTime", [Number(timeToVote) + 1000]);
    await ethers.provider.send("evm_mine");

    await (await token.connect(addr1).endVoting()).wait();

    await expect(
      token.connect(addr1).transfer(addr2.address, 10n)
    ).to.not.be.revertedWithCustomError(token, "LockedUntilVotingEnds");
  });
});
