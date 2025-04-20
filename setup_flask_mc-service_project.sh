#!/bin/bash

# Script para crear la ESTRUCTURA DE INFRAESTRUCTURA BASE
# para una aplicación de comercio electrónico simple basada en microservicios.
#
# Este script configura:
# - Directorio raíz del proyecto.
# - Archivos informativos básicos (README, .gitignore).
# - Scripts de gestión y despliegue (dev, staging, prod).
# - Un Makefile para comandos comunes.
# - Estructura para componentes compartidos (Frontend, Gateway, Discover).
# - Un docker-compose.yml base con la infraestructura compartida.
#
# Los microservicios específicos (Products, Clients, Orders, etc.)
# se añadirán DESPUÉS usando el script 'create_microservice.sh'.

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

info "====================================================="
info " Creando Infraestructura Base para Proyecto Microservicios"
info "====================================================="

# --- Configuración ---
PARENT_DIR="$(dirname "$(pwd)")"
PROJECT_NAME="simple_ecommerce_app"
PROJECT_DIR="$PARENT_DIR/$PROJECT_NAME"
SCRIPTS_DIR="scripts" # Directorio para guardar los scripts de gestión

# --- Creación Directorio Raíz ---
if [ -d "$PROJECT_DIR" ]; then
  info "Advertencia: El directorio '$PROJECT_DIR' ya existe."
  read -p "¿Continuar y potencialmente sobrescribir archivos de configuración base? (s/N): " confirm
  if [[ ! "$confirm" =~ ^[Ss]$ ]]; then
    error "Operación cancelada."
    exit 1
  fi
else
  mkdir "$PROJECT_DIR" || { error "No se pudo crear el directorio $PROJECT_DIR"; exit 1; }
  cd "$PROJECT_DIR" || exit 1
fi
cd "$PROJECT_DIR" || exit 1
info "Directorio raíz del proyecto '$PROJECT_DIR' creado/seleccionado."
info "-----------------------------------------------------"

# --- Archivos Raíz Básicos ---
info "Creando archivos raíz (.gitignore, README.md, .env.example)..."

# .gitignore
cat << EOF > .gitignore
# Byte-compiled / optimized / DLL files
__pycache__/
*.py[cod] # Combina *.pyc, *.pyo, *.pyd implícitamente en algunos sistemas, pero añadimos *.pyd explícitamente abajo
*.pyd # Específico de C extensions en Windows
*$py.class

# C extensions
*.so

# Distribution / packaging
.Python
build/
develop-eggs/
dist/
downloads/
eggs/
.eggs/
lib/
lib64/
parts/
sdist/
var/
wheels/
*.egg-info/
.installed.cfg
*.egg
MANIFEST

# PyInstaller
# Usually these files are written by a python script from a template
# before PyInstaller builds the exe, so as to inject date/other infos into it.
*.manifest
*.spec

# Installer logs
pip-log.txt
pip-delete-this-directory.txt

# Unit test / coverage reports
htmlcov/
.tox/
.nox/
.coverage
.coverage.*
.cache
nosetests.xml
coverage.xml
*.cover
*.py,cover
.hypothesis/
.pytest_cache/
cover/

# Translations
*.mo
*.pot

# Django stuff:
local_settings.py

# Flask stuff:
instance/
.webassets-cache

# Scrapy stuff:
.scrapy

# Sphinx documentation
docs/_build/

# PyBuilder
target/

# Jupyter Notebook
.ipynb_checkpoints

# IPython
profile_default/
ipython_config.py

# PEP 582; __pypackages__
__pypackages__/

# Celery stuff
celerybeat-schedule

# SageMath parsed files
*.sage.py

# Environments
.env
.venv
env/
venv/
ENV/
env.bak/
venv.bak/
.env.docker

# Spyder project settings
.spyderproject
.spyproject

# Rope project settings
.ropeproject

# mkdocs documentation
/site

# mypy
.mypy_cache/
.dmypy.json
dmypy.json

# Pyre type checker
.pyre/

# pytype static analysis results
.pytype/

# Cython debug symbols
cython_debug/

# Operating System Files
.DS_Store
Thumbs.db

# IDE / Editor Files
.vscode/
.idea/
*.swp
*~

