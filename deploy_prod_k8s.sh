#!/bin/bash

# Script CONCEPTUAL para desplegar/actualizar en Producción usando Kubectl

# --- Variables (Deberían venir del CI/CD o parámetros) ---
IMAGE_TAG="v1.2.3" # La nueva versión/tag de la imagen a desplegar
K8S_NAMESPACE="production"
K8S_CONTEXT="mi-cluster-produccion" # Nombre del contexto kubectl
REGISTRY_URL="gcr.io/mi-proyecto" # URL base del registro de imágenes

# Nombres de los Deployments en K8s (ejemplos)
FRONTEND_DEPLOY="frontend-deployment"
GATEWAY_DEPLOY="gateway-deployment"
PRODUCTS_DEPLOY="products-deployment"
CLIENTS_DEPLOY="clients-deployment"
DISCOVER_DEPLOY="discover-deployment"
# Asumimos que etcd y BBDD son StatefulSets o servicios gestionados externamente

echo "================================================="
echo " Desplegando a Producción (Kubernetes)"
echo " Contexto K8s: $K8S_CONTEXT"
echo " Namespace:    $K8S_NAMESPACE"
echo " Tag Imagenes: $IMAGE_TAG"
echo "================================================="

# --- Prerrequisitos ---
echo "[1/3] Verificando kubectl..."
if ! command -v kubectl &> /dev/null; then
    echo "ERROR: kubectl no está instalado o no se encuentra en el PATH."
    exit 1
fi
echo "Usando contexto: $(kubectl config current-context)"
# Podrías añadir una comprobación para asegurar que es el contexto correcto
# kubectl config use-context $K8S_CONTEXT || exit 1

# --- Autenticación al Registro (Depende del registro y CI/CD) ---
# echo "[2/3] Autenticando al registro de contenedores (si es necesario)..."
# gcloud auth configure-docker europe-west1-docker.pkg.dev # Ejemplo GCP Artifact Registry
# aws ecr get-login-password --region eu-west-1 | docker login --username AWS --password-stdin 123456789012.dkr.ecr.eu-west-1.amazonaws.com # Ejemplo AWS ECR

# --- Actualización de Deployments ---
echo "[3/3] Actualizando imágenes de los Deployments..."

# Función para actualizar y verificar un deployment
update_deployment() {
    local deployment_name=$1
    local service_name=$2 # Nombre base de la imagen
    local image_url="${REGISTRY_URL}/${service_name}:${IMAGE_TAG}"

    echo "  -> Actualizando $deployment_name con imagen $image_url..."
    kubectl set image deployment/"$deployment_name" \
        "$service_name"-container="$image_url" \
        -n "$K8S_NAMESPACE" --record || \
        { echo "ERROR: Falló la actualización de imagen para $deployment_name"; return 1; }

    echo "     Esperando finalización del rollout para $deployment_name..."
    kubectl rollout status deployment/"$deployment_name" -n "$K8S_NAMESPACE" --timeout=5m || \
        { echo "ERROR: Rollout de $deployment_name falló o excedió el tiempo."; return 1; }
    echo "     Rollout de $deployment_name completado."
    return 0
}

# Actualizar cada deployment
update_deployment "$FRONTEND_DEPLOY" "frontend-web" && \
update_deployment "$GATEWAY_DEPLOY" "gateway" && \
update_deployment "$PRODUCTS_DEPLOY" "products-service" && \
update_deployment "$CLIENTS_DEPLOY" "clients-service" && \
update_deployment "$DISCOVER_DEPLOY" "discover-service"

# Comprobar estado final
if [ $? -eq 0 ]; then
    echo "-------------------------------------------------"
    echo "¡Despliegue a Producción completado con éxito!"
    echo "Verificando Pods en namespace $K8S_NAMESPACE:"
    kubectl get pods -n "$K8S_NAMESPACE"
    echo "-------------------------------------------------"
    exit 0
else
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    echo "ERROR: Uno o más deployments fallaron durante la actualización."
    echo "Revisa los logs y el estado del cluster K8s."
    echo "Podría ser necesario un rollback: kubectl rollout undo deployment/<nombre_deployment> -n $K8S_NAMESPACE"
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    exit 1
fi

# Nota: Si usas Helm, el script sería más simple:
# helm upgrade mi-release ./mi-chart --version $IMAGE_TAG -f values-prod.yaml -n $K8S_NAMESPACE --install --atomic