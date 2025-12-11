# Ingredientes: Marco Ortiz - 21361620-K, Nicolás Rojas - 21602113-4.

# Compilador a usar
CC = gcc

# Flags de compilación:
# -Wall -Wextra: Activan todas las advertencias.
# -g: Agrega información de depuración (útil para usar valgrind).
CFLAGS = -Wall -Wextra -g

# Regla por defecto
all: lab2

# Depende de los archivos objeto (.o)
lab2: lab2.o funciones.o
	$(CC) $(CFLAGS) -o lab2 lab2.o funciones.o

# Depende de lab2.c y funciones.h
lab2.o: lab2.c funciones.h
	$(CC) $(CFLAGS) -c lab2.c

# Depende de funciones.c y funciones.h
funciones.o: funciones.c funciones.h
	$(CC) $(CFLAGS) -c funciones.c

# Regla para limpiar archivos generados (para reiniciar la compilación)
clean:
	rm -f *.o lab2