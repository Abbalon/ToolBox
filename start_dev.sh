#!/bin/bash

# Script para iniciar el entorno de desarrollo local usando Docker Compose

PROJECT_ROOT=$(pwd) # Asume que se ejecuta desde la raíz del proyecto

# --- Helper Functions ---
info() {
  echo -e "\e[1;34mINFO:\e[0m $1"
}

error() {
  echo -e "\e[1;31mERROR:\e[0m $1"
}

success() {
  echo -e "\e[1;32mSUCCESS:\e[0m $1"
}

info "================================================="
info " Iniciando Entorno de Desarrollo Local"
info " Proyecto en: $PROJECT_ROOT"
info "================================================="

# --- Prerrequisitos ---
info "[1/4] Verificando Docker..."
if ! command -v docker &> /dev/null; then
    error "Docker no está instalado o no se encuentra en el PATH."
    info "Por favor, instala Docker: https://docs.docker.com/get-docker/"
    exit 1
fi
docker --version

info "[2/4] Verificando Docker Compose..."
# Docker Compose v2 ahora es parte del plugin `docker compose`
if ! docker compose version &> /dev/null; then
     # Comprobar la versión v1 independiente como fallback (aunque está obsoleta)
     if ! command -v docker-compose &> /dev/null; then
        error "Docker Compose (plugin v2 o v1 standalone) no está instalado o no se encuentra."
        info "Recomendado: Instala Docker Desktop o sigue las instrucciones para Docker Compose v2."
        info "Info: https://docs.docker.com/compose/install/"
        exit 1
     else
        info "Advertencia: Usando docker-compose v1 (obsoleto). Se recomienda actualizar a v2 (plugin 'docker compose')."
        COMPOSE_CMD="docker-compose"
     fi
else
    COMPOSE_CMD="docker compose" # Usar el comando v2
fi
$COMPOSE_CMD version

# --- Configuración ---
info "[3/4] Verificando archivo de configuración .env..."
if [ ! -f "$PROJECT_ROOT/.env" ]; then
    info "ADVERTENCIA: No se encontró el archivo .env en $PROJECT_ROOT."
    info "Se recomienda crear un archivo .env con la configuración local."
    info "Puedes copiar '.env.example' si existe: cp .env.example .env"
    read -p "¿Continuar sin .env? (s/N): " confirm_env
    if [[ ! "$confirm_env" =~ ^[Ss]$ ]]; then
        error "Operación cancelada. Por favor, crea el archivo .env."
        exit 1
    fi
else
    info "Archivo .env encontrado."
    # Podrías añadir una validación básica de variables aquí si quisieras
fi

# --- Arranque ---
info "[4/4] Iniciando servicios con Docker Compose..."
info "Usando comando: '$COMPOSE_CMD up --build -d'"
info "  --build : Reconstruye imágenes si los Dockerfiles o el contexto cambiaron."
info "  -d      : Ejecuta en modo detached (segundo plano)."
info "Puede tardar un poco la primera vez o si se reconstruyen imágenes..."

# Ejecutar Docker Compose
$COMPOSE_CMD up --build -d

# Verificar estado (opcional pero útil)
info "-------------------------------------------------"
info "Verificando estado de los contenedores..."
$COMPOSE_CMD ps
info "-------------------------------------------------"

# Instrucciones post-arranque con Consul
success "¡Entorno local iniciado con Consul!"
info "-------------------------------------------------"
info "Servicios:"
$COMPOSE_CMD ps
info "-------------------------------------------------"
success "Consul está accesible en http://localhost:8500 (contenedor 'consul')."
info "Tus microservicios deberían estar configurados para registrarse en Consul."
info "-------------------------------------------------"
info "Puedes ver los logs de Consul con: '$COMPOSE_CMD logs -f consul'"
info "Para ver los logs de un microservicio: '$COMPOSE_CMD logs -f [nombre_servicio]'"
info "Para detener el entorno, ejecuta: './stop_dev.sh' o '$COMPOSE_CMD down'"
success "El frontend debería estar accesible en http://localhost:8080 (o el puerto que hayas configurado)"
success "La API Gateway en http://localhost:5000 (o el puerto configurado)"
success "El microservicio '${SERVICE_NAME}' debería estar accesible en http://localhost:5001 (o el puerto configurado)"

exit 0