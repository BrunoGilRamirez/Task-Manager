#!/usr/bin/env bash
# =============================================================================
# config.sh – Genera / reconfigura el entorno de Task Manager
#
# Actualiza de forma sincronizada:
#   - docker/.env                                    (stack Docker local)
#   - back/task-manager/.env                         (backend Express)
#   - front/task-manager/src/app/core/environment.ts (Angular)
#   - front/task-manager/angular.json                (CSP connect-src)
#
# Uso:
#   bash config.sh [opciones]
#   bash config.sh --show
#   bash config.sh -h
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKER_ENV="$SCRIPT_DIR/docker/.env"
BACK_ENV="$SCRIPT_DIR/back/task-manager/.env"
FRONT_ENV_TS="$SCRIPT_DIR/front/task-manager/src/app/core/environment.ts"
ANGULAR_JSON="$SCRIPT_DIR/front/task-manager/angular.json"

RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[1;33m'
CYAN=$'\033[0;36m'; BOLD=$'\033[1m'; RESET=$'\033[0m'

log_info()  { echo -e "${CYAN}[INFO]${RESET}  $*"; }
log_ok()    { echo -e "${GREEN}[OK]${RESET}    $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
log_error() { echo -e "${RED}[ERROR]${RESET} $*" >&2; }
log_step()  { echo -e "\n${BOLD}━━━ $* ━━━${RESET}"; }

# =============================================================================
# Ayuda
# =============================================================================
usage() {
  cat <<EOF

${BOLD}config.sh${RESET} – Configura el stack de Task Manager

${BOLD}USO${RESET}
  bash config.sh [opciones]

${BOLD}PUERTOS${RESET}
  -fp  | --frontend-port    <N>    Puerto Angular dev server      (defecto: 4200)
  -bp  | --backend-port     <N>    Puerto Express API             (defecto: 3000)
  -sbp | --supabase-port    <N>    Puerto Kong / Supabase HTTP    (defecto: 5433)
  -dbp | --db-port          <N>    Puerto PostgreSQL              (defecto: 5432)
  -mp  | --mail-port        <N>    Puerto UI Mailpit              (defecto: 5435)

${BOLD}SEGURIDAD${RESET}
  -pp  | --postgres-password <val>  Contraseña de PostgreSQL
  -js  | --jwt-secret        <val>  JWT secret (≥ 32 chars)
                                    Regenera ANON_KEY y SERVICE_ROLE_KEY automáticamente

${BOLD}COMPORTAMIENTO${RESET}
  --no-signup                Deshabilita el registro de nuevos usuarios
  --signup                   Habilita el registro de nuevos usuarios
  --autoconfirm              Auto-confirma emails al registrarse (sin verificación)
  --no-autoconfirm           Requiere verificación de email

${BOLD}UTILIDADES${RESET}
  --init                     Crea los archivos de config faltantes con valores por defecto
                             (ideal tras un git clone; no sobreescribe archivos existentes)
  --reset-conf               Resetea toda la configuración a los valores por defecto
                             (sobreescribe archivos existentes; pide confirmación)
  -y  | --yes                Salta la confirmación en --reset-conf
  --show                     Muestra la configuración actual sin modificar nada
  -h  | --help               Muestra este mensaje

${BOLD}EJEMPLOS${RESET}
  bash config.sh --init                          # primer setup tras git clone
  bash config.sh --reset-conf                    # resetear toda la config
  bash config.sh --reset-conf -y                 # resetear sin confirmar
  bash config.sh -fp 2020 -bp 2333 -sbp 8080
  bash config.sh -pp "mi-nueva-contraseña-segura"
  bash config.sh -js "mi-jwt-secret-de-al-menos-32-caracteres"
  bash config.sh --no-signup --no-autoconfirm
  bash config.sh --show

${BOLD}ARCHIVOS ACTUALIZADOS${RESET}
  docker/.env
  back/task-manager/.env
  front/task-manager/src/app/core/environment.ts
  front/task-manager/angular.json  (CSP connect-src)

${BOLD}NOTA${RESET}
  Tras cambiar contraseñas o puertos Docker, reinicia el stack:
    bash stop.sh --prune && bash start.sh

  Para cambios solo de puertos de aplicación (backend / frontend):
    bash stop.sh && bash start.sh

EOF
}

# =============================================================================
# Helpers
# =============================================================================

# Lee una variable de un .env; retorna $default si el archivo no existe o la
# variable no está definida.
get_env_var() {
  local file="$1" key="$2" default="${3:-}"
  if [[ -f "$file" ]]; then
    local val
    val=$(grep -E "^${key}=" "$file" 2>/dev/null | head -1 | cut -d'=' -f2- || true)
    echo "${val:-$default}"
  else
    echo "$default"
  fi
}

# Establece / actualiza una variable en un archivo .env.
# Usa Python para manejar de forma segura valores con caracteres especiales.
set_env_var() {
  local file="$1" key="$2" value="$3"
  python3 - "$file" "$key" "$value" <<'PYEOF'
import sys, re, os

path, key, val = sys.argv[1], sys.argv[2], sys.argv[3]
os.makedirs(os.path.dirname(os.path.abspath(path)) or '.', exist_ok=True)

pattern = re.compile(r'^' + re.escape(key) + r'=.*$', re.MULTILINE)
replacement = key + '=' + val

if os.path.exists(path):
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()
    if pattern.search(content):
        content = pattern.sub(lambda _: replacement, content)
    else:
        content = content.rstrip('\n') + '\n' + replacement + '\n'
else:
    content = replacement + '\n'

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
PYEOF
}

# Genera ANON_KEY y SERVICE_ROLE_KEY a partir del JWT_SECRET con Node.js.
# Imprime dos líneas: primero anon_key, luego service_role_key.
generate_jwt_keys() {
  local secret="$1"
  node - "$secret" <<'JSEOF'
const crypto = require('crypto');
const secret = process.argv[2];

function makeJWT(payload) {
  const h = Buffer.from(JSON.stringify({ alg: 'HS256', typ: 'JWT' })).toString('base64url');
  const p = Buffer.from(JSON.stringify(payload)).toString('base64url');
  const sig = crypto.createHmac('sha256', secret).update(h + '.' + p).digest('base64url');
  return `${h}.${p}.${sig}`;
}

const exp = 1983812996; // ~2032 — suficiente para desarrollo local
console.log(makeJWT({ iss: 'supabase-demo', role: 'anon',         exp }));
console.log(makeJWT({ iss: 'supabase-demo', role: 'service_role', exp }));
JSEOF
}

# Actualiza supabaseUrl, supabaseKey y backendUrl en environment.ts.
# Solo toca líneas no comentadas (que empiezan con espacios, no con //).
update_env_ts() {
  local file="$1" sb_url="$2" anon_key="$3" back_url="$4"
  python3 - "$file" "$sb_url" "$anon_key" "$back_url" <<'PYEOF'
import sys, re

path, sb_url, anon_key, back_url = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]

with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# supabaseUrl — solo líneas no comentadas
# La línea activa es "  supabaseUrl: '...'," (precedida por \n + espacios)
# La línea comentada es "  // supabaseUrl: '...'," (tiene // entre los espacios y la clave)
def rep_sb_url(m):
    return m.group(1) + "supabaseUrl: '" + sb_url + "'"
content = re.sub(r'(\n[ \t]+)supabaseUrl:\s*\'[^\']*\'', rep_sb_url, content)

# supabaseKey — puede estar en formato de dos líneas:
#   supabaseKey:
#     'eyJ...',
# o en una sola línea.
ml_pat = re.compile(r'(\n[ \t]+)supabaseKey:\s*\n[ \t]+\'[^\']*\'')
if ml_pat.search(content):
    def rep_key_ml(m):
        return m.group(1) + "supabaseKey:\n    '" + anon_key + "'"
    content = ml_pat.sub(rep_key_ml, content)
else:
    def rep_key_sl(m):
        return m.group(1) + "supabaseKey: '" + anon_key + "'"
    content = re.sub(r'(\n[ \t]+)supabaseKey:\s*\'[^\']*\'', rep_key_sl, content)

# backendUrl
def rep_back(m):
    return m.group(1) + "backendUrl: '" + back_url + "'"
content = re.sub(r'(\n[ \t]+)backendUrl:\s*\'[^\']*\'', rep_back, content)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
PYEOF
}

# Actualiza los localhost URLs en el connect-src de angular.json.
# Reemplaza la URL anterior del backend y de supabase por las nuevas.
update_angular_csp() {
  local file="$1" old_bp="$2" new_bp="$3" old_sbp="$4" new_sbp="$5"
  python3 - "$file" "$old_bp" "$new_bp" "$old_sbp" "$new_sbp" <<'PYEOF'
import sys

path       = sys.argv[1]
old_bp_url = 'http://localhost:' + sys.argv[2]
new_bp_url = 'http://localhost:' + sys.argv[3]
old_sb_url = 'http://localhost:' + sys.argv[4]
new_sb_url = 'http://localhost:' + sys.argv[5]

with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace(old_bp_url, new_bp_url)
content = content.replace(old_sb_url, new_sb_url)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
PYEOF
}

# Muestra la configuración actual con valores enmascarados para secretos.
show_config() {
  local fp sbp dbp mp bp pp js anon srk ds ac

  fp=$(get_env_var  "$DOCKER_ENV" "FRONTEND_PORT"            "4200")
  sbp=$(get_env_var "$DOCKER_ENV" "KONG_HTTP_PORT"           "5433")
  dbp=$(get_env_var "$DOCKER_ENV" "POSTGRES_PORT"            "5432")
  mp=$(get_env_var  "$DOCKER_ENV" "MAILPIT_UI_PORT"          "5435")
  bp=$(get_env_var  "$BACK_ENV"   "PORT"                     "3000")
  pp=$(get_env_var  "$DOCKER_ENV" "POSTGRES_PASSWORD"        "(no configurado)")
  js=$(get_env_var  "$DOCKER_ENV" "JWT_SECRET"               "(no configurado)")
  anon=$(get_env_var "$DOCKER_ENV" "ANON_KEY"                "")
  srk=$(get_env_var  "$DOCKER_ENV" "SERVICE_ROLE_KEY"        "")
  ds=$(get_env_var  "$DOCKER_ENV" "DISABLE_SIGNUP"           "false")
  ac=$(get_env_var  "$DOCKER_ENV" "ENABLE_EMAIL_AUTOCONFIRM" "true")

  # Enmascara: muestra los 6 primeros y los 4 últimos chars
  mask() {
    local v="$1"
    local len="${#v}"
    if [[ $len -le 10 ]]; then
      echo "****"
    else
      echo "${v:0:6}...${v: -4}"
    fi
  }

  echo ""
  echo -e "${BOLD}━━━ Configuración Actual de Task Manager ━━━${RESET}"
  echo ""
  echo -e "${BOLD}  Puertos${RESET}"
  printf "    %-32s %s\n" "Frontend  (Angular dev server):" "$fp"
  printf "    %-32s %s\n" "Backend   (Express API):"        "$bp"
  printf "    %-32s %s\n" "Supabase  (Kong HTTP):"          "$sbp"
  printf "    %-32s %s\n" "PostgreSQL:"                     "$dbp"
  printf "    %-32s %s\n" "Mailpit UI:"                     "$mp"
  echo ""
  echo -e "${BOLD}  Seguridad${RESET}"
  printf "    %-32s %s\n" "Postgres password:"   "$(mask "$pp")"
  printf "    %-32s %s\n" "JWT secret:"          "$(mask "$js")"
  printf "    %-32s %s\n" "ANON_KEY:"            "$(mask "$anon")"
  printf "    %-32s %s\n" "SERVICE_ROLE_KEY:"    "$(mask "$srk")"
  echo ""
  echo -e "${BOLD}  Comportamiento${RESET}"
  printf "    %-32s %s\n" "DISABLE_SIGNUP:"           "$ds"
  printf "    %-32s %s\n" "ENABLE_EMAIL_AUTOCONFIRM:" "$ac"
  echo ""
}

# =============================================================================
# Valores por defecto del proyecto (estado inicial tras git clone)
# =============================================================================
readonly DEF_FP="4200"
readonly DEF_BP="3000"
readonly DEF_SBP="5433"
readonly DEF_SBPS="5434"
readonly DEF_DBP="5432"
readonly DEF_MP="5435"
readonly DEF_PP="your-super-secret-and-long-postgres-password"
readonly DEF_JS="your-super-secret-jwt-token-with-at-least-32-characters-long"
readonly DEF_ANON="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.b_lMH2mc5km7S9Lw_sRGGqE9IeiahYu-caevDcacKiY"
readonly DEF_SRK="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImV4cCI6MTk4MzgxMjk5Nn0.kcyKZAiwnnBG9t6IVGO17bcVw574pVynTHYVdF4q-p0"

# =============================================================================
# write_defaults – Escribe los archivos de configuración con valores por defecto
#
# mode="init"  → solo crea archivos que NO existen (no sobreescribe)
# mode="reset" → sobreescribe todos los archivos existentes o los crea
# =============================================================================
write_defaults() {
  local mode="$1"
  local created=0 skipped=0

  # En reset: capturar puertos actuales del angular.json ANTES de sobreescribir
  # (necesario para revertir el CSP a los puertos por defecto)
  local old_bp="$DEF_BP" old_sbp="$DEF_SBP"
  if [[ "$mode" == "reset" ]]; then
    old_bp=$( get_env_var "$BACK_ENV"    "PORT"           "$DEF_BP"  )
    old_sbp=$(get_env_var "$DOCKER_ENV"  "KONG_HTTP_PORT" "$DEF_SBP" )
  fi

  # ── docker/.env ──────────────────────────────────────────────────────────────
  if [[ "$mode" == "reset" ]] || [[ ! -f "$DOCKER_ENV" ]]; then
    mkdir -p "$(dirname "$DOCKER_ENV")"
    cat > "$DOCKER_ENV" <<'ENVEOF'
# =============================================================================
# Supabase Local Docker Stack – Variables de Entorno
# Generado por: bash config.sh --init
# Para reconfigurar: bash config.sh [opciones]
# =============================================================================

# ── PostgreSQL ──────────────────────────────────────────────────────────────
POSTGRES_PASSWORD=your-super-secret-and-long-postgres-password
POSTGRES_DB=postgres
POSTGRES_USER=postgres
POSTGRES_PORT=5432

# ── JWT ─────────────────────────────────────────────────────────────────────
# Mínimo 32 caracteres. No compartas este valor en producción.
JWT_SECRET=your-super-secret-jwt-token-with-at-least-32-characters-long
JWT_EXP=3600

# Claves JWT pre-generadas para el JWT_SECRET anterior.
ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.b_lMH2mc5km7S9Lw_sRGGqE9IeiahYu-caevDcacKiY
SERVICE_ROLE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImV4cCI6MTk4MzgxMjk5Nn0.kcyKZAiwnnBG9t6IVGO17bcVw574pVynTHYVdF4q-p0

# ── API / Kong ───────────────────────────────────────────────────────────────
KONG_HTTP_PORT=5433
KONG_HTTPS_PORT=5434
API_EXTERNAL_URL=http://localhost:5433

# ── Frontend (Angular) ───────────────────────────────────────────────────────
FRONTEND_PORT=4200
SITE_URL=http://localhost:4200
ADDITIONAL_REDIRECT_URLS=http://localhost:4200,http://localhost:4200/reset-password

# ── Email (Mailpit) ──────────────────────────────────────────────────────────
# Con ENABLE_EMAIL_AUTOCONFIRM=true los registros no necesitan verificar email.
ENABLE_EMAIL_AUTOCONFIRM=true
SMTP_HOST=mail
SMTP_PORT=1025
SMTP_USER=fake@example.com
SMTP_PASS=fake
SMTP_SENDER_NAME=Task Manager
MAILPIT_UI_PORT=5435

# ── Miscelánea ───────────────────────────────────────────────────────────────
DISABLE_SIGNUP=false
PGRST_DB_SCHEMAS=public
ENVEOF
    log_ok "docker/.env $( [[ "$mode" == "reset" ]] && echo "reseteado" || echo "creado" )."
    created=$((created + 1))
  else
    log_info "docker/.env ya existe — saltando. (usa --reset-conf para sobreescribir)"
    skipped=$((skipped + 1))
  fi

  # ── back/task-manager/.env ───────────────────────────────────────────────────
  if [[ "$mode" == "reset" ]] || [[ ! -f "$BACK_ENV" ]]; then
    mkdir -p "$(dirname "$BACK_ENV")"
    cat > "$BACK_ENV" <<'ENVEOF'
# Server
PORT=3000
NODE_ENV=development
CORS_ORIGIN=http://localhost:4200,http://127.0.0.1:4200

# Supabase – stack local de Docker
SUPABASE_URL=http://localhost:5433
SUPABASE_PUBLISHABLE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.b_lMH2mc5km7S9Lw_sRGGqE9IeiahYu-caevDcacKiY

FRONTEND_RESET_PASSWORD_URL=http://localhost:4200/reset-password
ENVEOF
    log_ok "back/task-manager/.env $( [[ "$mode" == "reset" ]] && echo "reseteado" || echo "creado" )."
    created=$((created + 1))
  else
    log_info "back/task-manager/.env ya existe — saltando. (usa --reset-conf para sobreescribir)"
    skipped=$((skipped + 1))
  fi

  # ── front/.../environment.ts ─────────────────────────────────────────────────
  if [[ "$mode" == "reset" ]] || [[ ! -f "$FRONT_ENV_TS" ]]; then
    mkdir -p "$(dirname "$FRONT_ENV_TS")"
    cat > "$FRONT_ENV_TS" <<'TSEOF'
export const environment = {
  production: false,
  // Supabase – stack local de Docker
  supabaseUrl: 'http://localhost:5433',
  supabaseKey:
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.b_lMH2mc5km7S9Lw_sRGGqE9IeiahYu-caevDcacKiY',
  backendUrl: 'http://localhost:3000',
};
TSEOF
    log_ok "environment.ts $( [[ "$mode" == "reset" ]] && echo "reseteado" || echo "creado" )."
    created=$((created + 1))
  else
    log_info "environment.ts ya existe — saltando. (usa --reset-conf para sobreescribir)"
    skipped=$((skipped + 1))
  fi

  # ── angular.json CSP — solo en reset (en init está en git con valores por defecto) ─
  if [[ "$mode" == "reset" ]] && [[ -f "$ANGULAR_JSON" ]]; then
    update_angular_csp "$ANGULAR_JSON" "$old_bp" "$DEF_BP" "$old_sbp" "$DEF_SBP"
    log_ok "angular.json CSP reseteado a puertos por defecto."
  fi

  # ── Resumen ──────────────────────────────────────────────────────────────────
  echo ""
  if [[ "$mode" == "init" ]]; then
    echo -e "${BOLD}${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${BOLD}${GREEN}  ✅  Entorno inicializado${RESET}"
    echo -e "${BOLD}${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    printf "  ${CYAN}%-12s${RESET} →  http://localhost:%s\n" "Frontend"   "$DEF_FP"
    printf "  ${CYAN}%-12s${RESET} →  http://localhost:%s\n" "Backend"    "$DEF_BP"
    printf "  ${CYAN}%-12s${RESET} →  http://localhost:%s\n" "Supabase"   "$DEF_SBP"
    printf "  ${CYAN}%-12s${RESET} →  localhost:%s\n"        "PostgreSQL" "$DEF_DBP"
    printf "  ${CYAN}%-12s${RESET} →  http://localhost:%s\n" "Mailpit"    "$DEF_MP"
    echo -e "${BOLD}${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    [[ $skipped -gt 0 ]] && log_warn "$skipped archivo(s) ya existían y no se modificaron."
    echo ""
    log_info "Para personalizar la configuración: bash config.sh --help"
    log_info "Para levantar el stack:             bash start.sh"
  else
    echo -e "${BOLD}${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${BOLD}${GREEN}  ✅  Configuración reseteada a valores por defecto${RESET}"
    echo -e "${BOLD}${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    printf "  ${CYAN}%-12s${RESET} →  http://localhost:%s\n" "Frontend"   "$DEF_FP"
    printf "  ${CYAN}%-12s${RESET} →  http://localhost:%s\n" "Backend"    "$DEF_BP"
    printf "  ${CYAN}%-12s${RESET} →  http://localhost:%s\n" "Supabase"   "$DEF_SBP"
    printf "  ${CYAN}%-12s${RESET} →  localhost:%s\n"        "PostgreSQL" "$DEF_DBP"
    printf "  ${CYAN}%-12s${RESET} →  http://localhost:%s\n" "Mailpit"    "$DEF_MP"
    echo -e "${BOLD}${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""
    log_warn "Si el stack estaba corriendo, reinicia con:"
    echo -e "  ${BOLD}bash stop.sh --prune && bash start.sh${RESET}"
  fi
  echo ""
}

# =============================================================================
# Parseo de argumentos
# =============================================================================
NEW_FP="" NEW_BP="" NEW_SBP="" NEW_DBP="" NEW_MP=""
NEW_PP="" NEW_JS=""
NEW_DS="" NEW_AC=""
MODE="config"
YES_FLAG=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    -fp  | --frontend-port)     NEW_FP="$2";  shift 2 ;;
    -bp  | --backend-port)      NEW_BP="$2";  shift 2 ;;
    -sbp | --supabase-port)     NEW_SBP="$2"; shift 2 ;;
    -dbp | --db-port)           NEW_DBP="$2"; shift 2 ;;
    -mp  | --mail-port)         NEW_MP="$2";  shift 2 ;;
    -pp  | --postgres-password) NEW_PP="$2";  shift 2 ;;
    -js  | --jwt-secret)        NEW_JS="$2";  shift 2 ;;
    --no-signup)                NEW_DS="true";       shift ;;
    --signup)                   NEW_DS="false";      shift ;;
    --autoconfirm)              NEW_AC="true";       shift ;;
    --no-autoconfirm)           NEW_AC="false";      shift ;;
    --show)                     MODE="show";         shift ;;
    --init)                     MODE="init";         shift ;;
    --reset-conf)               MODE="reset-conf";   shift ;;
    -y | --yes)                 YES_FLAG=true;       shift ;;
    -h | --help)                usage; exit 0 ;;
    *) log_error "Opción desconocida: $1"; usage; exit 1 ;;
  esac
