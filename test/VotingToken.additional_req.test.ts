import { expect } from "chai";
import type { VotingTokenTest_Upgradeable } from "../typechain-types/index.js";; // важно использовать import type
import { network } from "hardhat";
const { ethers } = await network.connect();

let token: VotingTokenTest_Upgradeable;

let [admin, addr1, addr2] = await ethers.getSigners();
const tokenPrice = ethers.parseEther("0.002");
const buyFee = 500;
const sellFee = 500;

async function deployTestContract(): Promise<VotingTokenTest_Upgradeable> {
  [admin, addr1, addr2] = await ethers.getSigners();

  const Logic = await ethers.getContractFactory("VotingTokenTest_Upgradeable");
  const logic = await Logic.deploy();
  await logic.waitForDeployment();

  const Proxy = await ethers.getContractFactory("VotingToken_UUPSproxy");
  const proxy = await Proxy.deploy(
    await logic.getAddress(),
    admin.address
  );
  await proxy.waitForDeployment();

  const instance = (await ethers.getContractAt(
    "VotingTokenTest_Upgradeable",
    await proxy.getAddress()
  )) as VotingTokenTest_Upgradeable;

  // 4) Run initializer (вместо конструктора)
  await instance.initialize(tokenPrice, buyFee, sellFee);

  return instance;
}
describe("VotingToken - Additional requirements", function () {
  before(async function () {
    token = await deployTestContract();
  });

  it("buy() should be correctly processed", async function () {
    // tokenPrice = 0.002 ETH  (0.002 * 1e18 = 2 000 000 000 000 000 wei)
    // fee_denominator = 10_000
    // buyFee = 500 / 10000 = 0.05 => 5% (10000 bps = 100% масштаб для дробных процентов в "basis points"
    // sellFee = 500 => 5% 
    // msg.value = 0.05 ETH → 50_000_000_000_000_000 wei

    // подстановки: 
    // * tokens =
    // 50_000_000_000_000_000 * 1e18 = 50_000_000_000_000_000_000000000000000000 /
    //                                      / 2_000_000_000_000_000 = 25_000_000_000_000_000_000 (токена в масштабе wei )
    // 25_000_000_000_000_000_000 / 1e18  = 25 токенов

    // * или проверка через простую математику
    // 0.05 ETH / 0.002 ETH = 25 токенов

    // * fee
    //  = 25_000_000_000_000_000_000 tokens * 500 buyFee = 12_500_000_000_000_000_000_000 /
    //                                       / 10_000 fee_denominator = 1_250_000_000_000_000_000 токена
    //
    // 1_250_000_000_000_000_000 / 1e18 = 1.25
    // * или проверка через простую математику
    // 25 * 0.05 = 1.25
    // * netTokens
    // = 25 токенов - 1,25 fee токенов =>  23.75 * 1e18 = 23,750,000,000,000,000,000 (токена в масштабе wei)

    const ethAmount = ethers.parseEther("0.05");

    // 0.05 / 0.002 = 25 токенов
    const tokens = ethers.parseEther("25");

    // fee = tokens * 500 / 10000 = 1.25
    const feeTokens = ethers.parseEther("1.25");

    // net = 25 - 1.25 = 23.75
    const netTokens = ethers.parseEther("23.75");

    await expect(
      token.connect(addr1).buy({ value: ethAmount })
    )
      .to.emit(token, "Transfer")
      .withArgs(
        ethers.ZeroAddress,
        addr1.address,
        netTokens
      )
      .and.to.emit(token, "Transfer")
      .withArgs(
        ethers.ZeroAddress,
        await token.getAddress(),
        feeTokens
      )
      .and.to.emit(token, "Buy")
      .withArgs(
        addr1.address,
        ethAmount,
        netTokens,
        feeTokens
      );

    const balUser = await token.balanceOf(addr1.address);
    expect(balUser).to.equal(netTokens);
    console.log(`${balUser} == ${netTokens}`);

    const balContract = await token.balanceOf(await token.getAddress());
    expect(balContract).to.equal(feeTokens);
    console.log(`${balContract} == ${feeTokens}`);


    const totalSupply = await token.totalSupply();
    expect(totalSupply).to.equal(tokens);
    console.log(`${totalSupply} == ${tokens}`);


    const fees = await token.accumulatedFees();
    expect(fees).to.equal(feeTokens);
    console.log(`${fees} == ${feeTokens}`);
  });
});


describe("VotingToken - startVoting()", function () {
  let receipt: any, blockTime: bigint;

  beforeEach(async function () {
    token = await deployTestContract();
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
    token = await deployTestContract();
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
    token = await deployTestContract();
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
