# 🧪 Hardhat Test Run Cheat Sheet

### 🔹 Запуск всех тестов
```bash
npx hardhat test
```
Запускает все тесты из папки `test/`.

---

### 🔹 Запуск конкретного файла
```bash
npx hardhat test test/VotingToken.ts
```
или с подпапкой:
```bash
npx hardhat test test/unit/VotingToken.ts
```

---

### 🔹 Запуск тестов по названию (поиск через `--grep`)
```bash
npx hardhat test --grep "buy"
```
Запускает только те тесты, где в названии `describe()` или `it()` встречается слово `buy`.

Полное совпадение:
```bash
npx hardhat test --grep "^should revert on inefficient amount$"
```

---

### 🔹 Запуск только одного теста в коде
```ts
it.only("should revert on inefficient amount", async function () { ... });
```
или
```ts
describe.only("VotingToken", function () { ... });
```
Запустит **только этот** блок, остальные будут пропущены.

---

### 🔹 Комбинации
- Один файл + фильтр:
  ```bash
  npx hardhat test test/VotingToken.ts --grep "sell"
  ```
- Один файл + `it.only` внутри — тоже работает.

---

### 🔹 Сокращения через `package.json`
Добавь алиасы:
```json
"scripts": {
  "test:all": "npx hardhat test",
  "test:token": "npx hardhat test test/VotingToken.ts",
  "test:fees": "npx hardhat test --grep 'fee'"
}
```
Тогда можно запускать:
```bash
npm run test:token
```

---

### 🔹 Дополнительно
- `--parallel` — запускает тесты одновременно (ускоряет на многоядерных CPU)
- `--bail` — останавливает при первой ошибке
- `--reporter` — меняет формат вывода, напр. `spec`, `dot`, `json`

Пример:
```bash
npx hardhat test --parallel --bail --grep "buy"
```