done

# ── Modo --show: solo mostrar, sin cambios ────────────────────────────────────
if [[ "$MODE" == "show" ]]; then
  show_config
  exit 0
fi

# ── Modo --init: crear archivos faltantes con valores por defecto ─────────────
if [[ "$MODE" == "init" ]]; then
  log_step "Inicializando entorno"
  write_defaults "init"
  exit 0
fi

# ── Modo --reset-conf: sobreescribir todo con valores por defecto ─────────────
if [[ "$MODE" == "reset-conf" ]]; then
  if [[ "$YES_FLAG" != "true" ]]; then
    echo ""
    log_warn "Esto sobreescribirá toda la configuración personalizada con los valores por defecto."
    printf "  ¿Continuar? [y/N] "
    read -r CONFIRM
    if [[ "${CONFIRM,,}" != "y" ]]; then
      log_info "Operación cancelada."
      exit 0
    fi
  fi
  log_step "Reseteando configuración a valores por defecto"
  write_defaults "reset"
  exit 0
fi

# ── Sin argumentos: mostrar config actual + ayuda ────────────────────────────
if [[ -z "$NEW_FP$NEW_BP$NEW_SBP$NEW_DBP$NEW_MP$NEW_PP$NEW_JS$NEW_DS$NEW_AC" ]]; then
  show_config
  usage
  exit 0
