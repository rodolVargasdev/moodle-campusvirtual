#!/bin/bash

echo "🧹 === LIMPIEZA AUTOMÁTICA DE MOODLE PERSONALIZADO ==="
echo "📅 Fecha: $(date)"
echo ""

# Configuración
PROJECT_ID=$(gcloud config get-value project)
IMAGE_NAME="gcr.io/$PROJECT_ID/moodle-custom"
TAG="latest"

echo "🔧 Configuración:"
echo "   Proyecto: $PROJECT_ID"
echo "   Imagen: $IMAGE_NAME:$TAG"
echo ""

# Confirmar antes de eliminar
echo "⚠️  ADVERTENCIA: Esto eliminará TODOS los recursos de Moodle"
echo "   - Pods y deployments"
echo "   - Services e ingress"
echo "   - PersistentVolumeClaims (datos se perderán)"
echo "   - ConfigMaps"
echo "   - Imagen personalizada"
echo ""

read -p "¿Estás seguro de que quieres continuar? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Limpieza cancelada"
    exit 1
fi

echo ""
echo "🚀 Iniciando limpieza..."

# Eliminar recursos de Kubernetes
echo "🗑️ Eliminando recursos de Kubernetes..."
kubectl delete -f . --ignore-not-found=true --timeout=300s
echo "✅ Recursos de Kubernetes eliminados"
echo ""

# Eliminar namespace
echo "📁 Eliminando namespace moodle..."
kubectl delete namespace moodle --ignore-not-found=true --timeout=300s
echo "✅ Namespace moodle eliminado"
echo ""

# Eliminar imagen personalizada
echo "🖼️ Eliminando imagen personalizada..."
gcloud container images delete $IMAGE_NAME:$TAG --quiet --force-delete-tags || echo "ℹ️  Imagen no encontrada o ya eliminada"
echo "✅ Imagen personalizada eliminada"
echo ""

# Eliminar IP estática
echo "🌐 Eliminando IP estática..."
gcloud compute addresses delete moodle-ip --global --quiet || echo "ℹ️  IP estática no encontrada o ya eliminada"
echo "✅ IP estática eliminada"
echo ""

# Limpiar archivos temporales
echo "🧽 Limpiando archivos temporales..."
rm -f deployment-custom-final.yaml
rm -f deployment-custom.yaml
echo "✅ Archivos temporales eliminados"
echo ""

# Verificar que todo esté limpio
echo "🔍 Verificando limpieza..."
echo "   Namespaces:"
kubectl get namespaces | grep moodle || echo "   ✅ No hay namespaces de moodle"
echo ""
echo "   Imágenes:"
gcloud container images list-tags $IMAGE_NAME --limit=5 || echo "   ✅ No hay imágenes de moodle"
echo ""
echo "   IPs estáticas:"
gcloud compute addresses list | grep moodle-ip || echo "   ✅ No hay IPs estáticas de moodle"
echo ""

echo "🎉 === LIMPIEZA COMPLETADA ==="
echo ""
echo "✅ Todos los recursos de Moodle han sido eliminados"
echo ""
echo "📝 Para verificar que todo esté limpio:"
echo "   kubectl get all -n moodle"
echo "   gcloud container images list-tags $IMAGE_NAME"
echo "   gcloud compute addresses list"
echo ""
echo "🔄 Para desplegar nuevamente:"
echo "   ./auto-deploy-moodle.sh" 