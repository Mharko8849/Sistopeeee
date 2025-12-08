#!/bin/bash

# ---------------------------------------------------------
# transform.sh
# ---------------------------------------------------------
# Variables para estadísticas
LINES_PROCESSED=0
LINES_TRANSFORMED=0
# // Entradas:
# //   - stdin: salida de filter.sh en formato:
# //       TIMESTAMP PID UID COMM %CPU %MEM
# //   - flags opcionales:
# //       --anon-uid: anonimiza el campo UID usando hash SHA256
# //       -l <archivo>: archivo donde se guardará el log de la ejecución
# //
# // Salidas:
# //   - stdout: líneas transformadas manteniendo el mismo formato
# //   - stderr: mensajes de error o información de debug
# //
# // Descripción:
# //   Transforma los datos de entrada, principalmente anonimizando UIDs
# //   cuando se especifica el flag --anon-uid. El resto de campos
# //   permanecen intactos para mantener compatibilidad con el pipeline.
# ---------------------------------------------------------

# ================================
# Función: print_use
# ================================
# // Entradas: nada
# // Salidas: imprime en stdout el formato de uso del script
# // Descripción: muestra cómo usar el script con ejemplos
print_use() {
  cat <<EOF
Uso: $0 [--anon-uid]

Transforma datos de procesos desde stdin:
  --anon-uid : anonimiza el UID usando hash SHA256

Ejemplos:
  # Sin transformaciones (passthrough)
  $0
  
  # Con anonimización de UIDs
  $0 --anon-uid

Formato entrada/salida: TIMESTAMP PID UID COMM %CPU %MEM
EOF
}

# ================================
# Variables globales
# ================================
ANON_UID=false
LOG_FILE=""

# ================================
# Función: convert_arguments
# ================================
# // Entradas: argumentos de línea de comandos ($@)
# // Salidas: modifica variable global ANON_UID
# // Descripción: convierte/intrepreta y valida los argumentos del script
convert_arguments() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --anon-uid)
        ANON_UID=true
        ;;
      -l)
        shift
        [[ $# -gt 0 ]] || { echo "Error: falta argumento para -l" >&2; exit 1; }
        LOG_FILE="$1"
        ;;
      -h|--help)
        print_use
        exit 0
        ;;
      *)
        echo "Error: opción desconocida: $1" >&2
        print_use
        exit 1
        ;;
    esac
    shift
  done
}

# ================================
# Función: anonymize_uid
# ================================
# // Entradas: $1 = UID original (string/número)
# // Salidas: hash SHA256 truncado a 8 caracteres
# // Descripción: genera un hash determinístico del UID para anonimización
anonymize_uid() {
  local original_uid="$1"
  
  # Verificar que tenemos las herramientas necesarias
  if ! command -v sha256sum >/dev/null 2>&1; then
    echo "Error: sha256sum no disponible para anonimización" >&2
    exit 1
  fi
  
  # Generar hash SHA256 y tomar los primeros 8 caracteres
  # Usamos un salt fijo para que sea determinístico pero no trivial de revertir
  local salt="lab1_so_2025"
  local hash=$(echo -n "${salt}_${original_uid}" | sha256sum | cut -d' ' -f1 | head -c 8)
  echo "${hash}"
}

# ================================
# Función: process_line
# ================================
# // Entradas: $1 = línea completa del stdin
# // Salidas: línea transformada a stdout
# // Descripción: procesa una línea aplicando las transformaciones necesarias
process_line() {
  local line="$1"
  
  # Verificar que la línea no esté vacía
  if [[ -z "${line}" ]]; then
    return
  fi
  
  # Convertimos/interpretamos los campos (esperamos: TIMESTAMP PID UID COMM %CPU %MEM)
  read -r timestamp pid uid comm cpu mem <<< "${line}"
  
  # Verificar que tenemos todos los campos necesarios
  if [[ -z "${timestamp}" || -z "${pid}" || -z "${uid}" || -z "${comm}" || -z "${cpu}" || -z "${mem}" ]]; then
    echo "transform.sh: línea con formato inválido descartada: ${line}" >&2
    return
  fi
  
  # Aplicar transformación de UID si está habilitada
  local original_uid="${uid}"
  if $ANON_UID; then
    uid=$(anonymize_uid "$uid")
    if [[ -n "${LOG_FILE}" ]]; then
      echo "[$(date --iso-8601=seconds)] UID transformado: ${original_uid} -> ${uid}" >> "${LOG_FILE}"
    fi
    LINES_TRANSFORMED=$((LINES_TRANSFORMED + 1))
  fi
  
  LINES_PROCESSED=$((LINES_PROCESSED + 1))
  # Imprimir línea transformada manteniendo el formato original
  echo "${timestamp} ${pid} ${uid} ${comm} ${cpu} ${mem}"
}

# ================================
# Función: main_processing
# ================================
# // Entradas: lee de stdin línea por línea
# // Salidas: escribe líneas transformadas a stdout
# // Descripción: bucle principal que procesa todas las líneas de entrada
main_processing() {
  local line_count=0
  local processed_count=0
  
  while IFS= read -r line; do
    line_count=$((line_count + 1))
    
    # Procesar la línea (esto maneja validaciones internas)
    if output=$(process_line "${line}"); then
      processed_count=$((processed_count + 1))
      if [[ -n "${LOG_FILE}" ]]; then
        echo "[$(date --iso-8601=seconds)] Línea procesada: ${line} -> ${output}" >> "${LOG_FILE}"
      fi
      echo "${output}"
    fi
  done
  
  # Mensaje informativo al stderr (no interfiere con el pipeline)
  echo "transform.sh: procesadas ${processed_count} de ${line_count} líneas" >&2
}

# ================================
# EJECUCIÓN PRINCIPAL
# ================================

# Convierte/Interpreta todos argumentos de línea de comandos
convert_arguments "$@"

# Configurar archivo de log si se especificó
if [[ -n "${LOG_FILE}" ]]; then
    # Crear el directorio del log si no existe
    mkdir -p "$(dirname "${LOG_FILE}")"
    # Iniciar el archivo de log
    echo "Iniciando transformador $(date --iso-8601=seconds)" > "${LOG_FILE}"
    echo "Configuración:" >> "${LOG_FILE}"
    $ANON_UID && echo "- Anonimización de UID: activada" >> "${LOG_FILE}"
fi

# Información de debug al stderr
if $ANON_UID; then
  echo "transform.sh: anonimización de UID habilitada" >&2
else
  echo "transform.sh: modo passthrough (sin transformaciones)" >&2
fi

# Procesar todas las líneas de stdin
main_processing