fi

# =============================================================================
# Leer valores actuales desde los archivos de configuración
# =============================================================================
CURR_FP=$(get_env_var  "$DOCKER_ENV" "FRONTEND_PORT"            "4200")
CURR_SBP=$(get_env_var "$DOCKER_ENV" "KONG_HTTP_PORT"           "5433")
CURR_DBP=$(get_env_var "$DOCKER_ENV" "POSTGRES_PORT"            "5432")
CURR_MP=$(get_env_var  "$DOCKER_ENV" "MAILPIT_UI_PORT"          "5435")
CURR_BP=$(get_env_var  "$BACK_ENV"   "PORT"                     "3000")
CURR_PP=$(get_env_var  "$DOCKER_ENV" "POSTGRES_PASSWORD"        "your-super-secret-and-long-postgres-password")
CURR_JS=$(get_env_var  "$DOCKER_ENV" "JWT_SECRET"               "your-super-secret-jwt-token-with-at-least-32-characters-long")
CURR_ANON=$(get_env_var "$DOCKER_ENV" "ANON_KEY"                "")
CURR_SRK=$(get_env_var  "$DOCKER_ENV" "SERVICE_ROLE_KEY"        "")
CURR_DS=$(get_env_var  "$DOCKER_ENV" "DISABLE_SIGNUP"           "false")
CURR_AC=$(get_env_var  "$DOCKER_ENV" "ENABLE_EMAIL_AUTOCONFIRM" "true")

