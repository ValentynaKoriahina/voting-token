import { expect } from "chai";
import { deployVotingTokenProxy } from "./helpers/deployVotingTokenProxy.js";

describe("VotingToken via Transparent Proxy", function () {
  let admin: any;
  let addr1: any;
  let token: any;

  let buyFee: bigint = 200n;
  let sellFee: bigint = 100n;
  let tokenPriceValue: string = "0.002";

  before(async function () {
    const deployed = await deployVotingTokenProxy(
      tokenPriceValue,
      buyFee,
      sellFee
    );
    [admin, addr1] = deployed.signers;

    token = deployed.token;
  });

  it("should initialize correctly", async function () {
    expect(await token.name()).to.equal("VotingToken");
    expect(await token.symbol()).to.equal("VT");
    expect(await token.decimals()).to.equal(18);
  });

  it("should allow owner to mint", async function () {
    const totalBefore = await token.totalSupply();

    await token.connect(admin).mint(addr1.address, 100n);

    expect(await token.balanceOf(addr1.address)).to.equal(100n);
    expect(await token.totalSupply()).to.equal(totalBefore + 100n);
  });
});
