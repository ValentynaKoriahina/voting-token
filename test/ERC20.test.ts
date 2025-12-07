import { expect } from "chai";
import { deployVotingTokenProxy } from "./helpers/deployVotingTokenProxy.js";

describe("ERC20", function () {
  let token: any;
  let admin: any;
  let addr1: any;
  let addr2: any;
  let addr3: any;

  let ethers: any;
  let amountToMint: string;
  let amountToTransfer: string;


  beforeEach(async function () {
    const buyFee: bigint = 200n;
    const sellFee: bigint = 100n;
    const tokenPriceValue = "0.002";
    const deployed = await deployVotingTokenProxy(
      tokenPriceValue,
      buyFee,
      sellFee
    );

    [admin, addr1, addr2, addr3] = deployed.signers;
    token = deployed.token;
    ethers = deployed.ethers;
  });

  it("should give balance to addr1", async function () {
    amountToMint = ethers.parseEther("100");
    const totalSupply_b = await token.totalSupply();
    const tx = await token.connect(admin).mint(addr1.address, amountToMint);
    await tx.wait();
    const balance = await token.balanceOf(addr1.address);
    console.log("balance", balance);
    const totalSupply_a = await token.totalSupply();
    expect(balance).to.equal(amountToMint);
    expect(totalSupply_a).to.equal(totalSupply_b + amountToMint);
  });

  it("should revert if allowance is insufficient", async function () {
    amountToTransfer = ethers.parseEther("9999999");

    await expect(
      token.connect(addr1).transfer(addr2.address, amountToTransfer)
    ).to.be.revertedWithCustomError(token, "InsufficientBalance");
  });

  it("should emit Transfer event for valid transfer", async function () {
    const tx = await token.connect(admin).mint(addr1.address, amountToMint);
    await tx.wait();
    amountToTransfer = ethers.parseEther("10");

    await expect(token.connect(addr1).transfer(addr2.address, amountToTransfer))
      .to.emit(token, "Transfer")
      .withArgs(addr1.address, addr2.address, amountToTransfer);
  });

  it("should update balances correctly after transfer", async function () {
    const amountToMint = ethers.parseEther("100");
    await token.connect(admin).mint(addr1.address, amountToMint);

    const amountToTransfer = ethers.parseEther("10");
    await token.connect(addr1).transfer(addr2.address, amountToTransfer);

    const balance1 = await token.balanceOf(addr1.address);
    const balance2 = await token.balanceOf(addr2.address);

    expect(balance1).to.equal(amountToMint - amountToTransfer);
    expect(balance2).to.equal(amountToTransfer);
  });

  it("should set the allowance and emit Approval event", async function () {
    const amount = ethers.parseEther("200");
    await expect(token.connect(addr1).approve(addr2, amount))
      .to.emit(token, "Approval")
      .withArgs(addr1, addr2, amount);
  });

  it("should decrease allowance and emit Transfer event", async function () {
    const amountToApprove = ethers.parseEther("300");
    const amountToTransfer = ethers.parseEther("2");
    const amountToMint = ethers.parseEther("500");
    const tx = await token.connect(admin).mint(addr1.address, amountToMint);
    await tx.wait();
    await token.connect(addr1).approve(addr2, amountToApprove);

    const allowance_b = await token.allowance(addr1, addr2);

    await expect(
      token.connect(addr2).transferFrom(addr1, addr3, amountToTransfer)
    )
      .to.emit(token, "Transfer")
      .withArgs(addr1, addr3, amountToTransfer);

    const allowance_a = await token.allowance(addr1, addr2);

    expect(allowance_a).to.equal(allowance_b - amountToTransfer);
  });

  it("should revert if allowance is insufficient", async function () {
    const amountToApprove = ethers.parseEther("600");
    await token.connect(addr1).approve(addr2, amountToApprove);

    await expect(
      token.connect(addr2).transferFrom(addr1, addr3, amountToApprove + 1n)
    ).to.be.revertedWithCustomError(token, "AllowanceExceeded");
  });
});
