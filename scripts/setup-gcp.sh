#!/bin/bash

# Script para configurar GCP y GKE para Moodle
# Uso: ./setup-gcp.sh [PROJECT_ID] [ZONE] [CLUSTER_NAME]

set -e

# Variables por defecto
PROJECT_ID=${1:-"tu-project-id"}
ZONE=${2:-"us-central1-a"}
CLUSTER_NAME=${3:-"moodle-cluster"}

echo "🚀 Configurando GCP y GKE para Moodle..."
echo "Proyecto: $PROJECT_ID"
echo "Zona: $ZONE"
echo "Cluster: $CLUSTER_NAME"

# Verificar que gcloud esté instalado
if ! command -v gcloud &> /dev/null; then
    echo "❌ Error: gcloud no está instalado. Por favor instala Google Cloud SDK."
    exit 1
fi

# Verificar que kubectl esté instalado
if ! command -v kubectl &> /dev/null; then
    echo "❌ Error: kubectl no está instalado. Por favor instala kubectl."
    exit 1
fi

# Autenticarse con GCP
echo "🔐 Autenticándose con GCP..."
gcloud auth login

# Configurar proyecto
echo "📋 Configurando proyecto: $PROJECT_ID"
gcloud config set project $PROJECT_ID

# Habilitar APIs necesarias
echo "🔧 Habilitando APIs necesarias..."
gcloud services enable container.googleapis.com
gcloud services enable compute.googleapis.com
gcloud services enable dns.googleapis.com

# Crear cluster GKE
echo "🏗️ Creando cluster GKE: $CLUSTER_NAME"
gcloud container clusters create $CLUSTER_NAME \
  --zone=$ZONE \
  --num-nodes=3 \
  --machine-type=n1-standard-2 \
  --disk-size=50 \
  --enable-autoscaling \
  --min-nodes=1 \
  --max-nodes=5 \
  --enable-network-policy \
  --enable-ip-alias \
  --addons=HttpLoadBalancing,HorizontalPodAutoscaling

# Configurar kubectl
echo "⚙️ Configurando kubectl..."
gcloud container clusters get-credentials $CLUSTER_NAME --zone=$ZONE

# Verificar cluster
echo "✅ Verificando cluster..."
kubectl cluster-info
kubectl get nodes

echo "🎉 Configuración de GCP y GKE completada!"
echo ""
echo "📝 Próximos pasos:"
echo "1. Instalar Helm: https://helm.sh/docs/intro/install/"
echo "2. Ejecutar: ./scripts/deploy-moodle.sh"
echo ""
echo "🔗 Para ver el cluster en la consola web:"
echo "https://console.cloud.google.com/kubernetes/clusters/details/$ZONE/$CLUSTER_NAME" 