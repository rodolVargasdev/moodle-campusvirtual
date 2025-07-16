#!/bin/bash

echo "🧹 LIMPIEZA COMPLETA DE FILESTORE Y MOODLE ESCALABLE"
echo "===================================================="

# Variables de configuración
PROJECT_ID="g-moddle-dev-prj-jnld"
ZONE="us-east1-b"
FILESTORE_NAME="moodle-filestore"

echo "⚠️  ADVERTENCIA: Esto eliminará TODOS los datos de Moodle y el Filestore"
echo "¿Estás seguro de que quieres continuar? (y/N)"
read -r response

if [[ ! "$response" =~ ^[Yy]$ ]]; then
    echo "❌ Operación cancelada."
    exit 0
fi

echo "🗑️ Eliminando recursos de Kubernetes..."

# Eliminar deployments y servicios
echo "   - Eliminando deployments..."
kubectl delete deployment moodle-scalable -n moodle --ignore-not-found=true
kubectl delete deployment moodle-scaled -n moodle --ignore-not-found=true
kubectl delete deployment moodle -n moodle --ignore-not-found=true

echo "   - Eliminando servicios..."
kubectl delete service moodle-scalable -n moodle --ignore-not-found=true
kubectl delete service moodle-scaled -n moodle --ignore-not-found=true
kubectl delete service moodle -n moodle --ignore-not-found=true

echo "   - Eliminando PVCs..."
kubectl delete pvc moodle-filestore-pvc -n moodle --ignore-not-found=true
kubectl delete pvc moodle-data-pvc-rwm -n moodle --ignore-not-found=true
kubectl delete pvc moodle-data-pvc -n moodle --ignore-not-found=true

echo "   - Eliminando PersistentVolumes..."
kubectl delete pv moodle-filestore-pv --ignore-not-found=true

echo "   - Eliminando StorageClass..."
kubectl delete storageclass filestore-rwx --ignore-not-found=true

echo "   - Eliminando ConfigMaps..."
kubectl delete configmap moodle-config -n moodle --ignore-not-found=true

echo "   - Eliminando Secrets..."
kubectl delete secret mysql-secret -n moodle --ignore-not-found=true

echo "   - Eliminando namespace moodle..."
kubectl delete namespace moodle --ignore-not-found=true

echo "🗄️ Eliminando Filestore..."
gcloud filestore instances delete $FILESTORE_NAME --zone=$ZONE --quiet

echo "⏳ Esperando 30 segundos para completar eliminaciones..."
sleep 30

echo "✅ Limpieza completada."
echo ""
echo "📋 Recursos eliminados:"
echo "   - Filestore: $FILESTORE_NAME"
echo "   - Namespace: moodle"
echo "   - Todos los deployments, servicios y PVCs"
echo "   - StorageClass y PersistentVolumes"
echo ""
echo "⚠️  Nota: Los datos de Moodle han sido eliminados permanentemente." 