
# ---------------------------------------------------------
# filter.sh
# ---------------------------------------------------------
# // Entradas:
# //   - stdin: salida de preprocess.sh en formato:
# //       TIMESTAMP PID UID COMM %CPU %MEM
# //   - flags opcionales:
# //       -c <minCPU>: umbral mínimo de %CPU (procesos >= umbral)
# //       -m <minMEM>: umbral mínimo de %MEM (procesos >= umbral)  
# //       -r <regex>: expresión regular aplicada al campo COMM
# //       -l <archivo>: archivo donde se guardará el log de la ejecución
# //
# // Salidas:
# //   - stdout: líneas que cumplen TODOS los criterios especificados
# //   - stderr: mensajes de error si hay problemas con argumentos
# //
# // Descripción:
# //   Filtra procesos según criterios de CPU, memoria y nombre de comando.
# //   Solo pasan las líneas que cumplen simultáneamente todos los filtros activos.
# ---------------------------------------------------------

# ================================
# Función: print_use
# ================================
# // Entradas: nada
# // Salidas: imprime en stdout el formato de uso del script
# // Descripción: muestra cómo usar el script con ejemplos
print_use() {
  cat <<EOF
Uso: $0 [-c minCPU] [-m minMEM] [-r regex] [-l archivo_log]

Filtra procesos de stdin según criterios opcionales:
  -c <num> : umbral mínimo de %CPU (incluye procesos >= num)
  -m <num> : umbral mínimo de %MEM (incluye procesos >= num)  
  -r <expr>: expresión regular aplicada al comando (COMM)
  -l <archivo>: archivo donde se guardará el log de la ejecución

Ejemplos:
  # Procesos con CPU >= 5%
  $0 -c 5
  
  # Procesos con MEM >= 2% Y que contengan "python" o "chrome"
  $0 -m 2 -r "^(python|chrome)"
  
  # Solo procesos de Firefox con CPU alta
  $0 -c 10 -r "firefox"

Formato entrada esperado: TIMESTAMP PID UID COMM %CPU %MEM
EOF
}

# ================================
# Variables para almacenar filtros y estadísticas
# ================================
CPU_MIN=""
MEM_MIN=""
COMM_REGEX=""
LOG_FILE=""
LINES_PROCESSED=0
LINES_PASSED=0
LINES_FILTERED=0

