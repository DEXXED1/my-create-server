#!/usr/bin/env bash
# =============================================================================
# start.sh — автозапуск NeoForge-сервера Minecraft 1.21.1 в GitHub Codespaces
# Create Aeronautics + синхронизация мира через Git + туннель playit.gg
# =============================================================================
set -euo pipefail

# --- Конфигурация (можно переопределить через переменные окружения) ------------
MC_VERSION="${MC_VERSION:-1.21.1}"
# NeoForge для MC 1.21.1: версия вида 21.1.xxx (не путать с 21.4.x для MC 1.21.4+)
NEOFORGE_VERSION="${NEOFORGE_VERSION:-21.1.218}"
JAVA_MIN_MAJOR="${JAVA_MIN_MAJOR:-21}"
JAVA_MAX_HEAP="${JAVA_MAX_HEAP:-6500M}"
JAVA_MIN_HEAP="${JAVA_MIN_HEAP:-2048M}"
SERVER_PORT="${SERVER_PORT:-25565}"
GIT_BRANCH="${GIT_BRANCH:-main}"
PLAYIT_VERSION="${PLAYIT_VERSION:-v1.0.8}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

LOG_DIR="${SCRIPT_DIR}/logs"
PLAYIT_BIN="${SCRIPT_DIR}/bin/playit"
PLAYIT_LOG="${LOG_DIR}/playit.log"
NEOFORGE_INSTALLER="${SCRIPT_DIR}/neoforge-${NEOFORGE_VERSION}-installer.jar"
USER_JVM_ARGS="${SCRIPT_DIR}/user_jvm_args.txt"

PLAYIT_PID=""

# --- Утилиты ------------------------------------------------------------------
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

die() {
  log "ОШИБКА: $*" >&2
  exit 1
}

command_exists() {
  command -v "$1" &>/dev/null
}

java_major_version() {
  java -version 2>&1 | head -n1 | sed -E 's/.*"([0-9]+).*/\1/'
}

# --- 1. Java 21 (строго для Minecraft 1.21.1) ----------------------------------
ensure_java() {
  log "Проверка Java (требуется строго Java ${JAVA_MIN_MAJOR})..."

  if command_exists java; then
    local major
    major="$(java_major_version)"
    if [[ "$major" -ge "$JAVA_MIN_MAJOR" ]]; then
      log "Java найдена: $(java -version 2>&1 | head -n1)"
      return 0
    fi
    log "Установленная Java (${major}) не подходит для MC ${MC_VERSION}, обновляем..."
  fi

  log "Установка OpenJDK 21 через apt..."
  sudo apt-get update -qq
  sudo apt-get install -y openjdk-21-jre-headless

  if ! command_exists java; then
    die "Java не установлена после apt install."
  fi

  local major
  major="$(java_major_version)"
  if [[ "$major" -lt "$JAVA_MIN_MAJOR" ]]; then
    die "После установки Java ${major} < ${JAVA_MIN_MAJOR}. Требуется Java 21."
  fi

  log "OpenJDK 21 установлена: $(java -version 2>&1 | head -n1)"
}

# --- 2. Git PAT для push с донорских аккаунтов --------------------------------
setup_git_credentials() {
  local token="${GITHUB_PAT:-${GIT_PUSH_TOKEN:-}}"
  if [[ -z "$token" ]]; then
    log "GITHUB_PAT не задан — push будет работать только при наличии прав у текущего аккаунта."
    return 0
  fi

  local remote_url
  remote_url="$(git remote get-url origin 2>/dev/null || echo "")"
  if [[ -z "$remote_url" ]]; then
    log "Remote origin не настроен, пропускаем настройку PAT."
    return 0
  fi

  if [[ "$remote_url" =~ git@github.com:(.+)\.git ]]; then
    remote_url="https://github.com/${BASH_REMATCH[1]}.git"
  fi
  remote_url="$(echo "$remote_url" | sed -E 's|https://[^@]+@|https://|')"

  local repo_path
  repo_path="$(echo "$remote_url" | sed -E 's|https://github.com/||; s|\.git$||')"
  git remote set-url origin "https://x-access-token:${token}@github.com/${repo_path}.git"
  log "Git remote настроен для push через PAT."
}

