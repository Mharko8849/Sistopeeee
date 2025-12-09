/*
 * Integrantes: Marco Ortiz - 21361620-K, Nicolás Rojas - 21602113-4.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h> // Necesario para getopt
#include "funciones.h"

void print_usage(char *prog_name) {
    fprintf(stderr, "Uso: %s [-v] [comando...]\n", prog_name);
    fprintf(stderr, "  -v : Modo verboso (debug)\n");
}

int main(int argc, char *argv[]) {
    char input_buffer[MAX_BUFFER];
    int opt;
    int verbose_flag = 0;

    // 1. Capturar y validar parámetros por medio de getopt
    // Usamos "+" en optstring para detener el procesamiento en el primer argumento no-opción
    // Esto permite comandos como: ./lab2 -v generator.sh -i 1
    while ((opt = getopt(argc, argv, "+v")) != -1) {
        switch (opt) {
            case 'v':
                verbose_flag = 1;
                break;
            default:
                print_usage(argv[0]);
                exit(EXIT_FAILURE);
        }
    }

    if (verbose_flag) {
        fprintf(stderr, "[DEBUG] Modo verboso activado.\n");
    }

    // Verificar si hay argumentos después de las opciones
    if (optind < argc) {
        // Concatenar argumentos restantes (el comando a ejecutar)
        input_buffer[0] = '\0';
        for (int i = optind; i < argc; i++) {
            // Verificar desbordamiento de buffer
            if (strlen(input_buffer) + strlen(argv[i]) + 2 > MAX_BUFFER) {
                fprintf(stderr, "Error: Comando demasiado largo.\n");
                exit(EXIT_FAILURE);
            }
            strcat(input_buffer, argv[i]);
            if (i < argc - 1) {
                strcat(input_buffer, " ");
            }
        }
    } else {
        // Si no hay argumentos, leemos la entrada estándar.
        if (verbose_flag) {
            fprintf(stderr, "[DEBUG] Leyendo desde stdin...\n");
        }
        if (fgets(input_buffer, MAX_BUFFER, stdin) == NULL) {
            return 0; // Si no hay entrada, terminamos.
        }

        // Eliminamos el salto de línea '\n' que fgets incluye al final.
        size_t len = strlen(input_buffer);
        if (len > 0 && input_buffer[len - 1] == '\n') {
            input_buffer[len - 1] = '\0';
        }
    }

    // Si la línea está vacía, no hacemos nada
    if (input_buffer[0] == '\0') {
        return 0;
    }

    if (verbose_flag) {
        fprintf(stderr, "[DEBUG] Procesando comando: %s\n", input_buffer);
    }

    // Separa la línea por pipes y argumentos.
    int cmd_count = 0;
    FunctionsCommand *cmds = parse_input(input_buffer, &cmd_count);

    // Acá ejecutamos los pipeline
    // Se crea los procesos hijos y conectan los pipes.
    execute_pipeline(cmds, cmd_count);

    // Finalmente liberamos la memoria
    free_memory(cmds, cmd_count);

    return 0;
}