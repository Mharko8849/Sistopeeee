#!/bin/bash

# ---------------------------------------------------------
# report.sh
# ---------------------------------------------------------
# // Entradas:
# //   - stdin: salida de aggregate.sh en formato:
# //       COMM COUNT AVG_CPU MAX_CPU AVG_MEM MAX_MEM
# //   - flag obligatorio:
# //       -o <archivo>: nombre del archivo de salida (CSV/TSV)
# //
# // Salidas:
# //   - archivo especificado: reporte final con metadatos y datos
# //   - stderr: mensajes informativos y de error
# //
# // Descripción:
# //   Genera el reporte final añadiendo metadatos del sistema
# //   (fecha, usuario, host) y guarda todo en formato CSV/TSV.
# //   Es el último paso del pipeline de procesamiento.
# ---------------------------------------------------------

# ================================
# Función: print_usage
# ================================
# // Entradas: nada
# // Salidas: imprime en stdout el formato de uso del script
# // Descripción: muestra cómo usar el script con ejemplos
print_usage() {
  cat <<EOF
Uso: $0 -o <archivo_salida>

Genera reporte final con metadatos desde stdin.

Parámetros obligatorios:
  -o <archivo> : nombre del archivo de salida (CSV/TSV)

Ejemplos:
  # Generar reporte CSV
  cat data.txt | $0 -o reporte.csv
  
  # Generar reporte TSV  
  cat data.txt | $0 -o reporte.tsv
  
  # Pipeline completo
  ./generator.sh -i 1 -t 10 | ./preprocess.sh | ./filter.sh | ./transform.sh | ./aggregate.sh | $0 -o resultado.csv

Formato entrada: COMM COUNT AVG_CPU MAX_CPU AVG_MEM MAX_MEM
EOF
}

# ================================
# Variables globales
# ================================
OUTPUT_FILE=""

# ================================
# Función: convert_arguments
# ================================
# // Entradas: argumentos de línea de comandos ($@)
# // Salidas: modifica variable global OUTPUT_FILE
# // Descripción: convierte/interpreta y valida los argumentos del script
convert_arguments() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -o)
        shift
        [[ $# -gt 0 ]] || { echo "Error: falta argumento para -o" >&2; exit 1; }
        OUTPUT_FILE="$1"
        ;;
      -h|--help)
        print_usage
        exit 0
        ;;
      *)
        echo "Error: opción desconocida: $1" >&2
        print_usage
        exit 1
        ;;
    esac
    shift
  done
  
  # Verificar que se especificó archivo de salida
  if [[ -z "${OUTPUT_FILE}" ]]; then
    echo "Error: debe especificar archivo de salida con -o" >&2
    print_usage
    exit 1
  fi
}

# ================================
# Función: get_system_metadata
# ================================
# // Entradas: nada
# // Salidas: imprime metadatos del sistema al archivo
# // Descripción: obtiene y formatea información del sistema actual
get_system_metadata() {
  echo "# =============================================="
  echo "# REPORTE DE MONITOREO DE PROCESOS"
  echo "# =============================================="
  echo "#"
  echo "# Fecha de generación: $(date --iso-8601=seconds)"
  echo "# Usuario: $(whoami)"
  echo "# Host: $(hostname)"
  echo "# Directorio: $(pwd)"
  echo "# Script ejecutado: $0"
  echo "#"
  echo "# Generado por pipeline:"
  echo "# generator.sh -> preprocess.sh -> filter.sh -> transform.sh -> aggregate.sh -> report.sh"
  echo "#"
  echo "# =============================================="
  echo ""
}

# ================================
# Función: determine_separator
# ================================
# // Entradas: $1 = nombre del archivo
# // Salidas: retorna separador apropiado (coma o tab)
# // Descripción: determina si usar CSV (,) o TSV (tab) según extensión
determine_separator() {
  case "$1" in
    *.tsv|*.TSV)
      echo -e "\t"  # Tab para TSV
      ;;
    *.csv|*.CSV|*)
      echo ","      # Coma para CSV (por defecto)
      ;;
  esac
}

