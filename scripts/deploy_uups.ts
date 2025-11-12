import { network } from "hardhat";
const { ethers } = await network.connect();

async function main() {
  console.log("🚀 Начинаем деплой в сеть Sepolia...");

  const [deployer] = await ethers.getSigners();
  console.log("Адрес деплойера:", deployer.address);
  const balance = await ethers.provider.getBalance(deployer.address);
  console.log("Баланс:", ethers.formatEther(balance), "ETH");

  // 1Деплой реализации (логического контракта)
  const Logic = await ethers.getContractFactory("VotingToken_Upgradeable");
  const logic = await Logic.deploy();
  await logic.waitForDeployment();
  console.log("Логика (implementation) задеплоена по адресу:", await logic.getAddress());

  // Деплой прокси (UUPS)
  const Proxy = await ethers.getContractFactory("VotingToken_UUPSproxy");
  const proxy = await Proxy.deploy(await logic.getAddress(), deployer.address);
  await proxy.waitForDeployment();
  console.log("Прокси задеплоен по адресу:", await proxy.getAddress());

  // Привязываем ABI логического контракта к адресу прокси
  const token = await ethers.getContractAt(
    "VotingToken_Upgradeable",
    await proxy.getAddress()
  );

  // Инициализация (вместо конструктора)
  const tokenPrice = ethers.parseEther("0.01"); // 0.01 ETH за 1 токен (в пересчёте на 1e18 единиц)
  const buyFee = 100n;  // Комиссия при покупке 1.00% (из 10000)
  const sellFee = 150n; // Комиссия при продаже 1.50% (из 10000)

  console.log("Инициализация контракта...");
  const tx = await token.initialize(tokenPrice, buyFee, sellFee);
  await tx.wait();
  console.log("✅ Контракт успешно инициализирован!");

  console.log("====================================");
  console.log("Логика (implementation):", await logic.getAddress());
  console.log("Прокси:", await proxy.getAddress());
  console.log("Админ (EIP-1967):", deployer.address);
  console.log("====================================");
}

main().catch((error) => {
  console.error("❌ Ошибка при деплое:", error);
  process.exitCode = 1;
});
