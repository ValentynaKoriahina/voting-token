import { expect } from "chai";
import { network } from "hardhat";
const { ethers } = await network.connect();
import { deployVotingTokenProxy } from "./helpers/deployVotingTokenProxy.js";

let token: any;
let admin: any;
let addr1: any;
let addr2: any;
let addr3: any;

// ========================================================
// VotingToken - Additional requirements (buy())
// ========================================================
describe("Vote", function () {
  const tokenPrice = ethers.parseEther("0.002");
  const buyFee = 500;
  const sellFee = 500;

  before(async function () {
    const deployed = await deployVotingTokenProxy();
    [admin, addr1, addr2, addr3] = deployed.signers;
    token = deployed.token;

    // если нужно, можно выставить прайс/фии тут, если это не делается в deployVotingTokenProxy
    // await token.connect(admin).setTokenPrice(tokenPrice);
    // await token.connect(admin).setBuyFee(buyFee);
    // await token.connect(admin).setSellFee(sellFee);
  });

 // ========================================================
// VotingToken - startVoting()
// ========================================================
describe("VotingToken - startVoting()", function () {
  let receipt: any;
  let blockTime: bigint;

  beforeEach(async function () {
    const deployed = await deployVotingTokenProxy();
    [admin, addr1, addr2, addr3] = deployed.signers;
    token = deployed.token;

    const amountToMint = 100n;
    await token.connect(admin).mint(addr1.address, amountToMint);

    const tx = await token.connect(addr1).startVoting();
    receipt = await tx.wait();

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

// ========================================================
// VotingToken - vote()
// ========================================================
describe("VotingToken - vote()", function () {
  let receipt: any;

  beforeEach(async function () {
    const deployed = await deployVotingTokenProxy();
    [admin, addr1, addr2, addr3] = deployed.signers;
    token = deployed.token;

    await token.connect(admin).mint(addr1.address, 100n);

    await token.connect(addr1).startVoting();
    const tx = await token.connect(addr1).vote(ethers.parseEther("0.11"));
    receipt = await tx.wait();
  });

  it("Should prevent double participation through transfer", async function () {
    await expect(
      token.connect(addr1).transfer(addr2.address, 5n)
    ).to.be.revertedWithCustomError(token, "LockedUntilVotingEnds");
  });

  it("Vote transaction succeeds only if user holds ≥ 0.05 % of total supply", async function () {
    await expect(
      token.connect(addr2).vote(ethers.parseEther("0.21"))
    ).to.be.revertedWithCustomError(token, "InsufficientTokens");

    await expect(
      token.connect(addr1).vote(ethers.parseEther("0.12"))
    ).to.not.be.revertedWithCustomError(token, "InsufficientTokens");
  });
});

// ========================================================
// VotingToken - endVoting()
// ========================================================
describe("VotingToken - endVoting()", function () {
  let timeToVote: bigint;
  const amountToMint = 100000n;

  beforeEach(async function () {
    const deployed = await deployVotingTokenProxy();
    [admin, addr1, addr2, addr3] = deployed.signers;
    token = deployed.token;

    await token.connect(admin).mint(addr1.address, amountToMint);

    const tx = await token.connect(addr1).startVoting();
    await tx.wait();

    timeToVote = await token.timeToVote();
  });

  it("should revert if called before timeToVote elapsed", async function () {
    await expect(
      token.connect(addr1).endVoting()
    ).to.be.revertedWithCustomError(token, "VotingIsActive");
  });

  it("should allow anyone to call endVoting after timeToVote elapsed", async function () {
    await ethers.provider.send("evm_increaseTime", [Number(timeToVote) + 1000]);
    await ethers.provider.send("evm_mine", []);

    await expect(token.connect(addr2).endVoting()).to.emit(
      token,
      "VotingEnded"
    );
  });

  it("should correctly finalize voting, transfers should become unlocked", async function () {
    await ethers.provider.send("evm_increaseTime", [Number(timeToVote) + 1000]);
    await ethers.provider.send("evm_mine", []);

    await (await token.connect(addr1).endVoting()).wait();

    await expect(
      token.connect(addr1).transfer(addr2.address, 10n)
    ).to.not.be.revertedWithCustomError(token, "LockedUntilVotingEnds");
  });
});
