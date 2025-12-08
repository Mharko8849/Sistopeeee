
# ---------------------------------------------------------
# preprocess.sh
# ---------------------------------------------------------
# // Entradas:
# //   - stdin: salida de generator.sh (bloques con "# TIMESTAMP: ..." y líneas de procesos)
# //   - flag opcional: --iso8601
# //   - -l <archivo>: archivo donde se guardará el log de la ejecución
# //
# // Salidas:
# //   - stdout: líneas válidas normalizadas en formato:
# //       TIMESTAMP PID UID COMM %CPU %MEM
# //   - stderr: avisos (líneas descartadas / errores de conversion/interpretacion)
# //
# // Descripción:
# //   Lee la salida de generator.sh, maneja espacios en blanco, valida tipos de datos,
# //   convierte opcionalmente el timestamp a ISO-8601 UTC y emite una línea por proceso.
# ---------------------------------------------------------

print_use() {
  cat <<EOF
Uso: $0 [--iso8601] [-l <archivo_log>]
Lee stdin (salida de generator.sh) y emite:
TIMESTAMP PID UID COMM %CPU %MEM
Opciones:
  --iso8601        Convierte timestamps a formato ISO-8601
  -l <archivo>     Guarda el log en el archivo especificado
EOF
}

# Conversión de flags simples
ISO8601=false
LOG_FILE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --iso8601) ISO8601=true; shift ;;
    -l) 
      if [[ -n "${2:-}" ]]; then
        LOG_FILE="$2"
        shift 2
      else
        echo "Error: -l requiere un argumento." >&2
        exit 1
      fi ;;
    -h|--help) print_use; exit 0 ;;
    *) echo "Opción inválida: $1" >&2; print_use; exit 1 ;;
  esac
done

# Función para escribir resumen en el log
write_summary() {
    if [[ -n "${LOG_FILE}" ]]; then
        {
            echo "----------------------------------------"
            echo "Resumen del procesamiento:"
            echo "  Líneas procesadas: ${LINES_PROCESSED}"
            echo "  Líneas válidas: ${LINES_VALID}"
            echo "  Líneas inválidas: ${LINES_INVALID}"
            echo "Finalizado en: $(date --iso-8601=seconds)"
            echo "----------------------------------------"
        } >> "${LOG_FILE}"
    fi
}

# Configurar trap para capturar señales y escribir resumen
trap write_summary EXIT SIGPIPE

# Configurar archivo de log si se especificó
if [[ -n "${LOG_FILE}" ]]; then
    # Crear el directorio del log si no existe
    mkdir -p "$(dirname "${LOG_FILE}")"
    # Iniciar el archivo de log
    echo "Iniciando preprocesador $(date --iso-8601=seconds)" > "${LOG_FILE}"
fi

# Función para normalizar timestamp (intenta date; si falla, devuelve raw)
normalize_timestamp() {
  local raw="$1"
  if $ISO8601; then
    # date -d puede fallar si el formato es raro; usamos if para capturar fallo
    if converted=$(date -u -d "$raw" +"%Y-%m-%dT%H:%M:%S" 2>/dev/null); then
      echo "${converted}"
    else
      # fallback: devolver el raw (no abortamos el script)
      echo "${raw}"
    fi
  else
    echo "${raw}"
  fi
}

CURRENT_TS=""

# Variables para estadísticas
LINES_PROCESSED=0
LINES_VALID=0
LINES_INVALID=0

# Bucle principal: lee stdin línea por línea
while IFS= read -r line; do
  # Incrementar contador de líneas procesadas
  LINES_PROCESSED=$((LINES_PROCESSED + 1))

  # 1) Recortar espacios al inicio y al final:
  trimmed="${line#"${line%%[![:space:]]*}"}"   # Left
  trimmed="${trimmed%"${trimmed##*[![:space:]]}"}" # Right

  # Si la línea quedó vacía, la ignoramos
  if [[ -z "${trimmed}" ]]; then
    if [[ -n "${LOG_FILE}" ]]; then
      echo "[$(date --iso-8601=seconds)] Línea vacía ignorada" >> "${LOG_FILE}"
    fi
    LINES_INVALID=$((LINES_INVALID + 1))
    continue
  fi

  # Ignorar líneas que empiecen con # (comentarios)
  if [[ "${trimmed:0:1}" == "#" ]]; then
    continue
  fi

  # 2) Procesar la línea que debe tener formato: TIMESTAMP PID UID COMM %CPU %MEM
  if [[ "${trimmed}" =~ ^([^ ]+)[[:space:]]+(.*)$ ]]; then
    raw_ts="${BASH_REMATCH[1]}"
    rest_of_line="${BASH_REMATCH[2]}"
    
    # Convertir timestamp si se solicitó
    current_ts="$(normalize_timestamp "${raw_ts}")"
    
    # 3) Procesar el resto: PID UID COMM %CPU %MEM
    if [[ "$rest_of_line" =~ ([0-9]+\.?[0-9]*)[[:space:]]+([0-9]+\.?[0-9]*)[[:space:]]*$ ]]; then
      pmem="${BASH_REMATCH[2]}"
      pcpu="${BASH_REMATCH[1]}"
      
      # Remover %CPU y %MEM del final
      prefix="${rest_of_line% *}"  # Quitar %MEM
      prefix="${prefix% *}"   # Quitar %CPU
      
      # Extraer PID, UID y COMM
      if [[ "$prefix" =~ ^([0-9]+)[[:space:]]+([0-9]+)[[:space:]]+(.+)$ ]]; then
        pid="${BASH_REMATCH[1]}"
        uid="${BASH_REMATCH[2]}"
        comm="${BASH_REMATCH[3]}"
        
        # Limpiar espacios en comm
        comm="${comm#"${comm%%[![:space:]]*}"}"   # trim left
        comm="${comm%"${comm##*[![:space:]]}"}"   # trim right
        
        # Registrar en el log
        if [[ -n "${LOG_FILE}" ]]; then
          echo "[$(date --iso-8601=seconds)] Procesando: PID=${pid} UID=${uid} COMM=${comm} CPU=${pcpu} MEM=${pmem}" >> "${LOG_FILE}"
        fi
        LINES_VALID=$((LINES_VALID + 1))

        # Para la salida, reemplazar espacios en comm con guiones bajos
        comm_escaped="${comm// /_}"

        # Imprimir línea normalizada
        echo "${current_ts} ${pid} ${uid} ${comm_escaped} ${pcpu} ${pmem}"
      else
        echo "preprocess.sh: no se pudo extraer PID/UID/COMM -> $rest_of_line" >&2
        if [[ -n "${LOG_FILE}" ]]; then
          echo "[$(date --iso-8601=seconds)] ERROR: No se pudo extraer PID/UID/COMM -> ${rest_of_line}" >> "${LOG_FILE}"
        fi
        LINES_INVALID=$((LINES_INVALID + 1))
      fi
    else
      echo "preprocess.sh: no se pudieron extraer %CPU/%MEM -> $rest_of_line" >&2
      LINES_INVALID=$((LINES_INVALID + 1))
    fi
  else
    echo "preprocess.sh: línea inválida (formato incorrecto) -> $trimmed" >&2
    if [[ -n "${LOG_FILE}" ]]; then
      echo "[$(date --iso-8601=seconds)] ERROR: Formato de línea incorrecto -> ${trimmed}" >> "${LOG_FILE}"
    fi
    LINES_INVALID=$((LINES_INVALID + 1))
  fi
done