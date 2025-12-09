#!/bin/bash

# ---------------------------------------------------------
# aggregate.sh  
# ---------------------------------------------------------
# Variables para estadísticas
LINES_PROCESSED=0
UNIQUE_COMMANDS=0

# // Entradas:
# //   - stdin: salida de transform.sh en formato:
# //       TIMESTAMP PID UID COMM %CPU %MEM
# //   - flag opcional:
# //       -l <archivo>: archivo donde se guardará el log de la ejecución
# //
# // Salidas:
# //   - stdout: estadísticas agrupadas por comando en formato:
# //       COMM COUNT AVG_CPU MAX_CPU AVG_MEM MAX_MEM
# //   - stderr: mensajes informativos y de error
# //
# // Descripción:
# //   Agrupa todas las líneas por el campo COMM y calcula estadísticas:
# //   - COUNT: número total de procesos con ese comando
# //   - AVG_CPU: promedio de %CPU 
# //   - MAX_CPU: máximo %CPU observado
# //   - AVG_MEM: promedio de %MEM
# //   - MAX_MEM: máximo %MEM observado
# ---------------------------------------------------------

# ================================
# Función: print_use
# ================================  
# // Entradas: nada
# // Salidas: imprime en stdout el formato de uso del script
# // Descripción: muestra cómo usar el script con ejemplos
print_use() {
  cat <<EOF
Uso: $0

Agrupa procesos por comando y calcula estadísticas desde stdin.

Formato de entrada: TIMESTAMP PID UID COMM %CPU %MEM
Formato de salida:  COMM COUNT AVG_CPU MAX_CPU AVG_MEM MAX_MEM

Ejemplo:
  cat data.txt | $0
  
El script no requiere argumentos, procesa todo desde stdin.
EOF
}

# ================================
# Variables globales
# ================================
LOG_FILE=""

# ================================
# Función: convert_arguments
# ================================
# // Entradas: argumentos de línea de comandos ($@)  
# // Salidas: maneja flags de ayuda o termina con error
# // Descripción: maneja argumentos simples (-h/--help y -l)
convert_arguments() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -l)
        shift
        [[ $# -gt 0 ]] || { echo "Error: la opción -l requiere un argumento." >&2; exit 1; }
        LOG_FILE="$1"
        shift
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
  done
}

# ================================
# Función: process_aggregation
# ================================
# // Entradas: lee todas las líneas desde stdin
# // Salidas: estadísticas agrupadas a stdout
# // Descripción: usa AWK para procesar y agregar datos por comando
process_aggregation() {
  awk '
  {
    # Verificar formato mínimo (6 campos)
    if (NF < 6) {
      print "aggregate.sh: línea con formato inválido descartada: " $0 > "/dev/stderr"
      next
    }
    
    # Extraer campos: TIMESTAMP PID UID COMM %CPU %MEM  
    timestamp = $1
    pid = $2
    uid = $3
    comm = $4
    cpu = $5
    mem = $6
    
    # Validar que CPU y MEM sean numéricos
    if (cpu !~ /^[0-9]+(\.[0-9]+)?$/ || mem !~ /^[0-9]+(\.[0-9]+)?$/) {
      print "aggregate.sh: valores no numéricos en CPU/MEM descartados: " $0 > "/dev/stderr"
      next
    }
    
    # Convertir a números para operaciones
    cpu_val = cpu + 0
    mem_val = mem + 0
    
    # Contadores y acumuladores por comando
    count[comm]++
    cpu_sum[comm] += cpu_val
    mem_sum[comm] += mem_val
    lines_processed++
    
    # Registrar en el log si está habilitado
    if (log_file != "") {
      printf "[%s] Procesando línea %d: comm=%s, cpu=%.2f, mem=%.2f\n", \
        strftime("%Y-%m-%dT%H:%M:%S%z"), lines_processed, comm, cpu_val, mem_val >> log_file
    }
    
    # Máximos (inicializar en primera ocurrencia)
    if (count[comm] == 1) {
      cpu_max[comm] = cpu_val
      mem_max[comm] = mem_val  
    } else {
      if (cpu_val > cpu_max[comm]) cpu_max[comm] = cpu_val
      if (mem_val > mem_max[comm]) mem_max[comm] = mem_val
    }
  }
  
  END {
    # Verificar que procesamos algún dato
    if (length(count) == 0) {
      print "aggregate.sh: no se procesaron datos válidos" > "/dev/stderr"
      exit 1
    }
    
    # Imprimir encabezado
    print "COMM COUNT AVG_CPU MAX_CPU AVG_MEM MAX_MEM"
    
    # Usar PROCINFO["sorted_in"] para ordenar automáticamente
    PROCINFO["sorted_in"] = "@ind_str_asc"  # Ordenar por índice (comando) alfabéticamente
    
    # Procesar cada comando usando for...in (AWK requiere algún tipo de iteración)
    # Esta es la forma estándar en AWK para procesar arrays asociativos
    for (cmd in count) {
      cmd_count = count[cmd]
      avg_cpu = cpu_sum[cmd] / cmd_count
      max_cpu = cpu_max[cmd]  
      avg_mem = mem_sum[cmd] / cmd_count
      max_mem = mem_max[cmd]
      
      # Formatear números con precisión controlada
      printf "%s %d %.2f %.2f %.2f %.2f\n", cmd, cmd_count, avg_cpu, max_cpu, avg_mem, max_mem
      
      # Registrar en el log si está habilitado
      if (log_file != "") {
        printf "[%s] Agregación para %s: count=%d, avg_cpu=%.2f, max_cpu=%.2f, avg_mem=%.2f, max_mem=%.2f\n", \
          strftime("%Y-%m-%dT%H:%M:%S%z"), cmd, cmd_count, avg_cpu, max_cpu, avg_mem, max_mem >> log_file
      }
    }
    
    # Estadística final al stderr
    printf "aggregate.sh: procesados %d comandos únicos\n", length(count) > "/dev/stderr"
  }
  '
}

# ================================
# EJECUCIÓN PRINCIPAL
# ================================

# Convierte/Interpreta todos argumentos de línea de comandos
convert_arguments "$@"

# Función para escribir resumen en el log
write_summary() {
    if [[ -n "${LOG_FILE}" ]]; then
        {
            echo "----------------------------------------"
            echo "Resumen de agregación:"
            echo "  Líneas procesadas: ${LINES_PROCESSED}"
            echo "  Comandos únicos: ${UNIQUE_COMMANDS}"
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
        echo "Iniciando agregador $(date --iso-8601=seconds)"
        echo "Comenzando agregación de estadísticas..."
    } > "${LOG_FILE}"
fi

# Mensaje informativo
echo "aggregate.sh: iniciando agregación de datos..." >&2

# Procesar agregación desde stdin
process_aggregation