# Aplicar overrides: usar el nuevo valor si fue proporcionado, sino el actual
FINAL_FP="${NEW_FP:-$CURR_FP}"
FINAL_BP="${NEW_BP:-$CURR_BP}"
FINAL_SBP="${NEW_SBP:-$CURR_SBP}"
FINAL_DBP="${NEW_DBP:-$CURR_DBP}"
FINAL_MP="${NEW_MP:-$CURR_MP}"
FINAL_PP="${NEW_PP:-$CURR_PP}"
FINAL_JS="${NEW_JS:-$CURR_JS}"
FINAL_DS="${NEW_DS:-$CURR_DS}"
FINAL_AC="${NEW_AC:-$CURR_AC}"

# =============================================================================
# Validaciones
# =============================================================================
log_step "Validando parámetros"

# Puertos deben ser enteros en el rango 1024–65535
for VAR in FINAL_FP FINAL_BP FINAL_SBP FINAL_DBP FINAL_MP; do
  PORT_VAL="${!VAR}"
  if ! [[ "$PORT_VAL" =~ ^[0-9]+$ ]] || \
     [[ "$PORT_VAL" -lt 1024 ]] || \
     [[ "$PORT_VAL" -gt 65535 ]]; then
    log_error "$VAR tiene un valor inválido: '$PORT_VAL' (debe ser un entero 1024–65535)"
    exit 1
  fi
