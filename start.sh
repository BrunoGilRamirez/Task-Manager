#!/usr/bin/env bash
# =============================================================================
# start.sh – Start the full Task Manager stack
#
# Usage:
#   bash start.sh          # bring up Docker + backend + frontend
#   bash start.sh --docker # only bring up / verify Docker containers
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKER_ENV="$SCRIPT_DIR/docker/.env"
BACK_DIR="$SCRIPT_DIR/back/task-manager"
FRONT_DIR="$SCRIPT_DIR/front/task-manager"

# ── Read ports from config (with fallback to defaults) ───────────────────────
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

# ── Colors ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

log_info()  { echo -e "${CYAN}[INFO]${RESET}  $*"; }
log_ok()    { echo -e "${GREEN}[OK]${RESET}    $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
log_error() { echo -e "${RED}[ERROR]${RESET} $*"; }
log_step()  { echo -e "\n${BOLD}━━━ $* ━━━${RESET}"; }

# ── Helper: kill process on a port (Windows-safe via netstat + taskkill) ────
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

# ── Cleanup on exit (Ctrl+C) ────────────────────────────────────────────────
BACK_PID=""
FRONT_PID=""

cleanup() {
  echo ""
  log_warn "Stopping processes..."
  [[ -n "$BACK_PID"  ]] && kill "$BACK_PID"  2>/dev/null || true
  [[ -n "$FRONT_PID" ]] && kill "$FRONT_PID" 2>/dev/null || true
  log_info "Processes stopped. Docker containers are still running."
  log_info "To stop Docker containers: docker compose --env-file docker/.env down"
  exit 0
}
trap cleanup SIGINT SIGTERM

# =============================================================================
# 1. Docker – containers
# =============================================================================
log_step "Docker – checking containers"

if ! command -v docker &>/dev/null; then
  log_error "Docker is not installed or not available in PATH."
  exit 1
fi

cd "$SCRIPT_DIR"

# Detect if services are already running
RUNNING=$(docker compose --env-file "$DOCKER_ENV" ps --status running --format json 2>/dev/null \
  | python3 -c "import sys,json; data=sys.stdin.read(); rows=[json.loads(l) for l in data.splitlines() if l.strip()]; print(len(rows))" 2>/dev/null || echo "0")

if [[ "$RUNNING" -ge 5 ]]; then
  log_ok "Containers are already running ($RUNNING services active)."
else
  log_info "Bringing up Docker containers..."
  docker compose --env-file "$DOCKER_ENV" up -d 2>&1 | grep -v "^time=\|^warn\|level=warning" || true
fi

# Wait for db, auth and kong to become healthy
log_info "Waiting for services to become healthy..."
SERVICES=("task-manager-db-1" "task-manager-auth-1" "task-manager-kong-1")
TIMEOUT=120
ELAPSED=0

for SVC in "${SERVICES[@]}"; do
  log_info "  Waiting for $SVC..."
  until [[ "$(docker inspect --format='{{.State.Health.Status}}' "$SVC" 2>/dev/null)" == "healthy" ]]; do
    sleep 3
    ELAPSED=$((ELAPSED + 3))
    if [[ $ELAPSED -ge $TIMEOUT ]]; then
      log_error "Timeout waiting for $SVC. Check: docker compose logs $SVC"
      exit 1
    fi
  done
  log_ok "  $SVC healthy"
done

# Notify PostgREST to reload the schema (if it started before db-setup)
docker exec task-manager-db-1 psql -U postgres -c "NOTIFY pgrst, 'reload schema';" &>/dev/null || true

log_ok "Docker stack ready."

# If --docker was passed, exit here
if [[ "${1:-}" == "--docker" ]]; then
  log_info "--docker mode: containers only. Exiting."
  exit 0
fi

# =============================================================================
# 2. Backend – npm run dev
# =============================================================================
log_step "Backend – starting"

if [[ ! -d "$BACK_DIR/node_modules" ]]; then
  log_info "Installing backend dependencies..."
  (cd "$BACK_DIR" && npm install --silent)
fi

log_info "Starting backend at http://localhost:${BACK_PORT}"
kill_port "$BACK_PORT"
(cd "$BACK_DIR" && npm run dev 2>&1 | sed 's/^/  [back] /') &
BACK_PID=$!

# Wait until the backend responds
log_info "Waiting for backend to be ready..."
ELAPSED=0
until curl -sf "http://localhost:${BACK_PORT}/health" &>/dev/null; do
  sleep 2
  ELAPSED=$((ELAPSED + 2))
  if [[ $ELAPSED -ge 30 ]]; then
    log_error "Timeout waiting for backend."
    exit 1
  fi
done
log_ok "Backend ready at http://localhost:${BACK_PORT}"

# =============================================================================
# 3. Frontend – ng serve
# =============================================================================
log_step "Frontend – starting"

if [[ ! -d "$FRONT_DIR/node_modules" ]]; then
  log_info "Installing frontend dependencies..."
  (cd "$FRONT_DIR" && npm install --silent)
fi

log_info "Starting frontend at http://localhost:${FRONT_PORT}"
kill_port "$FRONT_PORT"
(cd "$FRONT_DIR" && npm start -- --port "$FRONT_PORT" 2>&1 | sed 's/^/  [front] /') &
FRONT_PID=$!

# Wait until the Angular compiler is ready
log_info "Waiting for frontend to compile..."
ELAPSED=0
until curl -sf "http://localhost:${FRONT_PORT}" &>/dev/null; do
  sleep 3
  ELAPSED=$((ELAPSED + 3))
  if [[ $ELAPSED -ge 120 ]]; then
    log_error "Timeout waiting for frontend."
    exit 1
  fi
done
log_ok "Frontend ready at http://localhost:${FRONT_PORT}"

# =============================================================================
# Summary
# =============================================================================
echo ""
echo -e "${BOLD}${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  echo -e "${BOLD}${GREEN}  ✅  Task Manager is running${RESET}"
echo -e "${BOLD}${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
printf "  ${CYAN}%-12s${RESET} →  http://localhost:%s\n" "Frontend"   "$FRONT_PORT"
printf "  ${CYAN}%-12s${RESET} →  http://localhost:%s\n" "Backend"    "$BACK_PORT"
printf "  ${CYAN}%-12s${RESET} →  http://localhost:%s\n" "Supabase"   "$SB_PORT"
printf "  ${CYAN}%-12s${RESET} →  http://localhost:%s\n" "Mailpit"    "$MAIL_PORT"
echo -e "${BOLD}${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""
log_info "Press Ctrl+C to stop the backend and frontend."

# Keep the script alive and forward output
wait $BACK_PID $FRONT_PID