# --- 3. Синхронизация мира из Git перед запуском ------------------------------
sync_world_from_git() {
  log "Синхронизация папки world/ с веткой ${GIT_BRANCH}..."

  if ! git rev-parse --git-dir &>/dev/null; then
    die "Это не git-репозиторий. Клонируйте репозиторий перед запуском."
  fi

  setup_git_credentials

  git fetch origin "$GIT_BRANCH" --quiet 2>/dev/null || log "fetch не удался (возможно, первый запуск)"

  if git show-ref --verify --quiet "refs/remotes/origin/${GIT_BRANCH}"; then
    git checkout "$GIT_BRANCH" 2>/dev/null \
      || git checkout -b "$GIT_BRANCH" "origin/${GIT_BRANCH}"
  else
    git checkout "$GIT_BRANCH" 2>/dev/null || git checkout -b "$GIT_BRANCH"
  fi

  if git rev-parse "origin/${GIT_BRANCH}" &>/dev/null; then
    log "Обновление world/ из origin/${GIT_BRANCH}..."
    git checkout "origin/${GIT_BRANCH}" -- world/ 2>/dev/null || true
  fi

  mkdir -p world
  log "Мир синхронизирован."
}

# --- 4. Сохранение мира в Git после остановки сервера -------------------------
save_world_to_git() {
  log "Сохранение мира в Git..."

  setup_git_credentials

  git config user.email >/dev/null 2>&1 || git config user.email "server@users.noreply.github.com"
  git config user.name  >/dev/null 2>&1 || git config user.name  "Minecraft Server"

  git add world/

  if git diff --cached --quiet; then
    log "Изменений в world/ нет, коммит не нужен."
    return 0
  fi

  local timestamp
  timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
  git commit -m "Автосохранение мира [${timestamp}]"

  log "Отправка мира на origin/${GIT_BRANCH}..."
  if git push origin "$GIT_BRANCH"; then
    log "Мир успешно сохранён в репозитории."
  else
    log "ОШИБКА: git push не удался. Проверьте GITHUB_PAT и права доступа."
    return 1
  fi
}

# --- 5. Установка NeoForge 1.21.1 ---------------------------------------------
neoforge_installed() {
  [[ -f "run.sh" ]] || return 1
  [[ -n "$(find libraries/net/neoforged/neoforge -name unix_args.txt 2>/dev/null | head -n1)" ]]
}

ensure_neoforge_server() {
  mkdir -p mods config logs bin

  if neoforge_installed; then
    log "NeoForge ${NEOFORGE_VERSION} уже установлен."
    return 0
  fi

  local installer_url
  installer_url="https://maven.neoforged.net/releases/net/neoforged/neoforge/${NEOFORGE_VERSION}/neoforge-${NEOFORGE_VERSION}-installer.jar"

  log "Скачивание NeoForge ${NEOFORGE_VERSION} для Minecraft ${MC_VERSION}..."
  log "URL: ${installer_url}"

  curl -fsSL "$installer_url" -o "$NEOFORGE_INSTALLER"

  log "Установка NeoForge (--installServer)..."
  java -jar "$NEOFORGE_INSTALLER" --installServer

  if ! neoforge_installed; then
    die "NeoForge не установился: run.sh или unix_args.txt не найдены."
  fi

  chmod +x run.sh 2>/dev/null || true
  log "NeoForge ${NEOFORGE_VERSION} установлен."
}

# Находит сгенерированный unix_args.txt (путь зависит от версии NeoForge)
resolve_unix_args() {
  local args_file
  args_file="$(find libraries/net/neoforged/neoforge -name unix_args.txt 2>/dev/null | head -n1)"
  if [[ -z "$args_file" ]]; then
    die "unix_args.txt не найден в libraries/net/neoforged/neoforge/. Запустите установку NeoForge."
  fi
  echo "$args_file"
}

# --- 6. JVM-флаги → user_jvm_args.txt (формат @argfile Java) ------------------
write_user_jvm_args() {
  log "Запись JVM-флагов в user_jvm_args.txt (Aikar's Flags, ${JAVA_MIN_HEAP}–${JAVA_MAX_HEAP})..."
  cat > "$USER_JVM_ARGS" <<EOF
# Автоматически сгенерировано start.sh — не редактируйте вручную
-Xms${JAVA_MIN_HEAP}
-Xmx${JAVA_MAX_HEAP}
-XX:+UseG1GC
-XX:+ParallelRefProcEnabled
-XX:MaxGCPauseMillis=200
-XX:+UnlockExperimentalVMOptions
-XX:+DisableExplicitGC
-XX:+AlwaysPreTouch
-XX:G1NewSizePercent=30
-XX:G1MaxNewSizePercent=40
-XX:G1HeapRegionSize=8M
-XX:G1ReservePercent=20
-XX:G1HeapWastePercent=5
-XX:G1MixedGCCountTarget=4
-XX:InitiatingHeapOccupancyPercent=15
-XX:G1MixedGCLiveThresholdPercent=90
-XX:G1RSetUpdatingPauseTimePercent=5
-XX:SurvivorRatio=32
-XX:+PerfDisableSharedMem
-XX:MaxTenuringThreshold=1
-Dusing.aikars.flags=https://mcflags.emc.gs
-Daikars.new.flags=true
EOF
}

