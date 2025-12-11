/*
 * Integrantes: Marco Ortiz - 21361620-K, Nicolás Rojas - 21602113-4.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h> 
#include "funciones.h"

// Función para el manejo de errores sobre el uso del programa
void print_usage(char *prog_name) {
    fprintf(stderr, "Uso: %s [-v] [comando...]\n", prog_name);
}

extern int optind;

int main(int argc, char *argv[]) {
    char input_buffer[MAX_BUFFER];
    int opt;

    // Capturamos y validamos los parámetros obtenidos por getopt
    while (((opt = getopt(argc, argv, "+v")) != -1)) {
        if (opt!='v'){
            print_usage(argv[0]);
            exit(EXIT_FAILURE);
        }
    }

    // Verificar si hay argumentos después de las opciones
    if (optind < argc) {
        // Concatenar argumentos restantes (el comando a ejecutar)
        input_buffer[0] = '\0';
        for (int i = optind; i < argc; i++) {
            // Validamos que la entrada no sea demasiado larga
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

    // Separamos la línea por pipes y argumentos.
    int cmd_count = 0;
    FunctionsCommand *cmds = interprate_input(input_buffer, &cmd_count);

    // Acá ejecutamos los pipeline
    // Se crea los procesos hijos y conectan los pipes.
    execute_pipeline(cmds, cmd_count);

    // Finalmente liberamos la memoria
    free_memory(cmds, cmd_count);

    return 0;
}