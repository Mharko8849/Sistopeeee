/*
 * Integrantes: Marco Ortiz - 21361620-K, Nicolás Rojas - 21602113-4.
 */

#ifndef FUNCIONES_H
#define FUNCIONES_H

#define MAX_BUFFER 4096  // Limitamos el tamaño de la entrada

/* Definimos una estructura que almacena un comando, las flags y sus valores.
 * Además le pasamos la cantidad total de elementos para manejar de mejor manera los bucles. 
 */
typedef struct {
    char *Command;
    char **FAndVal;
    int TotalArgs;
} FunctionsCommand;

// Asignamos memoria dinámica para los comandos y sus flags
FunctionsCommand* parse_input(char *input, int *count);


void execute_pipeline(FunctionsCommand *commands, int count);

// Liberamos memoria de manera adecuada
void free_memory(FunctionsCommand *commands, int count);

#endif