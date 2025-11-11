import { expect } from "chai";
import { network } from "hardhat";
const { ethers } = await network.connect();

let token: any;
const [admin, addr1, addr2] = await ethers.getSigners();
const tokenPrice = ethers.parseEther("0.01");
const buyFee = 10 // 0.1 * 100 = 10
const sellFee = 5


async function deployTestContract() {
  const Token = await ethers.getContractFactory("VotingTokenTest");
  const instance = await Token.deploy(tokenPrice, buyFee, sellFee);
  await instance.waitForDeployment();
  // console.log("Test contract deployed at:", await instance.getAddress());
  return instance;
}

describe("VotingToken - Main interface", function () {
  before(async function () {
    token = await deployTestContract();
  });


  it("should give balance to addr1", async function () {
    const tx = await token.giveBalanceForTest(addr1.address, 10n);
    await tx.wait();
    const balance = await token.balanceOf(addr1.address);
    expect(balance).to.equal(10n);
  });

  it("should revert transfer when balance is too low", async function () {
    await expect(
      token.connect(addr1).transfer(addr2.address, 99999n)
    ).to.be.revertedWithCustomError(token, "InefficientBalance");
  });

  it("should emit Transfer event for valid transfer", async function () {
    await expect(token.connect(addr1).transfer(addr2.address, 5n))
      .to.emit(token, "Transfer")
      .withArgs(addr1.address, addr2.address, 5n);
  });

  it("should update balances correctly after transfer", async function () {
    const balance1 = await token.balanceOf(addr1.address);
    const balance2 = await token.balanceOf(addr2.address);
    expect(balance1).to.equal(5n);
    expect(balance2).to.equal(5n);
  });
});

