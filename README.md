# Integrantes: Marco Ortiz - 21361620-K, Nicolás Rojas - 21602113-4.

Pasos a realizar para la correcta ejecución del código.
Paso:
1) Debe encontrarse en la carpeta con nombre "21361620k_216021134".
2) Abrir una terminal desde la carpeta en el paso anterior.
3) Ejecutar el comando "chmod +x *.sh". Esto nos dará los permisos suficientes para ejecutar correctamente los archivos .sh solicitados en la entrega anterior.
4) Luego, ejecutar el comando "make clean", esto para eliminar cualquier archivo "residual" que pueda haber previamente.
5) Luego, ejecutar el comando "make", esto lo que hará será compilar los correspondientes archivos (Dentro de los cuales se creará el ejecutable del código principal lab2.c)
6) Finalmente ejecutar el comando (*) por consola.

(*) El comando (A modo de ejemplo) es el siguiente:

    ./lab2 ./generator.sh -i 5 -t 5 \
    | ./preprocess.sh \
    | ./filter.sh -c 2 \
    | ./transform.sh --anon-uid \
    | ./aggregate.sh \
    | ./report.sh -o Ejemplo.csv
 
Como rellenar cada parámetro:

    generator.sh -i 1 -t 3 -l logs/generator.txt \
    |  preprocessor.sh --iso8601 -l logs/preprocess.txt \
    |  filter.sh -c 0.1 -m 0.1 -l logs/filter.txt \
    |  transform.sh --anon-uid -l logs/transform.txt \
    |  aggregate.sh -l logs/aggregate.txt \
    |  report.sh -o reporte.csv

- generator.sh -i (Ingresar un numero entero y positivo) -t (Ingresar un numero entero y positivo)
-  preprocessor.sh --iso8601 (Este ultimo es un parametro opcional, refiriéndose a ingresar --iso8601 o no)
-  filter.sh -c (Ingresar la CPU mínima) -m (Ingresar la memoria mínima) -r (Ingresar una expresión regular sobre el nombre de 		comando) 
-  transform.sh --anon-uid (Al ingresar "--anon-unid" anonimiza el UID con un hash dejando el resto intacto)
-  aggregate.sh (No se ingresa ningún parámetro. Su función es agrupar por comando. Calcula: número de procesos, CPU promedio,
CPU máxima, MEM promedio y MEM máxima)
-  report.sh -o (Acá se va a generar un reporte, por lo que en este campo se debe ingresar el nombre para dicho reporte, además de ingresar el tipo de formato de reporte, puede ser .tsv o .csv)