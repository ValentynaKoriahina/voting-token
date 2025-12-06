import { expect } from "chai";
import { network } from "hardhat";
const { ethers } = await network.connect();
import { deployVotingTokenProxy } from "./helpers/deployVotingTokenProxy.js";

let token: any;
let admin: any;
let addr1: any;
let addr2: any;
let addr3: any;

describe("Tradable", function () {

  before(async function () {
    const deployed = await deployVotingTokenProxy();
    [admin, addr1, addr2, addr3] = deployed.signers;
    token = deployed.token;
  });

  it("buy() should be correctly processed", async function () {
    const ethAmount = ethers.parseEther("0.05");

    // 0.05 / 0.002 = 25 токенов
    const tokens = ethers.parseEther("25");

    // fee = tokens * 500 / 10000 = 1.25
    const feeTokens = ethers.parseEther("1.25");

    // net = 25 - 1.25 = 23.75
    const netTokens = ethers.parseEther("23.75");

    await expect(token.connect(addr1).buy({ value: ethAmount }))
      .to.emit(token, "Transfer")
      .withArgs(ethers.ZeroAddress, addr1.address, netTokens)
      .and.to.emit(token, "Transfer")
      .withArgs(ethers.ZeroAddress, await token.getAddress(), feeTokens)
      .and.to.emit(token, "Buy")
      .withArgs(addr1.address, ethAmount, netTokens, feeTokens);

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


