#!/bin/bash

ENV_FILE="$(dirname "$0")/.env"

if [ -f "$ENV_FILE" ]; then
  set -a
  source "$ENV_FILE"
  set +a
fi

BOT_TOKEN="${BOT_TOKEN:-}"
CHAT_ID="${CHAT_ID:-}"

SANDBOX_URL="https://sandbox.example.com/swagger-ui/index.html"
PROD_URL="https://prod.example.com/swagger-ui/index.html"

send_telegram_message() {
  local text="$1"

  if [ -z "$BOT_TOKEN" ] || [ -z "$CHAT_ID" ]; then
    return 0
  fi

  curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
    -d chat_id="${CHAT_ID}" \
    --data-urlencode text="${text}" \
    > /dev/null 2>&1
}

check() {
  local name="$1"
  local url="$2"
  local code

  code=$(curl -k -L -s -o /dev/null -w "%{http_code}" "$url")

  if [ "$code" = "200" ]; then
    echo "✅ [$name] OK"
  else
    echo "❌ [$name] DOWN ($code)"
  fi
}

res1=$(check "sandbox" "$SANDBOX_URL")
res2=$(check "productive" "$PROD_URL")

if [[ "$res1" == *"❌"* || "$res2" == *"❌"* ]]; then
  send_telegram_message "$res1
$res2"
fi