
# ---------------------------------------------------------
# generator.sh
# ---------------------------------------------------------
# // Entradas:
# //   -i <intervalo> : intervalo en segundos entre cada muestreo (debe ser un entero positivo)
# //   -t <duracion>  : duración total en segundos que debe ejecutarse el generador 
# //                     (debe ser un entero positivo)
# //   -l <archivo>   : archivo donde se guardará el log (o registro) de lo que sucede
# //                     durante la ejecución
# //
# // Salidas:
# //   - Imprime por stdout:
# //       línea de timestamp: "# TIMESTAMP: <ISO-8601>"
# //       seguido de procesos capturados con:
# //         pid, uid, comm, %CPU, %MEM
# //
# // Descripción:
# //   Ejecuta capturas periódicas del estado de procesos usando `ps`.
# //   Repite cada -i segundos hasta que se cumpla el tiempo total -t.
# //   Su salida está diseñada para ser encadenada con pipes.
# ---------------------------------------------------------

# ================================
# Función: print_use
# ================================
# // Entradas: nada
# // Salidas: imprime en pantalla el formato de uso del script
# // Descripción: muestra cómo ejecutar el script y termina
print_use() {
  # El comando cat en Linux permite concatenar y mostrar el contenido de archivos.
  # Deriva de “concatenar” y se utiliza para visualizar, unir y crear archivos. 
  # Por ejemplo, “cat ejemplo.txt” muestra el contenido de “ejemplo.txt”.
  cat <<EOF
Uso: $0 -i <intervalo_segundos> -t <duracion_segundos> [-l <archivo_log>]
Ejemplo: $0 -i 2 -t 20 -l logs/generator.txt
Esto imprimirá timestamp + salida de 'ps' cada 2s durante 20s y guardará los logs en el archivo especificado.
EOF
}

# ================================
# Función: clean
# ================================
# // Entradas: nada (pero lee variable global SAMPLES_PERFORMED)
# // Salidas: imprime por stderr un mensaje de finalización
# // Descripción: se ejecuta cuando el script recibe SIGINT o SIGTERM
clean() {
  # El >&2 es para redirigir la salida de error estándar (stderr) de un comando a la salida estándar (stdout)
  # en lugar de a la pantalla
  echo "generator.sh: terminado por señal. Muestreos realizados = ${SAMPLES_PERFORMED:-0}" >&2
  exit 0
}

# ------------------------------
# Validación de las flags
# ------------------------------
INTERVAL=""
DURATION=""
LOG_FILE=""

# El comando getopts es un comando integrado en Bash para analizar opciones y argumentos de la línea de comandos.
while getopts ":i:t:l:h" opt; do
  # La sentencia bash casese usa generalmente para simplificar condicionales complejos cuando hay varias opciones.
  # Usarla caseen lugar de sentencias if anidadas ayudará a que tus scripts bash sean más legibles y fáciles de mantener.
  case "${opt}" in
    i) INTERVAL="${OPTARG}" ;;
    t) DURATION="${OPTARG}" ;;
    l) LOG_FILE="${OPTARG}" ;;
    h) print_use; exit 0 ;;
    \?) echo "Error: opción inválida -${OPTARG}" >&2; print_use; exit 1 ;;
    :)  echo "Error: la opción -${OPTARG} requiere un argumento." >&2; print_use; exit 1 ;;
  esac
done



# En este caso se usa para verificar si las variables INTERVAL y DURATION están vacías
if [[ -z "${INTERVAL}" || -z "${DURATION}" ]]; then
  echo "Error: Debes indicar -i <intervalo> y -t <duración>." >&2
  print_use
  exit 1
fi

# Validar que sean enteros positivos
# Esto para el manejo de errores
if ! [[ "${INTERVAL}" =~ ^[0-9]+$ && "${DURATION}" =~ ^[0-9]+$ ]]; then
  echo "Error: -i y -t deben ser enteros positivos (ej: 1, 2, 10)." >&2
  exit 1
fi

# Convertir a numeros (Forzamos la evaluación aritmética)
INTERVAL=$(( INTERVAL ))
DURATION=$(( DURATION ))

# Validar que sean mayores que 0
# Esto para el manejo de errores
if (( INTERVAL <= 0 || DURATION <= 0 )); then
  echo "Error: -i y -t deben ser mayores que 0." >&2
  exit 1
fi

# ------------------------------
# Configuración inicial
# ------------------------------
trap clean SIGINT SIGTERM   # Captura Ctrl+C y SIGTERM
START_TS=$(date +%s)          # Momento de inicio
END_TS=$(( START_TS + DURATION ))  # Momento en que debe detenerse
SAMPLES_PERFORMED=0           # Contador de muestreos

# Configurar archivo de log si se especificó
if [[ -n "${LOG_FILE}" ]]; then
    # Crear el directorio del log si no existe
    mkdir -p "$(dirname "${LOG_FILE}")"
    # Iniciar el archivo de log
    echo "Iniciando generador $(date --iso-8601=seconds)" > "${LOG_FILE}"
fi

# ================================
# Bucle principal
# ================================
# // Entradas: variables globales INTERVAL y END_TS
# // Salidas: imprime en stdout timestamp + procesos
# // Descripción: repite hasta que el tiempo actual supere END_TS
while [[ $(date +%s) -lt ${END_TS} ]]; do
  # Dato, el -lt lo que hace es comparar si el valor de la izquierda es menor que el de la derecha
  TIMESTAMP=$(date --iso-8601=seconds)
  echo "# TIMESTAMP: ${TIMESTAMP}"

  # Ejecuta ps con formato específico y guarda la salida en una variable
  PS_OUTPUT=$(ps -eo pid=,uid=,comm=,pcpu=,pmem= --sort=-%cpu)
  
  # Agregar el timestamp a cada línea de la salida de ps
  while IFS= read -r line; do
    echo "${TIMESTAMP} ${line}"
  done <<< "${PS_OUTPUT}"

  # Registra en el log si está habilitado
  if [[ -n "${LOG_FILE}" ]]; then
    echo "[$TIMESTAMP] Captura #${SAMPLES_PERFORMED}" >> "${LOG_FILE}"
    echo "Procesos capturados:" >> "${LOG_FILE}"
    echo "${PS_OUTPUT}" >> "${LOG_FILE}"
    echo "----------------------------------------" >> "${LOG_FILE}"
  fi

  # Actualiza contador
  SAMPLES_PERFORMED=$(( SAMPLES_PERFORMED + 1 ))

  # Calcular tiempo restante
  NOW_TS=$(date +%s)
  REMAINING=$(( END_TS - NOW_TS ))

  # Dormir lo justo
  # El while se detendrá solo cuando la condición inicial deje de cumplirse
  if (( REMAINING > 0 )); then
    if (( REMAINING < INTERVAL )); then
      sleep "${REMAINING}"
    else
      sleep "${INTERVAL}"
    fi
  fi
done

# Mensaje final (stderr para no romper pipeline)
echo "generator.sh: finalizado. Muestreos realizados = ${SAMPLES_PERFORMED}" >&2
exit 0