done

# JWT secret debe tener al menos 32 caracteres
if [[ "${#FINAL_JS}" -lt 32 ]]; then
  log_error "JWT secret demasiado corto (${#FINAL_JS} chars). Se requieren al menos 32 caracteres."
  exit 1
fi

# Avisar si los puertos no son todos distintos (puede ser intencional, pero es raro)
PORTS=("$FINAL_FP" "$FINAL_BP" "$FINAL_SBP" "$FINAL_DBP" "$FINAL_MP")
UNIQUE_PORTS=$(printf '%s\n' "${PORTS[@]}" | sort -u | wc -l)
if [[ "$UNIQUE_PORTS" -lt "${#PORTS[@]}" ]]; then
  log_warn "Dos o más puertos tienen el mismo valor. Asegúrate de que sea intencional."
fi

log_ok "Parámetros válidos."

# =============================================================================
# Regenerar JWT keys si el secret cambió
# =============================================================================
FINAL_ANON="$CURR_ANON"
FINAL_SRK="$CURR_SRK"

if [[ "$FINAL_JS" != "$CURR_JS" ]]; then
  log_step "Regenerando JWT keys"
  if ! command -v node &>/dev/null; then
    log_error "Node.js no está instalado. Es necesario para generar JWT keys."
    exit 1
  fi
  JWT_OUTPUT=$(generate_jwt_keys "$FINAL_JS")
  FINAL_ANON=$(echo "$JWT_OUTPUT" | head -1)
  FINAL_SRK=$(echo "$JWT_OUTPUT"  | tail -1)
  log_ok "ANON_KEY y SERVICE_ROLE_KEY regenerados."
