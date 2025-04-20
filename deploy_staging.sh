#!/bin/bash

# Script CONCEPTUAL para desplegar/actualizar en Staging usando Docker Compose

# --- Variables (Deberían ser parámetros o configuradas de forma segura) ---
STAGING_SERVER="user@staging.miempresa.com"
PROJECT_DIR="/srv/app/simple-ecommerce" # Directorio en el servidor de staging
ENV_FILE_PATH="$PROJECT_DIR/staging.env" # Archivo de entorno en el servidor
BRANCH="develop" # Rama de Git a desplegar

echo "================================================="
echo " Desplegando a Staging ($STAGING_SERVER)"
echo " Rama: $BRANCH"
echo "================================================="

# Comandos a ejecutar remotamente vía SSH
SSH_COMMANDS=$(cat <<EOF
  echo "[1/5] Navegando a $PROJECT_DIR";
  cd "$PROJECT_DIR" || { echo "ERROR: No se pudo acceder a $PROJECT_DIR"; exit 1; };

  echo "[2/5] Obteniendo últimos cambios de Git (Rama: $BRANCH)";
  git checkout $BRANCH || { echo "ERROR: No se pudo cambiar a la rama $BRANCH"; exit 1; };
  git pull origin $BRANCH || { echo "ERROR: Falló git pull"; exit 1; };

  echo "[3/5] Verificando archivo de entorno $ENV_FILE_PATH";
  if [ ! -f "$ENV_FILE_PATH" ]; then
      echo "ERROR: Archivo de entorno $ENV_FILE_PATH no encontrado en el servidor.";
      exit 1;
  fi;

  # Determinar comando compose en el servidor remoto (simplificado)
  if docker compose version &> /dev/null; then
      COMPOSE_CMD="docker compose";
  elif command -v docker-compose &> /dev/null; then
      COMPOSE_CMD="docker-compose";
  else
      echo "ERROR: Docker Compose no encontrado en $STAGING_SERVER";
      exit 1;
  fi;

  echo "[4/5] Deteniendo servicios anteriores (si existen)";
  \$COMPOSE_CMD --env-file "$ENV_FILE_PATH" down; # No usar -v para mantener datos

  echo "[5/5] Iniciando/Actualizando servicios";
  # Añadir --pull si se usan imágenes pre-construidas de un registry
  \$COMPOSE_CMD --env-file "$ENV_FILE_PATH" up --build -d || { echo "ERROR: Falló docker compose up"; exit 1; };

  echo "-------------------------------------------------";
  echo "Estado de los contenedores en Staging:";
  \$COMPOSE_CMD --env-file "$ENV_FILE_PATH" ps;
  echo "-------------------------------------------------";
  echo "¡Despliegue a Staging completado!";
EOF
)

# Ejecutar comandos en el servidor remoto
echo "Ejecutando comandos en $STAGING_SERVER..."
ssh -T "$STAGING_SERVER" bash -c "'$SSH_COMMANDS'" # Cuidado con las comillas anidadas

if [ $? -eq 0 ]; then
    echo "Script remoto ejecutado con éxito."
else
    echo "ERROR: Falló la ejecución remota en $STAGING_SERVER."
    exit 1
fi

exit 0