# ================================
# Función: convert_arguments  
# ================================
# // Entradas: argumentos de línea de comandos ($@)
# // Salidas: modifica variables globales CPU_MIN, MEM_MIN, COMM_REGEX
# // Descripción: convierte y valida los argumentos del script
convert_arguments() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -c)
        shift
        [[ $# -gt 0 ]] || { echo "Error: falta argumento para -c" >&2; exit 1; }
        CPU_MIN="$1"
        ;;
      -m)
        shift
        [[ $# -gt 0 ]] || { echo "Error: falta argumento para -m" >&2; exit 1; }
        MEM_MIN="$1"
        ;;
      -r)
        shift
        [[ $# -gt 0 ]] || { echo "Error: falta argumento para -r" >&2; exit 1; }
        COMM_REGEX="$1"
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
# Función: validate_numeric_args
# ================================  
# // Entradas: lee variables globales CPU_MIN y MEM_MIN
# // Salidas: termina el script si hay valores inválidos
# // Descripción: valida que los umbrales sean números válidos
validate_numeric_args() {
  local num_regex='^[0-9]+(\.[0-9]+)?$'
  
  if [ -n "${CPU_MIN}" ] && ! [[ "${CPU_MIN}" =~ $num_regex ]]; then
    echo "Error: -c requiere un número válido (entero o decimal), recibido: '${CPU_MIN}'" >&2
    exit 1
  fi
  
  if [ -n "${MEM_MIN}" ] && ! [[ "${MEM_MIN}" =~ $num_regex ]]; then
    echo "Error: -m requiere un número válido (entero o decimal), recibido: '${MEM_MIN}'" >&2
    exit 1
  fi
}

# ================================
# EJECUCIÓN PRINCIPAL
# ================================

# Convierte/Interpreta todos argumentos de línea de comandos
convert_arguments "$@"

# Validar que los argumentos numéricos sean correctos
validate_numeric_args

# Configurar archivo de log si se especificó
if [[ -n "${LOG_FILE}" ]]; then
    # Crear el directorio del log si no existe
    mkdir -p "$(dirname "${LOG_FILE}")"
    # Iniciar el archivo de log
    echo "Iniciando filtro $(date --iso-8601=seconds)" > "${LOG_FILE}"
    echo "Configuración:" >> "${LOG_FILE}"
    [[ -n "${CPU_MIN}" ]] && echo "- CPU mínima: ${CPU_MIN}%" >> "${LOG_FILE}"
    [[ -n "${MEM_MIN}" ]] && echo "- Memoria mínima: ${MEM_MIN}%" >> "${LOG_FILE}"
    [[ -n "${COMM_REGEX}" ]] && echo "- Regex de comando: ${COMM_REGEX}" >> "${LOG_FILE}"
fi

# Función para escribir resumen en el log
write_summary() {
    if [[ -n "${LOG_FILE}" ]]; then
        {
            echo "----------------------------------------"
            echo "Resumen del filtrado:"
            echo "Criterios aplicados:"
            [[ -n "${CPU_MIN}" ]] && echo "  - CPU >= ${CPU_MIN}%"
            [[ -n "${MEM_MIN}" ]] && echo "  - MEM >= ${MEM_MIN}%"
            [[ -n "${COMM_REGEX}" ]] && echo "  - COMM matches: ${COMM_REGEX}"
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
    {
        echo "Iniciando filtro $(date --iso-8601=seconds)"
        echo "Criterios de filtrado:"
        [[ -n "${CPU_MIN}" ]] && echo "  - CPU >= ${CPU_MIN}%"
        [[ -n "${MEM_MIN}" ]] && echo "  - MEM >= ${MEM_MIN}%"
        [[ -n "${COMM_REGEX}" ]] && echo "  - COMM matches: ${COMM_REGEX}"
    } > "${LOG_FILE}"
fi

# ================================
# Función de filtrado con AWK
# ================================
# // Entradas: stdin con formato "TIMESTAMP PID UID COMM %CPU %MEM"
# // Salidas: stdout con líneas que pasan todos los filtros
# // Descripción: usa AWK para aplicar filtros de CPU, memoria y regex
awk -v cpu_min="${CPU_MIN}" -v mem_min="${MEM_MIN}" -v comm_re="${COMM_REGEX}" -v log_file="${LOG_FILE}" '
{
  # Verificar que la línea tenga al menos 6 campos
  if (NF < 6) {
    print "filter.sh: línea con menos de 6 campos descartada: " $0 > "/dev/stderr"
    next
  }
  
  # Extraer campos (formato: TIMESTAMP PID UID COMM %CPU %MEM)
  timestamp = $1
  pid = $2
  uid = $3  
  comm = $4
  cpu = $5
  mem = $6
  
  # Variable para indicar si la línea pasa todos los filtros
  passes_all_filters = 1
  
  # Aplicar filtro de CPU mínima (si está especificado)
  if (cpu_min != "" && (cpu + 0) < (cpu_min + 0)) {
    passes_all_filters = 0
  }
  
  # Aplicar filtro de memoria mínima (si está especificado)  
  if (mem_min != "" && (mem + 0) < (mem_min + 0)) {
    passes_all_filters = 0
  }
  
  # Aplicar filtro de expresión regular sobre COMM (si está especificado)
  if (comm_re != "" && comm !~ comm_re) {
    passes_all_filters = 0
  }
  
  # Si pasa todos los filtros, imprimir la línea completa
  if (passes_all_filters) {
    print $0
    if (log_file != "") {
      printf "[%s] PASS: %s\n", strftime("%Y-%m-%dT%H:%M:%S%z"), $0 >> log_file
    }
  } else {
    if (log_file != "") {
      printf "[%s] FILTERED: %s (", strftime("%Y-%m-%dT%H:%M:%S%z"), $0 >> log_file
      if (cpu_min != "" && (cpu + 0) < (cpu_min + 0)) printf "CPU too low, " >> log_file
      if (mem_min != "" && (mem + 0) < (mem_min + 0)) printf "MEM too low, " >> log_file
      if (comm_re != "" && comm !~ comm_re) printf "COMM not matching, " >> log_file
      printf ")\n" >> log_file
    }
  }
}
'
