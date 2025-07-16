#!/bin/bash

# Script de despliegue rápido de Moodle en GCP
# Este script automatiza todo el proceso de despliegue

# Variables por defecto
PROJECT_ID=${1:-"tu-project-id"}
ZONE=${2:-"us-central1-a"}
CLUSTER_NAME=${3:-"moodle-cluster"}
MYSQL_PASSWORD=${4:-"moodle123!"}
MOODLE_PASSWORD=${5:-"admin123!"}

echo "🚀 Despliegue rápido de Moodle en GCP"
echo "====================================="

# Verificar herramientas
echo "🔍 Verificando herramientas..."

tools=("gcloud" "kubectl" "helm")
for tool in "${tools[@]}"; do
    if command -v $tool &> /dev/null; then
        echo "✅ $tool está instalado"
    else
        echo "❌ $tool no está instalado"
        echo "Por favor instala $tool antes de continuar"
        exit 1
    fi
done

# Paso 1: Configurar GCP
echo ""
echo "📋 Paso 1: Configurando GCP..."
./scripts/setup-gcp.sh "$PROJECT_ID" "$ZONE" "$CLUSTER_NAME"

# Paso 2: Desplegar Moodle
echo ""
echo "📚 Paso 2: Desplegando Moodle..."
./scripts/deploy-moodle.sh "moodle.local" "$MYSQL_PASSWORD" "$MOODLE_PASSWORD"

echo ""
echo "🎉 ¡Despliegue completado exitosamente!"
echo ""
echo "📋 Resumen:"
echo "Proyecto: $PROJECT_ID"
echo "Cluster: $CLUSTER_NAME"
echo "Zona: $ZONE"
echo "Contraseña MySQL: $MYSQL_PASSWORD"
echo "Contraseña Moodle: $MOODLE_PASSWORD"
echo ""
echo "🔗 Para acceder a Moodle, obtén la IP externa con:"
echo "kubectl get svc -n ingress-nginx"
echo ""
echo "⚠️ IMPORTANTE: Cambia las contraseñas por defecto después del primer acceso." 