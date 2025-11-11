import { expect } from "chai";
import { network } from "hardhat";
const { ethers } = await network.connect();
import { Contract } from "ethers"; // !
import type { VotingTokenTest } from "../typechain-types/index.js";

describe("Proxy + VotingToken", function () {
  let token: VotingTokenTest;
  let logic: VotingTokenTest;
  let proxy: any;
  let admin: any;


  const tokenPrice: bigint = ethers.parseEther("0.01");
  const buyFee: number = 100;    // 1%
  const sellFee: number = 200;   // 2%

  beforeEach(async () => {
    [admin] = await ethers.getSigners();

    const Logic = await ethers.getContractFactory("VotingTokenTest");
    logic = await Logic.deploy(tokenPrice, buyFee, sellFee);
    await logic.waitForDeployment();

    const Proxy = await ethers.getContractFactory("VotingToken_UUPSproxy");
    proxy = await Proxy.deploy(await logic.getAddress(), admin);
    await proxy.waitForDeployment();

    token = await ethers.getContractAt(
      "VotingTokenTest",
      await proxy.getAddress()
    );
  });

  it("Should set balance through proxy", async () => {
    await token.giveBalanceForTest(admin.address, 123n);
    expect(await token.balanceOf(admin.address)).to.equal(123n);
  });
});
