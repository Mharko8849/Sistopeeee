/*
 * Integrantes: Marco Ortiz - 21361620-K, Nicolás Rojas - 21602113-4.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/wait.h>
#include "funciones.h"

// Entradas: 
//    char *input: Cadena de texto que contiene la línea de comandos completa (ej: "cmd1 | cmd2").
//    int *count: Puntero a entero donde se almacenará la cantidad de comandos encontrados.
// Salidas: 
//    Retorna un puntero a un arreglo de estructuras FunctionsCommand con la información parseada.
// Descripción: 
//    Esta función analiza la entrada estándar, cuenta cuántos comandos hay separados por pipes ('|'),
//    reserva memoria dinámica para las estructuras y luego separa cada comando en sus argumentos individuales
//    para dejarlos listos para la ejecución.
FunctionsCommand* parse_input(char *input, int *count) {
    
    // Contamos los comandos para saber cuanta memoria asignar
    *count = 0;
    
    // Hacemos una copia temporal para contar los pipes sin romper el original aún
    char *input_copy = strdup(input);
    if (input_copy == NULL) { 
        perror("Error strdup input_copy"); 
        exit(1); 
    }

    // Aquí creamos un fragmento de la entrada separado por pipes
    char *cmd_substring = strtok(input_copy, "|");
    int cmd_capacity = 0;
    
    while (cmd_substring != NULL) {
        cmd_capacity += 1;
        cmd_substring = strtok(NULL, "|");
    }
    free(input_copy); // Liberamos la copia usada solo para contar

    // Asignamos memoria para el arreglo de estructuras
    FunctionsCommand *cmds = (FunctionsCommand*) malloc(sizeof(FunctionsCommand) * cmd_capacity);
    if (cmds == NULL) { 
        perror("Error malloc cmds"); 
        exit(1); 
    }
    
    // Puntero necesario para que el strtok_r no se pierda
    char *saveptr_main;
    
    // Obtenemos el primer "substring" de comando (ej: "ls -l")
    char *current_cmd_substring = strtok_r(input, "|", &saveptr_main);
    
    int i = 0;
    while (current_cmd_substring != NULL) {
        
        // Necesitamos una copia temporal del substring para contar las palabras
        char *temp_cmd_copy = strdup(current_cmd_substring);
        int args_count = 0;
        char *saveptr_args_temp;
        
        char *arg_substring = strtok_r(temp_cmd_copy, " \t\n", &saveptr_args_temp);
        
        while(arg_substring != NULL) {
            args_count += 1;
            arg_substring = strtok_r(NULL, " \t\n", &saveptr_args_temp);
        }
        free(temp_cmd_copy); // Liberamos la copia temporal

        // Le agregamos un +1 porque el último debe ser NULL obligatoriamente para execvp
        // Y agregamos espacio extra por si necesitamos insertar "bash" al principio
        cmds[i].FAndVal = (char**) malloc(sizeof(char*) * (args_count + 2));
        cmds[i].TotalArgs = 0;

        char *saveptr_args_real;
        
        // Volvemos a leer el substring original para guardar los datos
        char *real_arg_substring = strtok_r(current_cmd_substring, " \t\n", &saveptr_args_real);
        
        // Variable para detectar si es un script .sh
        int is_shell_script = 0;

        while (real_arg_substring != NULL) {
            // Si es el primer argumento (el comando) y termina en .sh, activamos la bandera
            if (cmds[i].TotalArgs == 0) {
                size_t len = strlen(real_arg_substring);
                if (len > 3 && strcmp(real_arg_substring + len - 3, ".sh") == 0) {
                    is_shell_script = 1;
                    // Insertamos "bash" como primer argumento
                    cmds[i].FAndVal[cmds[i].TotalArgs] = strdup("bash");
                    cmds[i].TotalArgs += 1;
                }
            }

            // Creamos la copia
            cmds[i].FAndVal[cmds[i].TotalArgs] = strdup(real_arg_substring);
            cmds[i].TotalArgs += 1;
            
            // Ahora pasamos a la siguiente palabra
            real_arg_substring = strtok_r(NULL, " \t\n", &saveptr_args_real);
        }
        
        // El último puntero debe ser NULL para execvp
        cmds[i].FAndVal[cmds[i].TotalArgs] = NULL;
        
        if (cmds[i].TotalArgs > 0) {
            cmds[i].Command = cmds[i].FAndVal[0];
            // Si insertamos bash, el comando a ejecutar es "bash", no el script
            if (is_shell_script) {
                 // execvp buscará "bash" en el PATH
            }
        }

        i += 1;
        // Pasamos al siguiente comando (Osea el siguiente substring separado por el pipe) 
        current_cmd_substring = strtok_r(NULL, "|", &saveptr_main);
    }

    *count = cmd_capacity;
    return cmds;
}

// Entradas: 
//    FunctionsCommand *commands: Arreglo de estructuras con los comandos a ejecutar.
//    int count: Cantidad total de comandos en el arreglo.
// Salidas: 
//    No retorna valor (void).
// Descripción: 
//    Itera sobre la lista de comandos creando un proceso hijo (fork) para cada uno.
//    Configura los pipes (tuberías) para conectar la salida estándar (stdout) de un proceso
//    con la entrada estándar (stdin) del siguiente, y ejecuta los comandos mediante execvp.
void execute_pipeline(FunctionsCommand *commands, int count) {
    int i = 0; 
    int pipefd[2];
    int prev_pipe_read = -1;

    while (i < count) {
        // Si no es el último comando, creamos un pipe
        if (i < count - 1) {
            if (pipe(pipefd) == -1) {
                perror("Error pipe");
                exit(1);
            }
        }

        // Creamos un nuevo proceso
        pid_t pid = fork();
        if (pid == -1) {
            perror("Error fork");
            exit(1);
        }

        if (pid == 0) { // Validamos si es un proceso hijo
            
            // Si hay un pipe anterior lo conectamos a la entrada
            if (prev_pipe_read != -1) {
                dup2(prev_pipe_read, STDIN_FILENO);
                close(prev_pipe_read);
            }
            
            // Ahora, si hay un pipe siguiente lo conectamos pero con la salida
            if (i < count - 1) {
                close(pipefd[0]); // Cerramos el pipe actual (lectura)
                dup2(pipefd[1], STDOUT_FILENO);
                close(pipefd[1]); // Cerramos escritura después de duplicar
            }

            // Con esto ejecutamos el comando
            execvp(commands[i].Command, commands[i].FAndVal);
            
            // Manejo de errores, si execvp falla
            perror("Error execvp");
            exit(1);

        } else { // Ahora bien, si el proceso es el padre

            // Cerrar el pipe que venia de antes (El que ya uso el hijo)
            if (prev_pipe_read != -1) {
                close(prev_pipe_read); // Cerramos el lado de lectura del pipe anterior
            }
            
            // Guardar el lado de lectura del pipe del padre para el siguiente hijo
            if (i < count - 1) {
                prev_pipe_read = pipefd[0];
                close(pipefd[1]); // El padre no escribe en el pipe
            }
        }
        i += 1; 
    }

    // Esperamos a todos los hijos
    i = 0;
    while (i < count) {
        wait(NULL);
        i += 1;
    }
}

// Entradas: 
//    FunctionsCommand *commands: Arreglo de estructuras de comandos.
//    int count: Cantidad de comandos.
// Salidas: 
//    No retorna valor (void).
// Descripción: 
//    Libera toda la memoria dinámica reservada previamente. Esto incluye las cadenas de caracteres
//    individuales de los argumentos, los arreglos de punteros y el arreglo de estructuras principal.
void free_memory(FunctionsCommand *commands, int count) {
    int i = 0;
    while (i < count) {
        int j = 0;
        // Liberamos cada string dentro del array de flags y valores 
        while (j < commands[i].TotalArgs) {
            free(commands[i].FAndVal[j]);
            j += 1;
        }
        // Liberamos el array de punteros
        free(commands[i].FAndVal);
        i += 1;
    }
    // Y acá liberamos el array de estructuras principal
    free(commands);
}