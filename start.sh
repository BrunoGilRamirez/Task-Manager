#!/usr/bin/env bash
# =============================================================================
# start.sh – Levanta el stack completo de Task Manager
#
# Uso:
#   bash start.sh          # levanta Docker + backend + frontend
#   bash start.sh --docker # solo levanta / verifica los contenedores Docker
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKER_ENV="$SCRIPT_DIR/docker/.env"
BACK_DIR="$SCRIPT_DIR/back/task-manager"
FRONT_DIR="$SCRIPT_DIR/front/task-manager"

# ── Leer puertos desde config (con fallback a los valores por defecto) ────────
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

FRONT_PORT=$(_cfg "$DOCKER_ENV"                  "FRONTEND_PORT"  "4200")
BACK_PORT=$( _cfg "$SCRIPT_DIR/back/task-manager/.env" "PORT"     "3000")
SB_PORT=$(   _cfg "$DOCKER_ENV"                  "KONG_HTTP_PORT" "5433")
MAIL_PORT=$( _cfg "$DOCKER_ENV"                  "MAILPIT_UI_PORT" "5435")

# ── Colores ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

log_info()  { echo -e "${CYAN}[INFO]${RESET}  $*"; }
log_ok()    { echo -e "${GREEN}[OK]${RESET}    $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
log_error() { echo -e "${RED}[ERROR]${RESET} $*"; }
log_step()  { echo -e "\n${BOLD}━━━ $* ━━━${RESET}"; }

# ── Helper: matar proceso en puerto (Windows-safe via netstat + taskkill) ────
kill_port() {
  local PORT="$1"
  local PIDS
  PIDS=$(netstat -ano 2>/dev/null \
    | grep -E "[:.]${PORT}[[:space:]].*LISTENING" \
    | awk '{print $NF}' \
    | sort -u || true)
  if [[ -n "$PIDS" ]]; then
    while IFS= read -r PID; do
      [[ "$PID" =~ ^[0-9]+$ ]] || continue
      taskkill //PID "$PID" //F &>/dev/null 2>&1 || true
    done <<< "$PIDS"
  fi
}

# ── Limpieza al salir (Ctrl+C) ────────────────────────────────────────────────
BACK_PID=""
FRONT_PID=""

cleanup() {
  echo ""
  log_warn "Deteniendo procesos..."
  [[ -n "$BACK_PID"  ]] && kill "$BACK_PID"  2>/dev/null || true
  [[ -n "$FRONT_PID" ]] && kill "$FRONT_PID" 2>/dev/null || true
  log_info "Procesos detenidos. Los contenedores Docker siguen corriendo."
  log_info "Para detener Docker: docker compose --env-file docker/.env down"
  exit 0
}
trap cleanup SIGINT SIGTERM

# =============================================================================
# 1. Docker – contenedores
# =============================================================================
log_step "Docker – verificando contenedores"

if ! command -v docker &>/dev/null; then
  log_error "Docker no está instalado o no está en el PATH."
  exit 1
fi

cd "$SCRIPT_DIR"

# Detectar si ya están todos corriendo
RUNNING=$(docker compose --env-file "$DOCKER_ENV" ps --status running --format json 2>/dev/null \
  | python3 -c "import sys,json; data=sys.stdin.read(); rows=[json.loads(l) for l in data.splitlines() if l.strip()]; print(len(rows))" 2>/dev/null || echo "0")

if [[ "$RUNNING" -ge 5 ]]; then
  log_ok "Contenedores ya están corriendo ($RUNNING servicios activos)."
else
  log_info "Levantando contenedores Docker..."
  docker compose --env-file "$DOCKER_ENV" up -d 2>&1 | grep -v "^time=\|^warn\|level=warning" || true
fi

# Esperar a que db, auth y kong estén healthy
log_info "Esperando a que los servicios estén healthy..."
SERVICES=("task-manager-db-1" "task-manager-auth-1" "task-manager-kong-1")
TIMEOUT=120
ELAPSED=0

for SVC in "${SERVICES[@]}"; do
  log_info "  Esperando $SVC..."
  until [[ "$(docker inspect --format='{{.State.Health.Status}}' "$SVC" 2>/dev/null)" == "healthy" ]]; do
    sleep 3
    ELAPSED=$((ELAPSED + 3))
    if [[ $ELAPSED -ge $TIMEOUT ]]; then
      log_error "Timeout esperando $SVC. Revisa: docker compose logs $SVC"
      exit 1
    fi
  done
  log_ok "  $SVC healthy"
done

# Notificar a PostgREST que recargue el schema (por si arrancó antes de db-setup)
docker exec task-manager-db-1 psql -U postgres -c "NOTIFY pgrst, 'reload schema';" &>/dev/null || true

log_ok "Stack Docker listo."

# Si se pasó --docker, salir aquí
if [[ "${1:-}" == "--docker" ]]; then
  log_info "Modo --docker: solo contenedores. Saliendo."
  exit 0
fi

# =============================================================================
# 2. Backend – npm run dev
# =============================================================================
log_step "Backend – iniciando"

if [[ ! -d "$BACK_DIR/node_modules" ]]; then
  log_info "Instalando dependencias del backend..."
  (cd "$BACK_DIR" && npm install --silent)
fi

log_info "Lanzando backend en http://localhost:${BACK_PORT}"
kill_port "$BACK_PORT"
(cd "$BACK_DIR" && npm run dev 2>&1 | sed 's/^/  [back] /') &
BACK_PID=$!

# Esperar hasta que el backend responda
log_info "Esperando a que el backend esté listo..."
ELAPSED=0
until curl -sf "http://localhost:${BACK_PORT}/health" &>/dev/null; do
  sleep 2
  ELAPSED=$((ELAPSED + 2))
  if [[ $ELAPSED -ge 30 ]]; then
    log_error "Timeout esperando el backend."
    exit 1
  fi
done
log_ok "Backend listo en http://localhost:${BACK_PORT}"

# =============================================================================
# 3. Frontend – ng serve
# =============================================================================
log_step "Frontend – iniciando"

if [[ ! -d "$FRONT_DIR/node_modules" ]]; then
  log_info "Instalando dependencias del frontend..."
  (cd "$FRONT_DIR" && npm install --silent)
fi

log_info "Lanzando frontend en http://localhost:${FRONT_PORT}"
kill_port "$FRONT_PORT"
(cd "$FRONT_DIR" && npm start -- --port "$FRONT_PORT" 2>&1 | sed 's/^/  [front] /') &
FRONT_PID=$!

# Esperar hasta que Angular Compiler esté listo
log_info "Esperando a que el frontend compile..."
ELAPSED=0
until curl -sf "http://localhost:${FRONT_PORT}" &>/dev/null; do
  sleep 3
  ELAPSED=$((ELAPSED + 3))
  if [[ $ELAPSED -ge 120 ]]; then
    log_error "Timeout esperando el frontend."
    exit 1
  fi
done
log_ok "Frontend listo en http://localhost:${FRONT_PORT}"

# =============================================================================
# Resumen
# =============================================================================
echo ""
echo -e "${BOLD}${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${BOLD}${GREEN}  ✅  Task Manager está corriendo${RESET}"
echo -e "${BOLD}${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
printf "  ${CYAN}%-12s${RESET} →  http://localhost:%s\n" "Frontend"   "$FRONT_PORT"
printf "  ${CYAN}%-12s${RESET} →  http://localhost:%s\n" "Backend"    "$BACK_PORT"
printf "  ${CYAN}%-12s${RESET} →  http://localhost:%s\n" "Supabase"   "$SB_PORT"
printf "  ${CYAN}%-12s${RESET} →  http://localhost:%s\n" "Mailpit"    "$MAIL_PORT"
echo -e "${BOLD}${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""
log_info "Presiona Ctrl+C para detener el backend y el frontend."

# Mantener el script vivo y hacer forward de salida
wait $BACK_PID $FRONT_PID
