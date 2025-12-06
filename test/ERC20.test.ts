import { expect } from "chai";
import { deployVotingTokenProxy } from "./helpers/deployVotingTokenProxy.js";

describe("ERC20", function () {
  let token: any;
  let admin: any;
  let addr1: any;
  let addr2: any;
  let addr3: any;

  const amountToMint = 100n;
  const amountToTransfer = 50n;

  before(async function () {
    const deployed = await deployVotingTokenProxy();

    [admin, addr1, addr2, addr3] = deployed.signers;
    token = deployed.token;
  });

  it("should give balance to addr1", async function () {
    
    const totalSupply_b = await token.totalSupply();
    const tx = await token.connect(admin).mint(addr1.address, amountToMint);
    await tx.wait();
    const balance = await token.balanceOf(addr1.address);
    const totalSupply_a = await token.totalSupply();
    expect(balance).to.equal(amountToMint);
    expect(totalSupply_a).to.equal(totalSupply_b + amountToMint);
  });

  it("should revert if allowance is insufficient", async function () {
    await expect(
      token.connect(addr1).transfer(addr2.address, 99999n)
    ).to.be.revertedWithCustomError(token, "InsufficientBalance");
  });

  it("should emit Transfer event for valid transfer", async function () {
    await expect(token.connect(addr1).transfer(addr2.address, amountToTransfer))
      .to.emit(token, "Transfer")
      .withArgs(addr1.address, addr2.address, amountToTransfer);
  });

  it("should update balances correctly after transfer", async function () {
    const balance1 = await token.balanceOf(addr1.address);
    const balance2 = await token.balanceOf(addr2.address);
    expect(balance1).to.equal(amountToTransfer);
    expect(balance2).to.equal(amountToTransfer);
  });

  it("should set the allowance and emit Approval event", async function () {
    await expect(token.connect(addr1).approve(addr2, 200n))
      .to.emit(token, "Approval")
      .withArgs(addr1, addr2, 200n);
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

    await expect(
      token.connect(addr2).transferFrom(addr1, addr3, 601n)
    ).to.be.revertedWithCustomError(token, "AllowanceExceeded");
  });
});