# Bases de Datos locales
*.sqlite3
*.db
db.sqlite3-journal

# Log files
*.log

# Runtime / Process IDs / Docker specific
*.pid
celerybeat.pid # De Celery stuff (movido aquí)
docker-compose.override.yml

# Local configuration files not usually versioned
*.local
EOF

# README.md (Raíz)
cat << EOF > README.md
# Simple Ecommerce App - Proyecto de Microservicios

Este proyecto implementa una aplicación de comercio electrónico simple utilizando una arquitectura de microservicios.

## Estructura del Proyecto

*   \`frontend_web/\`: Microservicio encargado de la interfaz de usuario (Flask).
*   \`gateway/\`: API Gateway (Placeholder - necesita configuración/implementación). Actúa como punto de entrada.
*   \`discover_service/\`: Servicio de Descubrimiento (Placeholder - configurado para usar Consul en Docker Compose).
*   \`scripts/\`: Contiene scripts para gestión del ciclo de vida (dev, staging, prod) y creación de nuevos servicios.
*   \`docker-compose.yml\`: Define la infraestructura base (Frontend, Gateway, Consul) y la red compartida.
*   \`Makefile\`: Proporciona comandos rápidos para tareas comunes.
*   \`.env.example\`: Ejemplo de archivo de configuración de entorno. Copiar a \`.env\` y ajustar.
*   (Otros directorios de microservicios se añadirán aquí al crearlos con \`./scripts/create_microservice.sh\`)

## Requisitos

*   Docker & Docker Compose (v2 recomendado)
*   Python 3.10+ (para \`create_microservice.sh\` y desarrollo local)
*   Git
*   \`curl\`
*   \`make\` (opcional, para usar el Makefile)

## Inicio Rápido (Desarrollo Local)

1.  **Clonar el repositorio (si aplica).**
2.  **Copiar configuración de ejemplo:** \`cp .env.example .env\` (y ajustar si es necesario).
3.  **Iniciar entorno base:** \`make up\` o \`./scripts/start_dev.sh\`
4.  **Crear un nuevo microservicio:** \`make create-service\` o \`./scripts/create_microservice.sh --service-name <nombre> --entity-name <entidad> --db-type <db>\`
5.  **Integrar el nuevo microservicio:** Edita manualmente \`docker-compose.yml\` para añadir el nuevo servicio y su base de datos (copiando las definiciones del \`docker-compose.yml\` generado dentro del directorio del nuevo servicio).
6.  **Reiniciar el entorno:** \`make down && make up\` o \`./scripts/stop_dev.sh && ./scripts/start_dev.sh\`

## Comandos Makefile

*   \`make up\`: Inicia el entorno de desarrollo (docker compose up).
*   \`make down\`: Detiene el entorno de desarrollo (docker compose down).
*   \`make logs\`: Muestra los logs de todos los servicios.
*   \`make logs service=<nombre>\`: Muestra los logs de un servicio específico.
*   \`make ps\`: Muestra los contenedores en ejecución.
*   \`make create-service\`: Inicia el script para crear un nuevo microservicio.
*   \`make deploy-staging\`: Ejecuta el script de despliegue a Staging.
*   \`make deploy-prod\`: Ejecuta el script de despliegue a Producción (K8s).

## Próximos Pasos

*   Configurar/Implementar el API Gateway (\`gateway/\`).
*   Configurar/Implementar el Servicio de Descubrimiento (\`discover_service/\`) si no se usa Consul directamente.
*   Desarrollar la lógica del Frontend (\`frontend_web/\`).
*   Crear los microservicios necesarios usando \`create_microservice.sh\`.
*   Integrar los nuevos microservicios en el \`docker-compose.yml\` principal.
EOF

# .env.example (Raíz)
cat << EOF > .env.example
# Copia este archivo a .env y ajusta los valores según sea necesario

# --- Configuración General ---
# SECRET_KEY=tu_clave_secreta_aqui # Ejemplo para Flask

# --- URLs de Servicios (Usadas por Frontend/Gateway) ---
# Estas URLs apuntan a los nombres de servicio definidos en docker-compose.yml
# GATEWAY_INTERNAL_URL=http://gateway:5000 # Usado por Frontend
# PRODUCTS_INTERNAL_URL=http://products_service:5001 # Usado por Gateway
# CLIENTS_INTERNAL_URL=http://clients_service:5002 # Usado por Gateway

# --- Configuración Consul (Usado por register_consul.py en cada servicio) ---
CONSUL_HOST=consul
CONSUL_PORT=8500

# --- Configuración Base de Datos (Ejemplos - Añadir por servicio) ---
# Se definirán variables específicas por servicio en sus propios .env o aquí
# Ejemplo para un servicio 'orders' con Postgres:
# DATABASE_URL_ORDERS=postgresql://appuser:password@postgres_orders_service:5432/orders_service_db

EOF

# CHANGELOG.md (Opcional)
cat << EOF > CHANGELOG.md
# Changelog

Todas las cambios notables de este proyecto serán documentados en este archivo.

El formato está basado en [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
y este proyecto adhiere a [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased] - YYYY-MM-DD

### Added
-   Endpoint para búsqueda de productos por categoría en `products-service`.

### Changed
### Deprecated
### Removed
### Fixed
-   Corrección en la validación de emails durante el registro en `clients-service`.

### Security
## [1.0.0] - 2025-04-10

### Added
-   Lanzamiento inicial de la aplicación con funcionalidades básicas:
    -   Microservicios: Frontend, Gateway, Discover, Products, Clients.
    * Gestión de catálogo de productos (CRUD básico).
    * Registro y autenticación de clientes (JWT).
    * Descubrimiento de servicios con etcd.
    * Despliegue básico con Docker Compose para desarrollo.

## [0.1.0] - 2025-03-15

### Added
-   Configuración inicial del proyecto.
-   Estructura de directorios para microservicios.
-   Implementación básica del servicio `discover-service` con Flask y etcd.
-   Dockerfile inicial para `discover-service`.
EOF

info "Archivos raíz creados."
info "-----------------------------------------------------"

# --- Directorio de Scripts ---
info "Creando directorio de scripts y copiando scripts de gestión..."
mkdir -p "$SCRIPTS_DIR"

# Copiar los scripts existentes (asumiendo que están en el mismo directorio que setup_ecommerce.sh)
SCRIPT_SOURCE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

cp "$SCRIPT_SOURCE_DIR/start_dev.sh" "$SCRIPTS_DIR/" || error "Advertencia: No se pudo copiar start_dev.sh"
cp "$SCRIPT_SOURCE_DIR/stop_dev.sh" "$SCRIPTS_DIR/" || error "Advertencia: No se pudo copiar stop_dev.sh"
cp "$SCRIPT_SOURCE_DIR/deploy_staging.sh" "$SCRIPTS_DIR/" || error "Advertencia: No se pudo copiar deploy_staging.sh"
cp "$SCRIPT_SOURCE_DIR/deploy_prod_k8s.sh" "$SCRIPTS_DIR/" || error "Advertencia: No se pudo copiar deploy_prod_k8s.sh"
cp "$SCRIPT_SOURCE_DIR/create_microservice.sh" "$SCRIPTS_DIR/" || error "Advertencia: No se pudo copiar create_microservice.sh"

# Hacer scripts ejecutables
chmod +x "$SCRIPTS_DIR"/*.sh

info "Scripts copiados a '$SCRIPTS_DIR/'."
info "-----------------------------------------------------"

# --- Estructura Componentes Compartidos ---

# Frontend Web (Simplificado)
info "Creando estructura base para: Frontend Web"
FRONTEND_DIR="frontend_web"
mkdir -p "$FRONTEND_DIR/templates" "$FRONTEND_DIR/static/css" "$FRONTEND_DIR/static/js"
touch "$FRONTEND_DIR/app.py" \
      "$FRONTEND_DIR/requirements.txt" \
      "$FRONTEND_DIR/Dockerfile" \
      "$FRONTEND_DIR/templates/index.html" \
      "$FRONTEND_DIR/static/css/style.css"

# requirements.txt (Frontend)
echo "Flask" > "$FRONTEND_DIR/requirements.txt"
echo "requests # Para comunicarse con el Gateway" >> "$FRONTEND_DIR/requirements.txt"

# app.py (Frontend - Placeholder)
cat << EOF > "$FRONTEND_DIR/app.py"
import os
from flask import Flask, render_template, jsonify
import requests

app = Flask(__name__)
# Usar variable de entorno para la URL del Gateway
GATEWAY_URL = os.environ.get('GATEWAY_INTERNAL_URL', 'http://gateway:5000')

@app.route('/')
def index():
    # Ejemplo: Intentar obtener algo del gateway (fallará si gateway no está listo/configurado)
    try:
        # Ejemplo: Obtener productos a través del gateway
        # response = requests.get(f'{GATEWAY_URL}/api/products', timeout=5)
        # response.raise_for_status() # Lanza excepción si hay error HTTP
        # products = response.json()
        products = [{"name": "Producto Ejemplo 1 (desde Frontend)"}, {"name": "Producto Ejemplo 2 (desde Frontend)"}] # Datos de prueba
    except requests.exceptions.RequestException as e:
        print(f"Error al contactar Gateway: {e}")
        products = [] # Mostrar vacío o mensaje de error
    return render_template('index.html', products=products)

@app.route('/health')
def health_check():
    # Health check básico para el frontend
    return jsonify({"status": "OK", "service": "frontend-web"}), 200

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=8080) # Puerto interno del contenedor
EOF

# Dockerfile (Frontend)
cat << EOF > "$FRONTEND_DIR/Dockerfile"
FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 8080

CMD ["python", "app.py"]
EOF

# index.html (Frontend - Placeholder)
cat << EOF > "$FRONTEND_DIR/templates/index.html"
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <title>Simple Ecommerce</title>
    <link rel="stylesheet" href="{{ url_for('static', filename='css/style.css') }}">
</head>
<body>
    <h1>Bienvenido a Simple Ecommerce</h1>
    <p>Interfaz de Usuario (Frontend Web)</p>
    <h2>Productos (Ejemplo)</h2>
    <ul>
        {% for product in products %}
            <li>{{ product.name }}</li>
        {% else %}
            <li>No se pudieron cargar los productos.</li>
        {% endfor %}
    </ul>
    <script src="{{ url_for('static', filename='js/script.js') }}"></script>
</body>
</html>
EOF

touch "$FRONTEND_DIR/static/css/style.css"
touch "$FRONTEND_DIR/static/js/script.js"

info "Estructura de Frontend Web creada."
info "-----------------------------------------------------"

# Gateway (Placeholder)
info "Creando estructura base para: Gateway"
GATEWAY_DIR="gateway"
mkdir -p "$GATEWAY_DIR/config"
touch "$GATEWAY_DIR/README.md" \
      "$GATEWAY_DIR/Dockerfile" \
      "$GATEWAY_DIR/config/nginx.conf" # Ejemplo si se usa Nginx como base

# README.md (Gateway)
cat << EOF > "$GATEWAY_DIR/README.md"
# API Gateway Placeholder

Este directorio contiene la configuración/código para el API Gateway.

**Responsabilidades:**
*   Punto único de entrada.
*   Enrutamiento a microservicios backend (usando Service Discovery).
*   Autenticación/Autorización.
*   Rate Limiting, Caching, etc.

**Implementación:**
*   Puedes usar una solución existente (Kong, Tyk, Traefik, etc.).
*   Puedes implementar uno personalizado (e.g., usando Flask/FastAPI y Nginx).
*   El Dockerfile y \`nginx.conf\` actuales son solo un *placeholder* básico usando Nginx como reverse proxy simple. Necesitará configuración avanzada para un gateway real (descubrimiento de servicios, autenticación, etc.).
EOF

# Dockerfile (Gateway - Nginx Placeholder)
cat << EOF > "$GATEWAY_DIR/Dockerfile"
# Placeholder Dockerfile para un Gateway basado en Nginx
FROM nginx:alpine

# Copia la configuración personalizada de Nginx
COPY config/nginx.conf /etc/nginx/nginx.conf

# Exponer puerto (e.g., 5000)
EXPOSE 5000

# Nginx se inicia automáticamente
EOF

# nginx.conf (Gateway - Placeholder Básico)
cat << EOF > "$GATEWAY_DIR/config/nginx.conf"
worker_processes 1;

events {
    worker_connections 1024;
}

http {
    # Configuración básica de Nginx

    server {
        listen 5000; # Puerto interno del gateway

        location / {
            # Placeholder: Redirigir a frontend o mostrar mensaje
            # En un gateway real, aquí irían las reglas de enrutamiento
            # basadas en el path, host, etc., hacia los servicios backend.
            # Ejemplo MUY básico (requiere configurar DNS interno de Docker):
            # proxy_pass http://frontend_web:8080;

            # Mensaje temporal:
            return 200 'API Gateway Placeholder - Necesita configuración\n';
            add_header Content-Type text/plain;
        }

        location /api/products {
             # Placeholder para enrutar a products_service
             # Necesita resolución de nombres (Consul DNS) o configuración dinámica
             # resolver 127.0.0.11 valid=10s; # Usar DNS interno de Docker
             # set \$products_service products_service; # Nombre del servicio en Docker Compose
             # proxy_pass http://\$products_service:5001; # Puerto interno del servicio
             return 200 'Ruta /api/products - Enrutar a Products Service\n';
             add_header Content-Type text/plain;
        }

         location /api/clients {
             # Placeholder para enrutar a clients_service
             # resolver 127.0.0.11 valid=10s;
             # set \$clients_service clients_service;
             # proxy_pass http://\$clients_service:5002;
             return 200 'Ruta /api/clients - Enrutar a Clients Service\n';
             add_header Content-Type text/plain;
        }

        location /health {
            # Health check para el gateway mismo
            return 200 'OK';
            add_header Content-Type text/plain;
        }
    }
}
EOF

info "Estructura de Gateway creada."
info "-----------------------------------------------------"

# Discover Service (Placeholder - Asume Consul en Docker Compose)
info "Creando estructura base para: Discover Service"
DISCOVER_DIR="discover_service"
mkdir -p "$DISCOVER_DIR"
touch "$DISCOVER_DIR/README.md"

# README.md (Discover)
cat << EOF > "$DISCOVER_DIR/README.md"
# Discover Service Placeholder

Este directorio es un placeholder para la configuración o código relacionado con el servicio de descubrimiento.

**Responsabilidad:** Permitir que los servicios se encuentren dinámicamente en la red.

**Implementación:**
*   El archivo \`docker-compose.yml\` principal ya incluye un servicio **Consul** (\`discover\`) que actúa como el servicio de descubrimiento.
*   Los microservicios generados por \`create_microservice.sh\` incluyen un script (\`register_consul.py\`) para registrarse en este servicio Consul.
*   Si eligieras otra tecnología (Eureka, Zookeeper, etcd), necesitarías configurar los clientes correspondientes en cada microservicio y potencialmente un servidor aquí o en Docker Compose.
*   Este directorio podría usarse para configuraciones específicas de Consul si fueran necesarias (montadas como volumen en el contenedor de Consul).
EOF
info "Estructura de Discover Service creada."
info "-----------------------------------------------------"

# --- Docker Compose Base ---
info "Creando archivo docker-compose.yml base..."
cat << EOF > docker-compose.yml
version: '3.8'

networks:
  ecommerce_net:
    driver: bridge

volumes:
  # Los volúmenes de datos se añadirán aquí cuando se creen los microservicios
  # con bases de datos persistentes.
  # Ejemplo: postgres_orders_data:
  # Ejemplo: mongo_products_data:
  consul_data: # Opcional: para persistir estado de Consul si es necesario

services:
  # --- Infraestructura Compartida ---

  discover:
    image: consul:1.16 # Usar una versión específica
    container_name: consul
    ports:
      - "8500:8500" # UI y API HTTP
      - "8600:8600/udp" # DNS
    volumes:
       - consul_data:/consul/data # Persistir datos de Consul (opcional)
    # Ejecutar en modo dev para fácil configuración inicial
    # Para producción, usar configuración de cluster más robusta
    command: "agent -dev -client=0.0.0.0 -ui -node=consul-dev"
    networks:
      - ecommerce_net
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8500/v1/status/leader"]
      interval: 10s
      timeout: 5s
      retries: 5

  gateway:
    build: ./gateway # Usa el Dockerfile placeholder de Nginx
    container_name: gateway
    ports:
      - "5000:5000" # Puerto principal expuesto para acceder a la aplicación
    networks:
      - ecommerce_net
    depends_on:
      discover:
        condition: service_healthy # Espera a que Consul esté listo
      # Añadir dependencias a servicios backend cuando se creen
    environment:
      # Variables para configurar el gateway (ej. URL de Consul para descubrimiento dinámico)
      - CONSUL_HTTP_ADDR=http://discover:8500
    healthcheck:
      test: ["CMD-SHELL", "wget -q --spider http://localhost:5000/health || exit 1"]
      interval: 15s
      timeout: 5s
      retries: 3
      start_period: 10s

  frontend:
    build: ./frontend_web
    container_name: frontend_web
    ports:
      - "8080:8080" # Puerto para acceder directamente al frontend (o solo a través del gateway)
    networks:
      - ecommerce_net
    depends_on:
      - gateway # El frontend habla con el gateway
    environment:
      # Pasa la URL interna del gateway al frontend
      - GATEWAY_INTERNAL_URL=http://gateway:5000
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 15s
      timeout: 5s
      retries: 3
      start_period: 10s

  # --- Microservicios Backend (Añadir aquí al crearlos) ---
  # Ejemplo de cómo se añadiría un servicio 'products':
  # products_service:
  #   build: ./products_service
  #   container_name: products_service
  #   # ports: # Generalmente no se exponen directamente, se accede via gateway
  #   #   - "5001:5001"
  #   env_file:
  #     - ./products_service/.env # Carga config específica del servicio
  #   environment:
  #     - SERVICE_ADDRESS=products_service # Nombre para registro en Consul
  #     # Añadir más variables si es necesario
  #   depends_on:
  #     discover:
  #       condition: service_healthy
  #     mongo_products: # Dependencia de su BBDD
  #       condition: service_healthy
  #   networks:
  #     - ecommerce_net
  #   healthcheck:
  #     test: ["CMD", "curl", "-f", "http://localhost:5001/health"] # Puerto interno
  #     interval: 15s
  #     timeout: 5s
  #     retries: 3
  #     start_period: 10s

  # --- Bases de Datos (Añadir aquí por servicio) ---
  # Ejemplo para el servicio 'products':
  # mongo_products:
  #   image: mongo:6.0
  #   container_name: mongo_products
  #   volumes:
  #     - mongo_products_data:/data/db
  #   networks:
  #     - ecommerce_net
  #   healthcheck:
  #      test: echo 'db.runCommand("ping").ok' | mongosh localhost:27017/products_service_db --quiet
  #      interval: 10s
  #      timeout: 5s
  #      retries: 5
  #      start_period: 10s

EOF
info "Archivo docker-compose.yml base creado."
info "-----------------------------------------------------"

# --- Makefile ---
info "Creando Makefile..."
cat << EOF > Makefile
# Makefile para gestionar el entorno de desarrollo y tareas comunes

# Detectar comando de Docker Compose
ifeq ($(shell docker compose version --short),)
  ifeq ($(shell docker-compose version --short),)
    COMPOSE_CMD=$(shell docker compose version > /dev/null 2>&1 && echo "docker compose" || echo "docker-compose")
  else
    COMPOSE_CMD = docker-compose
    
  endif
else
  COMPOSE_CMD = docker compose
endif

# Variables
PYTHON=python3
VENV_NAME=.venv
SCRIPTS_DIR = ./scripts

.PHONY: help up down logs ps create-service deploy-staging deploy-prod

help:
	@echo "Comandos disponibles:"
	@echo "  setup          : Crea entorno virtual e instala dependencias dev."
	@echo "  lint           : Ejecuta flake8 y black (modo check)."
	@echo "  format         : Formatea el código con black."
	@echo "  test           : Ejecuta pytest (necesita configuración adicional para microservicios)."
	@echo "  docker-build   : Construye las imágenes Docker de los servicios."
	@echo "  make up             : Inicia el entorno de desarrollo (docker compose up -d --build)."
	@echo "  make down           : Detiene el entorno de desarrollo (docker compose down)."
	@echo "  make logs           : Muestra los logs de todos los servicios."
	@echo "  make logs service=<nombre> : Muestra los logs de un servicio específico."
	@echo "  make ps             : Lista los contenedores en ejecución."
	@echo "  make create-service : Ejecuta el script para crear un nuevo microservicio."
	@echo "  make deploy-staging : Ejecuta el script de despliegue a Staging."
	@echo "  make deploy-prod    : Ejecuta el script de despliegue a Producción (K8s)."
	@echo "  clean          : Elimina archivos temporales y caché de Python."

setup: $(VENV_NAME)/bin/activate

$(VENV_NAME)/bin/activate: requirements-dev.txt
	test -d $(VENV_NAME) || $(PYTHON) -m venv $(VENV_NAME)
	$(VENV_NAME)/bin/pip install --upgrade pip
	$(VENV_NAME)/bin/pip install -r requirements-dev.txt
	touch $(VENV_NAME)/bin/activate # Marca como creado/actualizado

lint: setup
	@echo "Ejecutando Flake8..."
	$(VENV_NAME)/bin/flake8 . --count --show-source --statistics
	@echo "Comprobando formato con Black..."
	$(VENV_NAME)/bin/black --check .

format: setup
	@echo "Formateando código con Black..."
	$(VENV_NAME)/bin/black .

test: setup
	@echo "Ejecutando Pytest..."
	# Esto es simplificado. Necesitarías una forma de ejecutar tests
	# para cada microservicio o tests de integración que arranquen compose.
	# $(VENV_NAME)/bin/pytest
	@echo "NOTA: Target 'test' necesita implementación específica para microservicios."

docker-build:
	@echo "Construyendo imágenes Docker..."
	$(COMPOSE_CMD) build

up:
	@echo "Iniciando entorno de desarrollo..."
	@/start_dev.sh

down:
	@echo "Deteniendo entorno de desarrollo..."
	@/stop_dev.sh

# Target para logs generales y específicos
logs:
ifeq ($(service),)
	@echo "Mostrando logs de todos los servicios... (Ctrl+C para salir)"
	@$(COMPOSE_CMD) logs -f
else
	@echo "Mostrando logs del servicio $(service)... (Ctrl+C para salir)"
	@$(COMPOSE_CMD) logs -f $(service)
endif
# Capturar argumentos después de 'logs' para el nombre del servicio
# Ejemplo: make logs service=frontend
%:
	@:

ps:
	@echo "Contenedores en ejecución:"
	@ ps

create-service:
	@echo "Ejecutando script para crear un nuevo microservicio..."
	@/create_microservice.sh

deploy-staging:
	@echo "Ejecutando despliegue a Staging..."
	@/deploy_staging.sh

deploy-prod:
	@echo "Ejecutando despliegue a Producción (K8s)..."
	@/deploy_prod_k8s.sh

clean:
	@echo "Limpiando archivos temporales..."
	find . -type f -name '*.py[co]' -delete
	find . -type d -name '__pycache__' -delete
	find . -type d -name '.pytest_cache' -exec rm -rf {} +
	find . -type d -name '.mypy_cache' -exec rm -rf {} +
	rm -f .coverage*
	rm -rf htmlcov/
	rm -rf $(VENV_NAME)
EOF

info "Makefile creado."
info "-----------------------------------------------------"

# --- Mensaje Final ---
info ""
info "====================================================="
info " Infraestructura Base del Proyecto Creada Exitosamente"
info " Directorio: $(pwd)"
info "====================================================="
info " Próximos pasos recomendados:"
info " 1. Revisa y ajusta el archivo '.env.example' y cópialo a '.env'."
info " 2. Inicia la infraestructura base: 'make up' o './scripts/start_dev.sh'"
info "    - Verifica que Consul UI esté accesible en http://localhost:8500"
info "    - Verifica que el Frontend base esté en http://localhost:8080"
info "    - Verifica que el Gateway placeholder responda en http://localhost:5000"
info " 3. Usa 'make create-service' o './scripts/create_microservice.sh' para añadir tus microservicios."
info " 4. **IMPORTANTE:** Después de crear un servicio, edita manualmente 'docker-compose.yml'"
info "    para añadir la definición del nuevo servicio y su base de datos."
info " 5. Reinicia el entorno ('make down && make up') para incluir los nuevos servicios."
info " 6. Configura el Gateway ('gateway/config/nginx.conf' o la tecnología elegida) para enrutar"
info "    peticiones a los nuevos microservicios usando Consul para el descubrimiento."
info "====================================================="

exit 0