# ================================
# Función: process_data_lines
# ================================
# // Entradas: $1 = separador, lee stdin línea por línea
# // Salidas: imprime líneas procesadas al archivo
# // Descripción: convierte datos de entrada al formato CSV/TSV
process_data_lines() {
  separator="$1"
  line_count=0
  header_written=false
  
  while IFS= read -r line; do
    line_count=$((line_count + 1))
    
    # Ignorar líneas vacías
    if [[ -z "${line}" ]]; then
      continue
    fi
    
    # Ignorar comentarios (líneas que empiecen con #)
    if [[ "${line:0:1}" == "#" ]]; then
      continue
    fi
    
    # Convertir/Interpreta campos separados por espacios
    read -r comm count avg_cpu max_cpu avg_mem max_mem <<< "${line}"
    
    # Validar que tenemos todos los campos
    if [[ -z "${comm}" || -z "${count}" || -z "${avg_cpu}" || -z "${max_cpu}" || -z "${avg_mem}" || -z "${max_mem}" ]]; then
      echo "report.sh: línea con formato incorrecto descartada: ${line}" >&2
      continue
    fi
    
    # Escribir encabezado solo una vez
    if ! $header_written; then
      echo "COMANDO${separator}PROCESOS${separator}CPU_PROMEDIO${separator}CPU_MAXIMO${separator}MEM_PROMEDIO${separator}MEM_MAXIMO"
      header_written=true
    fi
    
    # Escribir línea de datos en formato CSV/TSV
    echo "${comm}${separator}${count}${separator}${avg_cpu}${separator}${max_cpu}${separator}${avg_mem}${separator}${max_mem}"
  done
  
  # Verificar que procesamos algunos datos
  if (( line_count == 0 )); then
    echo "report.sh: advertencia - no se procesaron datos desde stdin" >&2
  fi

  echo "report.sh: procesadas ${line_count} líneas de datos" >&2
}

# ================================
# Función: generate_report
# ================================
# // Entradas: lee stdin y usa variables globales
# // Salidas: crea archivo completo con metadatos y datos
# // Descripción: función principal que genera el reporte completo
generate_report() {
  # Determinar separador según extensión del archivo
  separator=$(determine_separator "${OUTPUT_FILE}")
  
  # Verificar que podemos escribir al archivo
  if ! touch "${OUTPUT_FILE}" 2>/dev/null; then
    echo "Error: no se puede escribir al archivo '${OUTPUT_FILE}'" >&2
    exit 1
  fi
  
  # Generar reporte completo
  {
    # Metadatos iniciales
    get_system_metadata
    
    # Procesar datos desde stdin
    process_data_lines "${separator}"
    
  } > "${OUTPUT_FILE}"
  
  # Información final
  echo "report.sh: reporte generado exitosamente en '${OUTPUT_FILE}'" >&2
  echo "report.sh: formato detectado: $(if [[ "${separator}" == $'\t' ]]; then echo "TSV"; else echo "CSV"; fi)" >&2
}

# ================================
# EJECUCIÓN PRINCIPAL
# ================================

# Convertir/Interpreta argumentos de línea de comandos
convert_arguments "$@"

# Mensaje informativo
echo "report.sh: generando reporte en '${OUTPUT_FILE}'..." >&2

# Generar reporte completo
generate_report

# Mostrar resumen final
if [[ -f "${OUTPUT_FILE}" ]]; then
  file_size=$(wc -l < "${OUTPUT_FILE}")
  echo "report.sh: archivo creado con ${file_size} líneas" >&2
  echo "report.sh: ubicación: $(realpath "${OUTPUT_FILE}")" >&2
else
  echo "Error: no se pudo crear el archivo de reporte" >&2
  exit 1
fi
