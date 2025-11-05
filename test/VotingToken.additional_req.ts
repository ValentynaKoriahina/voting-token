import { expect } from "chai";
import { network } from "hardhat";
const { ethers } = await network.connect();

let token: any;
let [admin, addr1, addr2] = await ethers.getSigners();
const tokenPrice = ethers.parseEther("0.1");
const buyFee = 10 // 0.1 * 100 = 10
const sellFee = 5


async function deployTestContract() {
  [admin, addr1, addr2] = await ethers.getSigners();
  const Token = await ethers.getContractFactory("VotingTokenTest");
  const instance = await Token.deploy(tokenPrice, buyFee, sellFee);
  await instance.waitForDeployment();
  console.log("✅ Test contract deployed at:", await instance.getAddress());
  return instance;
}

describe("VotingToken - Additional requirements", function () {

  before(async function () {
    token = await deployTestContract();
  });

  it("buy() should revert on inefficient amount", async function () {
    await expect(
      token.connect(addr1).buy({ value: ethers.parseEther("0.05") })
    ).to.be.revertedWithCustomError(token, "InefficientETHForBuying");
  });

  it("sell() should revert if tokens are not specified", async function () {
    await expect(token.connect(addr1).sell(0n)).to.be.revertedWithCustomError(
      token,
      "ZeroTokenAmount"
    );
  });

  // it("buy() should mints tokens proportional to ETH sent", async function () {
  //   const amountEther = ethers.parseEther("0.3");
  //   const tokenPrice = await token.tokenPrice();
  //   await token.connect(addr1).buy({ value: amountEther });
  //   const expected = amountEther / tokenPrice;

  //   expect(await token.balanceOf(addr1.address)).to.equal(expected);
  //   expect(await token.totalSupply()).to.equal(5n);
  // });



  // it("sell() should burn tokens and send back ETH", async function () {
  //   const userTokensBalance = await token.balances(addr1.address);
  //   const contractTokensBalance = await token.totalSupply();
  //   const signersBalance = await ethers.provider.getBalance(addr1.address);

  //   await token.connect(addr1).sell(2n);

  //   const userTokensBalanceAfter = userTokensBalance - 2n;
  //   const contractTokensBalanceAfter = contractTokensBalance - 2n;

  //   expect(await token.balanceOf(addr1.address)).to.equal(
  //     userTokensBalanceAfter
  //   );
  //   expect(await token.totalSupply()).to.equal(contractTokensBalanceAfter);
  //   expect(await ethers.provider.getBalance(addr1.address)).to.be.gt(
  //     signersBalance
  //   );
  // });
});


describe("VotingToken - startVoting()", function () {

  let receipt: any, blockTime: bigint;

  beforeEach(async function () {
    token = await deployTestContract();
    await (await token.addTotalSupplyForTest(100000n)).wait();
    await (await token.giveBalanceForTest(addr1.address, 200n)).wait();

    const txPromise = token.connect(addr1).startVoting();
    await expect(token.connect(addr1).startVoting())
      .to.not.be.revertedWithCustomError(token, "InefficientTokens");

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
      "event VotingStarted(uint256 indexed votingNumber, uint256 startTime)"
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

  it("should prevent double participation through transfer", async function () {
    await expect(token.connect(addr1).vote(ethers.parseEther("0.12")))
      .to.not.be.revertedWithCustomError(token, "InefficientTokens");

    await expect(
      token.connect(addr1).transfer(addr2.address, 5n)
    ).to.be.revertedWithCustomError(token, "LockedUntilVotingEnds");

    await expect(token.connect(addr2).vote(ethers.parseEther("0.21")))
      .to.be.revertedWithCustomError(token, "InefficientTokens");


  });

});