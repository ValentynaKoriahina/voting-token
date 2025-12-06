import { network } from "hardhat";
const { ethers } = await network.connect();

/**
 * Deploys:
 *  - VotingToken (implementation)
 *  - AppProxyAdmin
 *  - AppTransparentUpgradeableProxy
 * Initializes VotingToken through proxy.
 */
export async function deployVotingTokenProxy() {
  const signers = await ethers.getSigners();
  const [admin] = signers;

  const name = "VotingToken";
  const symbol = "VT";
  const decimals = 18;
  const tokenPrice = ethers.parseEther("0.002");
  const buyFee = 500;
  const sellFee = 500;

  //
  // 1. Deploy implementation
  //
  const Token = await ethers.getContractFactory("VotingToken");
  const logic = await Token.deploy();
  await logic.waitForDeployment();

  //
  // 2. Deploy ProxyAdmin
  //
  const ProxyAdmin = await ethers.getContractFactory("AppProxyAdmin");
  const proxyAdmin = await ProxyAdmin.deploy(admin.address);
  await proxyAdmin.waitForDeployment();

  //
  // 3. Encode initialize()
  //
  const initData = Token.interface.encodeFunctionData("initialize", [
    name,
    symbol,
    tokenPrice,
    buyFee,
    sellFee,
  ]);

  //
  // 4. Deploy Transparent Proxy
  //
  const Proxy = await ethers.getContractFactory(
    "AppTransparentUpgradeableProxy"
  );

  const proxy = await Proxy.deploy(
    await logic.getAddress(), // implementation
    await proxyAdmin.getAddress(), // proxy admin
    initData // initializer call
  );

  await proxy.waitForDeployment();

  //
  // 5. Attach ABI of VotingToken to proxy address
  //
  const token = Token.attach(await proxy.getAddress());

  return {
    signers,
    token,
    logic,
    proxyAdmin,
    proxy,
    name,
    symbol,
    decimals,
  };
}
