#!/bin/bash

echo "=== Construyendo Moodle con Cloud Build ==="

# Configuración
PROJECT_ID=$(gcloud config get-value project)
IMAGE_NAME="gcr.io/$PROJECT_ID/moodle-custom"
TAG="latest"

echo "Proyecto: $PROJECT_ID"
echo "Imagen: $IMAGE_NAME:$TAG"

# Verificar que estamos en el directorio correcto
if [ ! -f "Dockerfile" ]; then
    echo "Error: No se encontró el Dockerfile en el directorio actual"
    exit 1
fi

# Habilitar Cloud Build API si no está habilitada
echo "Verificando Cloud Build API..."
gcloud services enable cloudbuild.googleapis.com

# Construir la imagen con Cloud Build
echo "Construyendo imagen con Cloud Build..."
gcloud builds submit --tag $IMAGE_NAME:$TAG .

if [ $? -ne 0 ]; then
    echo "Error: Falló la construcción con Cloud Build"
    exit 1
fi

echo ""
echo "=== Construcción completada ==="
echo "Imagen disponible en: $IMAGE_NAME:$TAG"
echo ""
echo "Para desplegar, ejecuta:"
echo "  kubectl set image deployment/moodle moodle=$IMAGE_NAME:$TAG -n moodle"
echo ""
echo "O actualiza el deployment manualmente con la nueva imagen." 