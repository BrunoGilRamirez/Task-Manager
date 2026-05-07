#!/usr/bin/env bash
# =============================================================================
# stop.sh – Detiene el stack completo de Task Manager
#
# Uso:
#   bash stop.sh           # detiene procesos Node + contenedores Docker
#   bash stop.sh --docker  # detiene solo los contenedores Docker
#   bash stop.sh --prune   # detiene Docker y elimina volúmenes (reset DB)
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKER_ENV="$SCRIPT_DIR/docker/.env"

# ── Leer puertos desde config (con fallback) ──────────────────────────
_cfg() {
  local file="$1" key="$2" default="$3"
  if [[ -f "$file" ]]; then
    local v
    v=$(grep -E "^${key}=" "$file" 2>/dev/null | head -1 | cut -d'=' -f2- || true)
    echo "${v:-$default}"
  else
    echo "$default"
  fi
}

FRONT_PORT=$(_cfg "$SCRIPT_DIR/docker/.env"                  "FRONTEND_PORT" "4200")
BACK_PORT=$( _cfg "$SCRIPT_DIR/back/task-manager/.env"       "PORT"          "3000")

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

log_info()  { echo -e "${CYAN}[INFO]${RESET}  $*"; }
log_ok()    { echo -e "${GREEN}[OK]${RESET}    $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
log_step()  { echo -e "\n${BOLD}━━━ $* ━━━${RESET}"; }

MODE="${1:-}"

# =============================================================================
# Helper: matar todos los PIDs que escuchan en un puerto TCP (Windows-safe)
# Usa netstat + taskkill (disponible en Git Bash vía Windows)
# =============================================================================
kill_port() {
  local PORT="$1"
  # netstat en Windows lista líneas con "TCP  0.0.0.0:PORT" o "[::]"
  local PIDS
  PIDS=$(netstat -ano 2>/dev/null \
    | grep -E "[:.]${PORT}[[:space:]].*LISTENING" \
    | awk '{print $NF}' \
    | sort -u || true)

  if [[ -n "$PIDS" ]]; then
    while IFS= read -r PID; do
      [[ "$PID" =~ ^[0-9]+$ ]] || continue
      taskkill //PID "$PID" //F &>/dev/null 2>&1 || true
      log_ok "Puerto $PORT liberado (PID $PID)"
    done <<< "$PIDS"
    return 0
  fi
  return 1
}

# =============================================================================
# 1. Procesos Node (backend nodemon + frontend ng serve)
# =============================================================================
if [[ "$MODE" != "--docker" && "$MODE" != "--prune" ]]; then
  log_step "Procesos Node"

  KILLED=0

  # Matar por nombre de proceso (funciona en Git Bash vía taskkill)
  if taskkill //F //IM node.exe &>/dev/null 2>&1; then
    log_ok "Procesos node.exe detenidos."
    KILLED=1
  fi

  # Liberar puertos por si quedaron procesos zombi
  for PORT in "$BACK_PORT" "$FRONT_PORT"; do
    if kill_port "$PORT"; then
      KILLED=1
    fi
  done

  [[ $KILLED -eq 0 ]] && log_info "No había procesos Node corriendo."
fi

# =============================================================================
# 2. Contenedores Docker
# =============================================================================
log_step "Docker – contenedores"

if ! command -v docker &>/dev/null; then
  log_warn "Docker no está disponible en el PATH. Saltando."
else
  cd "$SCRIPT_DIR"

  if [[ "$MODE" == "--prune" ]]; then
    log_warn "Modo --prune: se eliminarán los volúmenes (¡se borrará la base de datos!)."
    docker compose --env-file "$DOCKER_ENV" down -v 2>&1 \
      | grep -v "^time=\|level=warning" || true
    log_ok "Contenedores y volúmenes eliminados."
  else
    docker compose --env-file "$DOCKER_ENV" down 2>&1 \
      | grep -v "^time=\|level=warning" || true
    log_ok "Contenedores detenidos (volúmenes conservados)."
  fi
fi

# =============================================================================
# Resumen
# =============================================================================
echo ""
echo -e "${BOLD}${RED}╔══════════════════════════════════════╗${RESET}"
echo -e "${BOLD}${RED}║   🛑  Task Manager detenido          ║${RESET}"
echo -e "${BOLD}${RED}╚══════════════════════════════════════╝${RESET}"
if [[ "$MODE" == "--prune" ]]; then
  echo -e "${YELLOW}  Volúmenes eliminados – la DB quedó en blanco.${RESET}"
  echo -e "${YELLOW}  Para reiniciar limpio: bash start.sh${RESET}"
fi
echo ""
