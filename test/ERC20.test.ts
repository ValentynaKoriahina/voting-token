import { expect } from "chai";
import { network } from "hardhat";
const { ethers } = await network.connect();

const name = "Test";
const symbol = "T";
const decimals = 18;

let token: any;
const [admin, addr1, addr2, addr3] = await ethers.getSigners();

async function deployTestContract() {
  const Token = await ethers.getContractFactory("ERC20Test");
  const instance = await Token.deploy(name, symbol, decimals);
  await instance.waitForDeployment();
  console.log("Test contract deployed at:", await instance.getAddress());
  return instance;
}

describe("ERC20.sol - main Interface", function () {
  before(async function () {
    token = await deployTestContract();
  });

  it("should give balance to addr1", async function () {
    const totalSupply_b = await token.totalSupply();

    const tx = await token.setBalanceForTest(addr1.address, 10n);
    await tx.wait();
    const balance = await token.balanceOf(addr1.address);
    const totalSupply_a = await token.totalSupply();
    expect(balance).to.equal(10n);
    expect(totalSupply_a).to.equal(totalSupply_b + 10n);
  });

  it("should revert if allowance is insufficient", async function () {
    await expect(
      token.connect(addr1).transfer(addr2.address, 99999n)
    ).to.be.revertedWithCustomError(token, "InsufficientBalance");
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

  it("should set the allowance and emit Approval event", async function () {
    await expect(token.connect(addr1).approve(addr2, 200n))
      .to.emit(token, "Approval")
      .withArgs(addr1, addr2, 200n)
  });

  it("should decrease allowance and emit Transfer event", async function () {

    await token.connect(addr1).approve(addr2, 300n);

    const allowance_b = await token.allowance(addr1, addr2);

    await expect(token.connect(addr2).transferFrom(addr1, addr3, 2n))
      .to.emit(token, "Transfer")
      .withArgs(addr1, addr3, 2n);

    const allowance_a = await token.allowance(addr1, addr2);

    expect(allowance_a).to.equal(allowance_b - 2n);
  });

  it("should revert if allowance is insufficient", async function () {

    await token.connect(addr1).approve(addr2, 600n);

    await expect(token.connect(addr2).transferFrom(addr1, addr3, 601n))
      .to.be.revertedWithCustomError(token, "AllowanceExceeded");
  });

});

