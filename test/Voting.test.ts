import { expect } from "chai";
import { deployVotingTokenProxy } from "./helpers/deployVotingTokenProxy.js";

let token: any;
let admin: any;
let addr1: any;
let addr2: any;
let addr3: any;

let ethers: any;
let buyFee: bigint = 200n;
let sellFee: bigint = 100n;
let tokenPriceValue: string = "0.002";

describe("VotingToken - startVoting()", function () {
  let receipt: any;
  let blockTime: bigint;

  beforeEach(async function () {
    const deployed = await deployVotingTokenProxy(
      tokenPriceValue,
      buyFee,
      sellFee
    );

    [admin, addr1, addr2, addr3] = deployed.signers;
    token = deployed.token;
    ethers = deployed.ethers;

    const amountToMint = ethers.parseEther("100");
    await token.connect(admin).mint(admin.address, amountToMint);

    const tx = await token.connect(admin).startVoting();
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

describe("VotingToken - vote()", function () {
  before(async function () {
    const deployed = await deployVotingTokenProxy(
      tokenPriceValue,
      buyFee,
      sellFee
    );

    [admin, addr1, addr2, addr3] = deployed.signers;
    token = deployed.token;
    ethers = deployed.ethers;

    const amountToMint = ethers.parseEther("100");
    await token.connect(admin).mint(admin.address, amountToMint);

    const tx = await token.connect(admin).mint(admin.address, amountToMint);
    await tx.wait();

    await token.connect(admin).startVoting();
  });

  it("Vote transaction succeeds only if user holds ≥ 0.05 % of total supply", async function () {
    const balance = await token.balanceOf(addr1.address);
    console.log("Token balance of addr1:", balance.toString());
    const totalSupply = await token.totalSupply();
    console.log("totalSupply (wei):", totalSupply);
    const minTokensForVoting = await token.minTokensForVoting();
    console.log("minTokensForVoting", minTokensForVoting);

    await expect(
      token.connect(addr1).vote(ethers.parseEther("0.21"))
    ).to.be.revertedWithCustomError(token, "InsufficientTokens");

    const fundAmount = minTokensForVoting + 1n;
    await token.connect(admin).transfer(addr1.address, fundAmount);

    await expect(
      token.connect(addr1).vote(ethers.parseEther("0.12"))
    ).to.not.be.revertedWithCustomError(token, "InsufficientTokens");
  });

  it("Should prevent double participation through transfer", async function () {
    await expect(
      token.connect(addr1).transfer(addr2.address, 5n)
    ).to.be.revertedWithCustomError(token, "LockedUntilVotingEnds");
  });
});

describe("VotingToken - endVoting()", function () {
  let timeToVote: bigint;

  beforeEach(async function () {
    const deployed = await deployVotingTokenProxy(
      tokenPriceValue,
      buyFee,
      sellFee
    );

    [admin, addr1, addr2, addr3] = deployed.signers;
    token = deployed.token;
    ethers = deployed.ethers;

    const amountToMint = ethers.parseEther("100000");
    await token.connect(admin).mint(admin.address, amountToMint);

    const tx = await token.connect(admin).startVoting();
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