fi

# =============================================================================
# Actualizar docker/.env
# =============================================================================
log_step "Actualizando docker/.env"

set_env_var "$DOCKER_ENV" "FRONTEND_PORT"            "$FINAL_FP"
set_env_var "$DOCKER_ENV" "KONG_HTTP_PORT"            "$FINAL_SBP"
set_env_var "$DOCKER_ENV" "KONG_HTTPS_PORT"           "$((FINAL_SBP + 1))"
set_env_var "$DOCKER_ENV" "POSTGRES_PORT"             "$FINAL_DBP"
set_env_var "$DOCKER_ENV" "MAILPIT_UI_PORT"           "$FINAL_MP"
set_env_var "$DOCKER_ENV" "POSTGRES_PASSWORD"         "$FINAL_PP"
set_env_var "$DOCKER_ENV" "JWT_SECRET"                "$FINAL_JS"
set_env_var "$DOCKER_ENV" "ANON_KEY"                  "$FINAL_ANON"
set_env_var "$DOCKER_ENV" "SERVICE_ROLE_KEY"          "$FINAL_SRK"
set_env_var "$DOCKER_ENV" "API_EXTERNAL_URL"          "http://localhost:${FINAL_SBP}"
set_env_var "$DOCKER_ENV" "SITE_URL"                  "http://localhost:${FINAL_FP}"
set_env_var "$DOCKER_ENV" "ADDITIONAL_REDIRECT_URLS"  "http://localhost:${FINAL_FP},http://localhost:${FINAL_FP}/reset-password"
set_env_var "$DOCKER_ENV" "DISABLE_SIGNUP"            "$FINAL_DS"
set_env_var "$DOCKER_ENV" "ENABLE_EMAIL_AUTOCONFIRM"  "$FINAL_AC"

