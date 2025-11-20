# 🔐 Infisical + Solidity (Hardhat) — Шпаргалка

## 1. Установка (Windows)
```powershell
winget install Infisical.Infisical
```
Проверка:
```powershell
infisical --version
```

---

## 2. Логин в Infisical
```powershell
infisical login
```

---

## 3. Подключение проекта
(в папке проекта)
```powershell
infisical init
```
Выбрать:
- Project
- Environment: `dev`

---

## 4. Скачать секреты в `.env`
```powershell
infisical export > .env
```

Проверка:
```powershell
type .env
```

---

## 5. Hardhat: подключение `.env`
Установка dotenv:
```bash
npm install dotenv
```

`hardhat.config.js`:
```js
require("dotenv").config();

module.exports = {
  networks: {
    sepolia: {
      url: process.env.SEPOLIA_RPC_URL,
      accounts: [process.env.SEPOLIA_PRIVATE_KEY]
    }
  }
};
```

---

## 6. Запуск с автоподгрузкой секретов
```powershell
infisical run -- npx hardhat compile
```
```powershell
infisical run -- npx hardhat run scripts/deploy.js --network sepolia
```

---

## 7. Автоматический скрипт (Windows PowerShell)

Создай файл `setup.ps1` в корне проекта:

```powershell
Write-Host "== Infisical + Hardhat setup =="

infisical login
infisical init
infisical export > .env
npm install
npx hardhat compile

Write-Host "=== DONE! ==="
```

Запуск:
```powershell
./setup.ps1
```

---

## Быстрая последовательность после `git clone`
```powershell
infisical login
infisical init
infisical export > .env
npm install
npx hardhat compile
```

