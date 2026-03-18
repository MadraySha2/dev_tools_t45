# Bash Deploy Tools

---

# 🇷🇺 Описание

Набор bash-скриптов для:
- перезапуска backend-сервисов
- проверки доступности сервисов (healthcheck)
- отправки уведомлений в Telegram

Подходит для простого деплоя без CI/CD.

---

## 📂 Структура проекта

script/
├── restart.sh
├── healthcheck.sh
├── .env          # локальный (НЕ коммитить)
├── .env.example
└── README.md

---

## ⚙️ Настройка

Создай файл `.env` рядом со скриптами:

BOT_TOKEN=your_telegram_bot_token
CHAT_ID=your_chat_id

---

## 🚀 Usage

./restart.sh -p sandbox
./restart.sh -p productive
./restart.sh -p all

./healthcheck.sh

---

## ⏰ Cron

CRON_TZ=Europe/Moscow
0 6-23 * * * /bin/bash /path/to/healthcheck.sh >> /tmp/healthcheck.log 2>&1

*/30 6-23 * * * /bin/bash /path/to/healthcheck.sh >> /tmp/healthcheck.log 2>&1

0 17 * * * /bin/bash /path/to/restart.sh -p sandbox

---

# 🇬🇧 Description

A set of bash scripts for:
- restarting backend services
- performing health checks
- sending Telegram notifications

---

## 🚀 Usage

./restart.sh -p sandbox
./restart.sh -p productive
./restart.sh -p all

./healthcheck.sh