log_ok "docker/.env actualizado."

# =============================================================================
# Actualizar back/task-manager/.env
# =============================================================================
log_step "Actualizando back/task-manager/.env"

set_env_var "$BACK_ENV" "PORT"                       "$FINAL_BP"
set_env_var "$BACK_ENV" "CORS_ORIGIN"                "http://localhost:${FINAL_FP},http://127.0.0.1:${FINAL_FP}"
set_env_var "$BACK_ENV" "SUPABASE_URL"               "http://localhost:${FINAL_SBP}"
set_env_var "$BACK_ENV" "SUPABASE_PUBLISHABLE_KEY"   "$FINAL_ANON"
set_env_var "$BACK_ENV" "FRONTEND_RESET_PASSWORD_URL" "http://localhost:${FINAL_FP}/reset-password"

log_ok "back/task-manager/.env actualizado."

# =============================================================================
# Actualizar front/task-manager/src/app/core/environment.ts
# =============================================================================
log_step "Actualizando environment.ts"

if [[ -f "$FRONT_ENV_TS" ]]; then
  update_env_ts "$FRONT_ENV_TS" \
    "http://localhost:${FINAL_SBP}" \
    "$FINAL_ANON" \
    "http://localhost:${FINAL_BP}"
  log_ok "environment.ts actualizado."
