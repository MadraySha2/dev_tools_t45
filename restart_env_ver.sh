#!/bin/bash

set -u

ENV_FILE="$(dirname "$0")/.env"

if [ -f "$ENV_FILE" ]; then
  set -a
  source "$ENV_FILE"
  set +a
fi

BOT_TOKEN="${BOT_TOKEN:-}"
CHAT_ID="${CHAT_ID:-}"

usage() {
  echo "Usage: $0 -p <sandbox|productive|all>"
  exit 1
}

STAND=""

while getopts ":p:" opt; do
  case $opt in
    p) STAND="$OPTARG" ;;
    \?) usage ;;
    :) usage ;;
  esac
done

if [ -z "$STAND" ]; then
  usage
fi

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

send_telegram_document() {
  local file_path="$1"
  local caption="$2"

  if [ -z "$BOT_TOKEN" ] || [ -z "$CHAT_ID" ]; then
    return 0
  fi

  if [ ! -f "$file_path" ]; then
    return 0
  fi

  curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendDocument" \
    -F chat_id="${CHAT_ID}" \
    -F document=@"${file_path}" \
    -F caption="${caption}" \
    > /dev/null 2>&1
}

check_swagger() {
  local url="$1"
  local attempts=12
  local sleep_sec=10
  local i
  local code

  for ((i=1; i<=attempts; i++)); do
    code=$(curl -k -L -s -o /dev/null -w "%{http_code}" "$url")

    if [ "$code" = "200" ]; then
      return 0
    fi

    sleep "$sleep_sec"
  done

  return 1
}

restart_stand() {
  local stand_name="$1"
  local app_dir=""
  local target_dir=""
  local pid_file=""
  local log_file=""
  local jar_path=""
  local swagger_url=""
  local fallback_pids=""
  local pid=""
  local new_pid=""
  local last_log_file=""

  case "$stand_name" in
    sandbox)
      app_dir="/path/to/sandbox"
      jar_path="/path/to/sandbox/target/app.jar"
      swagger_url="https://sandbox.example.com/swagger-ui/index.html"
      ;;
    productive)
      app_dir="/path/to/production"
      jar_path="/path/to/production/target/app.jar"
      swagger_url="https://prod.example.com/swagger-ui/index.html"
      ;;
    *)
      return 1
      ;;
  esac

  target_dir="$app_dir/target"
  pid_file="$app_dir/app.pid"
  log_file="$app_dir/restart.log"
  last_log_file="/tmp/${stand_name}_last_log.txt"

  send_telegram_message "[${stand_name}] Restart started"

  cd "$app_dir" || return 1

  if [ -f "$pid_file" ]; then
    pid=$(cat "$pid_file")

    if ps -p "$pid" -o args= | grep -Fq -- "$jar_path"; then
      kill "$pid"
      sleep 10
    fi

    rm -f "$pid_file"
  fi

  fallback_pids=$(pgrep -f "Dstand.name=${stand_name}")

  if [ -n "${fallback_pids:-}" ]; then
    kill $fallback_pids
    sleep 10
  fi

  fallback_pids=$(pgrep -f "Dstand.name=${stand_name}")

  if [ -n "${fallback_pids:-}" ]; then
    kill -9 $fallback_pids
    sleep 2
  fi

  send_telegram_message "[${stand_name}] Build started"

  mvn clean install >> "$log_file" 2>&1

  if [ $? -ne 0 ]; then
    tail -n 100 "$log_file" > "$last_log_file"
    send_telegram_message "❌ [${stand_name}] Build failed"
    send_telegram_document "$last_log_file" "${stand_name} build log"
    return 1
  fi

  sleep 60

  if [ ! -f "$jar_path" ]; then
    jar_path=$(find "$target_dir" -maxdepth 1 -type f -name "*.jar" \
      ! -name "original-*.jar" \
      ! -name "*sources.jar" \
      ! -name "*javadoc.jar" | head -n 1)

    if [ -z "${jar_path:-}" ]; then
      tail -n 100 "$log_file" > "$last_log_file"
      send_telegram_message "❌ [${stand_name}] Jar not found"
      send_telegram_document "$last_log_file" "${stand_name} jar log"
      return 1
    fi
  fi

  cd "$target_dir" || return 1

  nohup java -Dstand.name="$stand_name" -jar "$(basename "$jar_path")" >> "$log_file" 2>&1 &
  new_pid=$!

  sleep 3

  if ! ps -p "$new_pid" > /dev/null 2>&1; then
    tail -n 100 "$log_file" > "$last_log_file"
    send_telegram_message "❌ [${stand_name}] Process died after start"
    send_telegram_document "$last_log_file" "${stand_name} start log"
    return 1
  fi

  echo "$new_pid" > "$pid_file"

  if check_swagger "$swagger_url"; then
    send_telegram_message "✅ [${stand_name}] Service is UP"
  else
    send_telegram_message "❌ [${stand_name}] Healthcheck failed"
  fi
}

case "$STAND" in
  sandbox)
    restart_stand "sandbox"
    ;;
  productive)
    restart_stand "productive"
    ;;
  all)
    restart_stand "sandbox"
    restart_stand "productive"
    ;;
  *)
    usage
    ;;
esac