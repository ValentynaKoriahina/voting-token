# 🧰 Surya – Быстрая шпаргалка

## 1. Наследование (граф + PNG)

```bash
surya inheritance \
contracts/Initializable.sol \
contracts/VotingToken_Upgradeable_V2.sol \
contracts/VotingToken_UUPSproxy.sol \
contracts/VotingToken_UUPSproxyStorage.sol | dot -Tpng > inheritance.png
```

📌 Используется, чтобы увидеть дерево наследования **только нужных контрактов**.

---

## 2. Трассировка вызова функции (ftrace)

```bash
surya ftrace VotingToken_Upgradeable_V2::upgradeTo all contracts/*.sol
```

📌 Показывает полный путь вызовов, начиная с `upgradeTo`.

---

## Полезно помнить

- `inheritance` → структура наследования
- `ftrace` → граф вызовов функций
- `dot -Tpng` → превращает DOT в картинку