else
  log_warn "No se encontró $FRONT_ENV_TS — saltando."
fi

# =============================================================================
# Actualizar front/task-manager/angular.json (CSP connect-src)
# =============================================================================
log_step "Actualizando angular.json (CSP connect-src)"

if [[ -f "$ANGULAR_JSON" ]]; then
  update_angular_csp "$ANGULAR_JSON" \
    "$CURR_BP"  "$FINAL_BP" \
    "$CURR_SBP" "$FINAL_SBP"
  log_ok "angular.json actualizado."
else
  log_warn "No se encontró $ANGULAR_JSON — saltando."
fi

# =============================================================================
# Resumen de cambios
# =============================================================================
echo ""
echo -e "${BOLD}${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${BOLD}${GREEN}  ✅  Configuración actualizada${RESET}"
echo -e "${BOLD}${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
printf "  ${CYAN}%-12s${RESET} →  http://localhost:%s\n" "Frontend"  "$FINAL_FP"
printf "  ${CYAN}%-12s${RESET} →  http://localhost:%s\n" "Backend"   "$FINAL_BP"
printf "  ${CYAN}%-12s${RESET} →  http://localhost:%s\n" "Supabase"  "$FINAL_SBP"
printf "  ${CYAN}%-12s${RESET} →  localhost:%s\n"        "PostgreSQL" "$FINAL_DBP"
printf "  ${CYAN}%-12s${RESET} →  http://localhost:%s\n" "Mailpit"   "$FINAL_MP"
echo -e "${BOLD}${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""

# Indicar qué tipo de reinicio es necesario
NEEDS_PRUNE=false
NEEDS_RESTART=false

[[ "$FINAL_PP"  != "$CURR_PP"  ]] && NEEDS_PRUNE=true
[[ "$FINAL_JS"  != "$CURR_JS"  ]] && NEEDS_PRUNE=true
[[ "$FINAL_SBP" != "$CURR_SBP" ]] && NEEDS_PRUNE=true
[[ "$FINAL_DBP" != "$CURR_DBP" ]] && NEEDS_PRUNE=true

[[ "$FINAL_FP"  != "$CURR_FP"  ]] && NEEDS_RESTART=true
[[ "$FINAL_BP"  != "$CURR_BP"  ]] && NEEDS_RESTART=true
[[ "$FINAL_DS"  != "$CURR_DS"  ]] && NEEDS_RESTART=true
[[ "$FINAL_AC"  != "$CURR_AC"  ]] && NEEDS_RESTART=true

if [[ "$NEEDS_PRUNE" == "true" ]]; then
  log_warn "Hay cambios en la DB, puertos Docker o JWT. Reinicia con:"
  echo -e "  ${BOLD}bash stop.sh --prune && bash start.sh${RESET}"
elif [[ "$NEEDS_RESTART" == "true" ]]; then
  log_info "Para aplicar los cambios, reinicia el stack:"
  echo -e "  ${BOLD}bash stop.sh && bash start.sh${RESET}"
fi
echo ""
