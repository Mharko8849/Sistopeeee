/*
 * Integrantes: Marco Ortiz - 21361620-K, Nicolás Rojas - 21602113-4.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "funciones.h"

int main() {
    char input_buffer[MAX_BUFFER];

    // Leemos la entrada estándar.
    if (fgets(input_buffer, MAX_BUFFER, stdin) == NULL) {
        return 0; // Si no hay entrada, terminamos.
    }

    // Eliminamos el salto de línea '\n' que fgets incluye al final.
    int i = 0;
    while (input_buffer[i] != '\0') {
        if (input_buffer[i] == '\n') {
            input_buffer[i] = '\0';
        }
        i += 1;
    }

    // Si la línea está vacía, no hacemos nada
    if (input_buffer[0] == '\0') {
        return 0;
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