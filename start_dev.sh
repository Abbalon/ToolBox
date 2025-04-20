#!/bin/bash

# Script para iniciar el entorno de desarrollo local usando Docker Compose

PROJECT_ROOT=$(pwd) # Asume que se ejecuta desde la raíz del proyecto

echo "================================================="
echo " Iniciando Entorno de Desarrollo Local"
echo " Proyecto en: $PROJECT_ROOT"
echo "================================================="

# --- Prerrequisitos ---
echo "[1/4] Verificando Docker..."
if ! command -v docker &> /dev/null; then
    echo "ERROR: Docker no está instalado o no se encuentra en el PATH."
    echo "Por favor, instala Docker: https://docs.docker.com/get-docker/"
    exit 1
fi
docker --version

echo "[2/4] Verificando Docker Compose..."
# Docker Compose v2 ahora es parte del plugin `docker compose`
if ! docker compose version &> /dev/null; then
     # Comprobar la versión v1 independiente como fallback (aunque está obsoleta)
     if ! command -v docker-compose &> /dev/null; then
        echo "ERROR: Docker Compose (plugin v2 o v1 standalone) no está instalado o no se encuentra."
        echo "Recomendado: Instala Docker Desktop o sigue las instrucciones para Docker Compose v2."
        echo "Info: https://docs.docker.com/compose/install/"
        exit 1
     else
        echo "Advertencia: Usando docker-compose v1 (obsoleto). Se recomienda actualizar a v2 (plugin 'docker compose')."
        COMPOSE_CMD="docker-compose"
     fi
else
    COMPOSE_CMD="docker compose" # Usar el comando v2
fi
$COMPOSE_CMD version

# --- Configuración ---
echo "[3/4] Verificando archivo de configuración .env..."
if [ ! -f "$PROJECT_ROOT/.env" ]; then
    echo "ADVERTENCIA: No se encontró el archivo .env en $PROJECT_ROOT."
    echo "Se recomienda crear un archivo .env con la configuración local."
    echo "Puedes copiar '.env.example' si existe: cp .env.example .env"
    read -p "¿Continuar sin .env? (s/N): " confirm_env
    if [[ ! "$confirm_env" =~ ^[Ss]$ ]]; then
        echo "Operación cancelada. Por favor, crea el archivo .env."
        exit 1
    fi
else
    echo "Archivo .env encontrado."
    # Podrías añadir una validación básica de variables aquí si quisieras
fi

# --- Arranque ---
echo "[4/4] Iniciando servicios con Docker Compose..."
echo "Usando comando: '$COMPOSE_CMD up --build -d'"
echo "  --build : Reconstruye imágenes si los Dockerfiles o el contexto cambiaron."
echo "  -d      : Ejecuta en modo detached (segundo plano)."
echo "Puede tardar un poco la primera vez o si se reconstruyen imágenes..."

# Ejecutar Docker Compose
$COMPOSE_CMD up --build -d

# Verificar estado (opcional pero útil)
echo "-------------------------------------------------"
echo "Verificando estado de los contenedores..."
$COMPOSE_CMD ps
echo "-------------------------------------------------"

# Instrucciones post-arranque con Consul
echo "¡Entorno local iniciado con Consul!"
echo "-------------------------------------------------"
echo "Servicios:"
$COMPOSE_CMD ps
echo "-------------------------------------------------"
echo "Consul está accesible en http://localhost:8500 (contenedor 'consul')."
echo "Tus microservicios deberían estar configurados para registrarse en Consul."
echo "-------------------------------------------------"
echo "Puedes ver los logs de Consul con: '$COMPOSE_CMD logs -f consul'"
echo "Para ver los logs de un microservicio: '$COMPOSE_CMD logs -f [nombre_servicio]'"
echo "Para detener el entorno, ejecuta: './stop_dev.sh' o '$COMPOSE_CMD down'"
echo "El frontend debería estar accesible en http://localhost:8080 (o el puerto que hayas configurado)"
echo "La API Gateway en http://localhost:5000 (o el puerto configurado)"
echo "El microservicio '${SERVICE_NAME}' debería estar accesible en http://localhost:5001 (o el puerto configurado)"

exit 0