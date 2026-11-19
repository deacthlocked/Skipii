#!/usr/bin/env bash
set -euo pipefail

WORKDIR="${HOME}/.lab_monerod_ev"
LOG_DIR="${WORKDIR}/logs"
EV_LOG="${WORKDIR}/ev_telemetry_events.jsonl"
MONEROD_BIN="${MONEROD_BIN:-monerod}"
RPC_HOST="${RPC_HOST:-127.0.0.1}"
RPC_PORT="${RPC_PORT:-18081}"

mkdir -p "${WORKDIR}" "${LOG_DIR}"

init_ev_log() {
  if [[ ! -f "${EV_LOG}" ]]; then
    cat <<'EOF' > "${EV_LOG}"
{"ts":"2026-11-19T00:00:00Z","unit":"EV-01","soc_pct":84,"pack_v":396.4,"bus":"CAN0","note":"Inicializacion de registro local"}
EOF
  fi
}

check_monerod_bin() {
  if ! command -v "${MONEROD_BIN}" >/dev/null 2>&1; then
    echo "Aviso: '${MONEROD_BIN}' no encontrado en PATH. Ajusta MONEROD_BIN o la ruta del binario." >&2
    return 1
  fi
  return 0
}

rpc_get() {
  local path="$1"
  if command -v curl >/dev/null 2>&1; then
    curl -fsS --max-time 4 "http://${RPC_HOST}:${RPC_PORT}/${path}" 2>/dev/null || return 1
  else
    echo "Error: se requiere 'curl' para consultar http://${RPC_HOST}:${RPC_PORT}/${path}" >&2
    return 1
  fi
}

rpc_json_method() {
  local method="$1"
  if command -v curl >/dev/null 2>&1; then
    curl -fsS --max-time 4 \
      -H "Content-Type: application/json" \
      -d "{\"jsonrpc\":\"2.0\",\"id\":\"0\",\"method\":\"${method}\"}" \
      "http://${RPC_HOST}:${RPC_PORT}/json_rpc" 2>/dev/null || return 1
  else
    echo "Error: se requiere 'curl' para invocar '${method}'." >&2
    return 1
  fi
}

monerod_status() {
  echo "=== [MONEROD] ESTADO RPC (${RPC_HOST}:${RPC_PORT}) ==="
  if pgrep -x "monerod" >/dev/null 2>&1; then
    echo "Proceso local: ACTIVO (PIDs: $(pgrep -x monerod | tr '\n' ' '))"
  else
    echo "Proceso local: no detectado en este espacio de nombres/host."
  fi

  if info_out="$(rpc_json_method "get_info")"; then
    echo "${info_out}"
  else
    echo "RPC no disponible en http://${RPC_HOST}:${RPC_PORT} (verifica si monerod está corriendo o el puerto/red)."
  fi
}

monerod_start() {
  local net_flag="${1:---stagenet}"
  local extra_args=()
  case "${net_flag}" in
    --stagenet|--testnet|--mainnet)
      if [[ "${net_flag}" != "--mainnet" ]]; then
        extra_args+=("${net_flag}")
      fi
      ;;
    *)
      extra_args+=("${net_flag}")
      ;;
  esac

  check_monerod_bin || return 1
  local log_file="${LOG_DIR}/monerod_$(date +%Y%m%d_%H%M%S).log"
  echo "Iniciando ${MONEROD_BIN} (${net_flag}) -> log: ${log_file}"
  nohup "${MONEROD_BIN}" \
    "${extra_args[@]}" \
    --data-dir="${WORKDIR}/bitmonero" \
    --log-file="${log_file}" \
    --non-interactive \
    >/dev/null 2>&1 &
  sleep 2
  monerod_status
}

monerod_stop() {
  if command -v "${MONEROD_BIN}" >/dev/null 2>&1; then
    "${MONEROD_BIN}" --rpc-bind-ip="${RPC_HOST}" --rpc-bind-port="${RPC_PORT}" exit 2>/dev/null || true
  fi
  if pgrep -x "monerod" >/dev/null 2>&1; then
    pkill -x "monerod" || true
  fi
  echo "Solicitud de detención de monerod enviada."
}

ev_record() {
  local unit="${1:?Uso: $0 ev-record <UNIDAD> <SOC_PCT> <PACK_V> <BUS> \"<NOTA>\"}"
  local soc="${2:?Falta SoC (%)}"
  local pack_v="${3:?Falta voltaje del paquete (V)}"
  local bus="${4:-CAN0}"
  local note="${5:-Lectura local}"
  local ts
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  init_ev_log
  printf '{"ts":"%s","unit":"%s","soc_pct":%s,"pack_v":%s,"bus":"%s","note":"%s"}\n' \
    "${ts}" "${unit}" "${soc}" "${pack_v}" "${bus}" "${note}" >> "${EV_LOG}"
  echo "Registrado en ${EV_LOG}: ${unit} | SoC=${soc}% | V=${pack_v}V | ${bus}"
}

ev_tail() {
  local lines="${1:-10}"
  init_ev_log
  echo "=== [VE TELEMETRÍA LOCAL] Últimos ${lines} registros ==="
  tail -n "${lines}" "${EV_LOG}"
}

usage() {
  cat <<EOF
Uso: $0 <comando> [argumentos]

Comandos monerod:
  status                         Consulta proceso local y método RPC get_info
  start [--stagenet|--testnet|--mainnet]
                                 Inicia monerod en segundo plano con log aislado
  stop                           Detiene monerod de forma limpia

Comandos vehículos eléctricos (registro local):
  ev-record <UNIDAD> <SOC> <VOLT> [BUS] [NOTA]
                                 Agrega una línea JSONL de estado/telemetría VE
  ev-tail [N]                    Muestra los últimos N registros VE (por defecto 10)
EOF
}

cmd="${1:-status}"
case "${cmd}" in
  status)
    monerod_status
    ;;
  start)
    monerod_start "${2:---stagenet}"
    ;;
  stop)
    monerod_stop
    ;;
  ev-record)
    shift
    ev_record "$@"
    ;;
  ev-tail)
    ev_tail "${2:-10}"
    ;;
  -h|--help|help)
    usage
    ;;
  *)
    usage
    exit 1
    ;;
esac
