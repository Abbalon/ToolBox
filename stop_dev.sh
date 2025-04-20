#!/bin/bash

# Script para detener el entorno de desarrollo local

PROJECT_ROOT=$(pwd) # Asume que se ejecuta desde la raíz del proyecto

echo "================================================="
echo " Deteniendo Entorno de Desarrollo Local"
echo " Proyecto en: $PROJECT_ROOT"
echo "================================================="

# Determinar comando de compose
if docker compose version &> /dev/null; then
    COMPOSE_CMD="docker compose"
elif command -v docker-compose &> /dev/null; then
    COMPOSE_CMD="docker-compose"
else
    echo "ERROR: No se encontró Docker Compose (v2 o v1)."
    exit 1
fi

echo "Usando comando: '$COMPOSE_CMD down'"
echo "Esto detendrá y eliminará los contenedores definidos en docker-compose.yml."
echo "Los volúmenes con datos persistentes (BBDD, etcd) NO se eliminarán por defecto."
echo "(Para eliminar volúmenes, usa: '$COMPOSE_CMD down -v')"

$COMPOSE_CMD down

echo "-------------------------------------------------"
echo "Estado de los contenedores después de detener:"
# Puede que no muestre nada si 'down' los eliminó, es normal.
$COMPOSE_CMD ps
echo "-------------------------------------------------"
echo "¡Entorno local detenido!"

exit 0