# --- 7. EULA ------------------------------------------------------------------
ensure_eula() {
  if [[ ! -f "eula.txt" ]] || ! grep -q "eula=true" eula.txt 2>/dev/null; then
    log "Создание eula.txt (eula=true)..."
    cat > eula.txt <<'EOF'
# Автоматически принято скриптом start.sh
# https://aka.ms/MinecraftEULA
eula=true
EOF
  fi
}

# --- 8. playit.gg туннель -----------------------------------------------------
ensure_playit() {
  if [[ -x "$PLAYIT_BIN" ]]; then
    log "playit уже скачан: $PLAYIT_BIN"
    return 0
  fi

  mkdir -p bin
  local url="https://github.com/playit-cloud/playit-agent/releases/download/${PLAYIT_VERSION}/playit-linux-amd64"
  log "Скачивание playit ${PLAYIT_VERSION}..."
  curl -fsSL "$url" -o "$PLAYIT_BIN"
  chmod +x "$PLAYIT_BIN"
  log "playit скачан."
}

start_playit() {
  ensure_playit
  mkdir -p "$LOG_DIR"

  local secret="${PLAYIT_SECRET:-${SECRET_KEY:-}}"
  if [[ -n "$secret" ]]; then
    export SECRET_KEY="$secret"
    log "playit: авторизация через SECRET_KEY (постоянный IP)."
  else
    log "PLAYIT_SECRET не задан — при первом запуске потребуется claim URL в ${PLAYIT_LOG}"
    log "Получите ключ: https://playit.gg/account/agents"
  fi

  log "Запуск playit в фоне (лог: ${PLAYIT_LOG})..."
  nohup "$PLAYIT_BIN" > "$PLAYIT_LOG" 2>&1 &
  PLAYIT_PID=$!
  log "playit PID: ${PLAYIT_PID}"

  sleep 3
  if ! kill -0 "$PLAYIT_PID" 2>/dev/null; then
    log "Предупреждение: playit завершился. Проверьте ${PLAYIT_LOG}"
    PLAYIT_PID=""
  fi
}

stop_playit() {
  if [[ -n "$PLAYIT_PID" ]] && kill -0 "$PLAYIT_PID" 2>/dev/null; then
    log "Остановка playit (PID ${PLAYIT_PID})..."
    kill "$PLAYIT_PID" 2>/dev/null || true
    wait "$PLAYIT_PID" 2>/dev/null || true
  fi
}

# --- 9. Обработчик завершения -------------------------------------------------
cleanup() {
  local exit_code=$?
  log "Завершение работы (код: ${exit_code})..."
  stop_playit
  save_world_to_git || true
  exit "$exit_code"
}

trap cleanup EXIT INT TERM

# --- 10. Запуск NeoForge-сервера ----------------------------------------------
# NeoForge не запускается через java -jar server.jar.
# Правильный способ: java @user_jvm_args.txt @libraries/.../unix_args.txt nogui
run_server() {
  local unix_args server_pid
  unix_args="$(resolve_unix_args)"

  write_user_jvm_args
  ensure_eula

  log "=========================================="
  log " Запуск Minecraft NeoForge ${NEOFORGE_VERSION}"
  log " MC: ${MC_VERSION}"
  log " unix_args: ${unix_args}"
  log " RAM: ${JAVA_MIN_HEAP} – ${JAVA_MAX_HEAP}"
  log " Порт: ${SERVER_PORT} (туннель playit.gg)"
  log " Мир: world/"
  log "=========================================="
  log "Для остановки введите: stop"
  log "Адрес для игроков — смотрите ${PLAYIT_LOG} или панель playit.gg"
  log "=========================================="

  # @user_jvm_args.txt — наши JVM-флаги (Aikar's)
  # @unix_args.txt     — classpath и main-class от NeoForge
  # nogui              — headless-режим сервера
  java @"${USER_JVM_ARGS}" @"${unix_args}" nogui &
  server_pid=$!

  wait "$server_pid"
  log "Сервер остановлен."
}

# =============================================================================
# MAIN
# =============================================================================
main() {
  log "=== Minecraft NeoForge Server Launcher ==="

  ensure_java
  sync_world_from_git
  ensure_neoforge_server
  start_playit
  run_server
}

main "$@"
