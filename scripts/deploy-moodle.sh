#!/bin/bash

# Script para desplegar Moodle en GKE
# Uso: ./deploy-moodle.sh [DOMAIN] [MYSQL_PASSWORD] [MOODLE_PASSWORD]

set -e

# Variables por defecto
DOMAIN=${1:-"moodle.local"}
MYSQL_PASSWORD=${2:-"moodle123!"}
MOODLE_PASSWORD=${3:-"admin123!"}

echo "🚀 Desplegando Moodle en GKE..."
echo "Dominio: $DOMAIN"
echo "Contraseña MySQL: $MYSQL_PASSWORD"
echo "Contraseña Moodle: $MOODLE_PASSWORD"

# Verificar que helm esté instalado
if ! command -v helm &> /dev/null; then
    echo "❌ Error: helm no está instalado. Por favor instala Helm."
    exit 1
fi

# Verificar que kubectl esté configurado
if ! kubectl cluster-info &> /dev/null; then
    echo "❌ Error: kubectl no está configurado. Ejecuta primero: ./scripts/setup-gcp.sh"
    exit 1
fi

# Agregar repositorios de Helm
echo "📦 Agregando repositorios de Helm..."
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

# Crear namespaces
echo "🏷️ Creando namespaces..."
kubectl apply -f k8s/namespace.yaml

# Aplicar storage classes
echo "💾 Aplicando storage classes..."
kubectl apply -f k8s/storage-class.yaml

# Instalar Nginx Ingress Controller
echo "🌐 Instalando Nginx Ingress Controller..."
helm install nginx-ingress ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.service.type=LoadBalancer \
  --wait

# Esperar a que el Load Balancer esté listo
echo "⏳ Esperando a que el Load Balancer esté listo..."
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=300s

# Obtener IP externa
echo "🔍 Obteniendo IP externa..."
EXTERNAL_IP=""
while [ -z "$EXTERNAL_IP" ]; do
  EXTERNAL_IP=$(kubectl get svc -n ingress-nginx nginx-ingress-ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
  if [ -z "$EXTERNAL_IP" ]; then
    echo "⏳ Esperando IP externa..."
    sleep 10
  fi
done

echo "✅ IP Externa obtenida: $EXTERNAL_IP"

# Instalar MySQL
echo "🗄️ Instalando MySQL..."
helm install moodle-mysql bitnami/mysql \
  --namespace moodle \
  --set auth.rootPassword="$MYSQL_PASSWORD" \
  --set auth.database=moodle \
  --set auth.username=moodle \
  --set auth.password="$MYSQL_PASSWORD" \
  --set primary.persistence.size=20Gi \
  --set primary.persistence.storageClass=standard-rwo \
  --wait

# Esperar a que MySQL esté listo
echo "⏳ Esperando a que MySQL esté listo..."
kubectl wait --namespace moodle \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/name=mysql \
  --timeout=300s

# Actualizar values.yaml con la IP externa
echo "📝 Actualizando configuración con IP externa..."
sed -i.bak "s/moodle.local/$EXTERNAL_IP.nip.io/g" charts/moodle/values.yaml
sed -i.bak "s|http://moodle.local|http://$EXTERNAL_IP.nip.io|g" charts/moodle/values.yaml

# Instalar Moodle
echo "📚 Instalando Moodle..."
helm install moodle ./charts/moodle \
  --namespace moodle \
  --set database.host=moodle-mysql.moodle.svc.cluster.local \
  --set database.name=moodle \
  --set database.user=moodle \
  --set database.password="$MYSQL_PASSWORD" \
  --set persistence.size=50Gi \
  --set moodle.password="$MOODLE_PASSWORD" \
  --set moodle.siteurl="http://$EXTERNAL_IP.nip.io" \
  --wait

# Esperar a que Moodle esté listo
echo "⏳ Esperando a que Moodle esté listo..."
kubectl wait --namespace moodle \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/name=moodle \
  --timeout=300s

# Verificar el despliegue
echo "✅ Verificando despliegue..."
kubectl get pods -n moodle
kubectl get svc -n moodle
kubectl get ingress -n moodle

echo ""
echo "🎉 ¡Moodle desplegado exitosamente!"
echo ""
echo "📋 Información de acceso:"
echo "URL: http://$EXTERNAL_IP.nip.io"
echo "Usuario: admin"
echo "Contraseña: $MOODLE_PASSWORD"
echo ""
echo "🔧 Para verificar el estado:"
echo "kubectl get pods -n moodle"
echo "kubectl logs -f deployment/moodle -n moodle"
echo ""
echo "🗄️ Para acceder a MySQL:"
echo "kubectl exec -it \$(kubectl get pods -n moodle -l app.kubernetes.io/name=mysql -o jsonpath='{.items[0].metadata.name}') -n moodle -- mysql -u root -p"
echo ""
echo "⚠️ IMPORTANTE: Cambia las contraseñas por defecto después del primer acceso." 