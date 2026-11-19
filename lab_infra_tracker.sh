#!/usr/bin/env bash
set -euo pipefail

WORKDIR="${HOME}/.lab_infra_6ghz_fiber_sat"
FIBER_DB="${WORKDIR}/fiber_restoration.json"
SAT_CACHE="${WORKDIR}/celestrak_active.tle"

mkdir -p "${WORKDIR}"

init_fiber_db() {
  if [[ ! -f "${FIBER_DB}" ]]; then
    cat <<'EOF' > "${FIBER_DB}"
[
  {
    "building": "Edificio Norte - Torre A",
    "segment": "Riser PB -> Piso 8",
    "fiber_count": 24,
    "status": "EN_EMPALME",
    "loss_db_target": 0.35,
    "notes": "Fusionando bandeja 2 y validando con OTDR"
  },
  {
    "building": "Edificio Sur - Acceso Principal",
    "segment": "Pozo Externo -> ODF Principal",
    "fiber_count": 48,
    "status": "RESTAURADO",
    "loss_db_target": 0.25,
    "notes": "Continuidad verificada y etiqueta actualizada"
  }
]
EOF
  fi
}

check_6ghz_operator() {
  local operator_label="${1:-OPERADOR-6GHZ-LAB}"
  echo "=== [1] OPERADOR Y ESPECTRO 6 GHz (${operator_label}) ==="
  date -Iseconds

  if command -v ip >/dev/null 2>&1; then
    echo "--- Interfaces de red ---"
    ip -br link || true
  fi

  if command -v iw >/dev/null 2>&1; then
    echo "--- Capacidades / Frecuencias (iw phy) ---"
    iw phy 2>/dev/null | grep -E "Wiphy|Frequencies|59[0-9]{2}\.0 MHz|6[0-9]{3}\.0 MHz" | head -n 30 || true
    echo "--- Interfaces activas (iw dev) ---"
    iw dev 2>/dev/null || true
  else
    echo "Nota: 'iw' no está instalado en este entorno."
  fi
}

fiber_status() {
  init_fiber_db
  echo "=== [2] PROYECTO DE RESTAURACIÓN DE FIBRA ÓPTICA EN EDIFICIOS ==="
  cat "${FIBER_DB}"
}

fiber_update() {
  local building="${1:?Uso: $0 fiber-update \"<Edificio>\" \"<Segmento>\" <ESTADO> <PERDIDA_DB> \"<Notas>\"}"
  local segment="${2:?Falta segmento}"
  local status="${3:?Falta estado (PENDIENTE|EN_EMPALME|PRUEBAS|RESTAURADO)}"
  local loss_db="${4:?Falta pérdida estimada/medida en dB}"
  local notes="${5:-Sin observaciones}"

  init_fiber_db

  if command -v python3 >/dev/null 2>&1; then
    python3 - "${FIBER_DB}" "${building}" "${segment}" "${status}" "${loss_db}" "${notes}" <<'PY'
import json, sys

db_path, building, segment, status, loss_db, notes = sys.argv[1:]
with open(db_path, "r", encoding="utf-8") as f:
    data = json.load(f)

updated = False
for item in data:
    if item.get("building") == building and item.get("segment") == segment:
        item["status"] = status
        item["loss_db_target"] = float(loss_db)
        item["notes"] = notes
        updated = True
        break

if not updated:
    data.append({
        "building": building,
        "segment": segment,
        "fiber_count": 24,
        "status": status,
        "loss_db_target": float(loss_db),
        "notes": notes
    })

with open(db_path, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
    f.write("\n")

print(f"Registro actualizado: {building} | {segment} -> {status}")
PY
  else
    echo "Se requiere python3 para actualizar ${FIBER_DB} de forma segura." >&2
    exit 1
  fi
}

check_satellites() {
  local filter_term="${1:-STARLINK}"
  echo "=== [3] SATÉLITES / TLE (Filtro: ${filter_term}) ==="

  if command -v curl >/dev/null 2>&1; then
    if curl -fsSL --max-time 8 "https://celestrak.org/NORAD/elements/gp.php?GROUP=active&FORMAT=tle" -o "${SAT_CACHE}.tmp" 2>/dev/null && [[ -s "${SAT_CACHE}.tmp" ]]; then
      mv "${SAT_CACHE}.tmp" "${SAT_CACHE}"
      echo "Caché TLE actualizada en: ${SAT_CACHE}"
    else
      rm -f "${SAT_CACHE}.tmp"
      echo "Sin acceso directo a CelesTrak o tiempo agotado; usando caché local si existe."
    fi
  fi

  if [[ -f "${SAT_CACHE}" ]]; then
    grep -i -A 2 -- "${filter_term}" "${SAT_CACHE}" | head -n 18 || echo "Sin coincidencias para '${filter_term}'."
  else
    echo "No hay archivo TLE local todavía."
  fi
}

usage() {
  cat <<EOF
Uso: $0 <comando> [argumentos]

Comandos:
  6ghz [NOMBRE_OPERADOR]                 Inspecciona red/frecuencias y muestra perfil 6 GHz
  fiber-list                             Lista el estado de restauración de fibra por edificio
  fiber-update "Edif" "Tram" EST DB "Nota" Agrega o actualiza un tramo de fibra óptica
  sat [FILTRO]                           Consulta/filtra TLE de satélites activos (ej. STARLINK, ONEWEB, IRIDIUM)
  all [NOMBRE_OPERADOR] [FILTRO_SAT]     Ejecuta los tres módulos en secuencia
EOF
}

cmd="${1:-all}"
case "${cmd}" in
  6ghz)
    check_6ghz_operator "${2:-OPERADOR-6GHZ-LAB}"
    ;;
  fiber-list)
    fiber_status
    ;;
  fiber-update)
    shift
    fiber_update "$@"
    ;;
  sat)
    check_satellites "${2:-STARLINK}"
    ;;
  all)
    op="${2:-OPERADOR-6GHZ-LAB}"
    sat_filter="${3:-STARLINK}"
    check_6ghz_operator "${op}"
    echo ""
    fiber_status
    echo ""
    check_satellites "${sat_filter}"
    ;;
  -h|--help|help)
    usage
    ;;
  *)
    usage
    exit 1
    ;;
esac
cat <<'EOF' > ~/lab_infra_tracker.sh
# (pega aquí el contenido del script)
EOF
chmod +x ~/lab_infra_tracker.sh

~/lab_infra_tracker.sh all "RED-6GHZ-TEST" "STARLINK"
~/lab_infra_tracker.sh fiber-update "Edificio Poniente" "Vertical Piso 1 -> Piso 6" "PRUEBAS" "0.28" "Atenuación dentro de margen"
