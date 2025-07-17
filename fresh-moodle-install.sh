#!/bin/bash

echo🧹 ELIMINANDO MOODLE ACTUAL E INSTALANDO LA ÚLTIMA VERSIÓN"
echo "=========================================================="

# Verificar conexión al cluster
if ! kubectl cluster-info &> /dev/null; then
    echo "❌ Error: No se puede conectar al cluster"
    exit 1
fi

echo "✅ Conexión al cluster verificada

# 1. ESCALAR A 0 para detener todo
echo "🛑 Deteniendo todos los deployments..."
kubectl scale deployment moodle --replicas=0 -n moodle --ignore-not-found=true
kubectl scale deployment mysql --replicas=0 -n moodle --ignore-not-found=true

#2Eliminar todos los pods
echo "🗑️ Eliminando todos los pods..."
kubectl delete pods -n moodle --all --ignore-not-found=true

#3Eliminar todos los ReplicaSets
echo "🗑️ Eliminando todos los ReplicaSets..."
kubectl delete replicaset -n moodle --all --ignore-not-found=true

# 4. Eliminar deployments
echo "🗑️ Eliminando deployments..."
kubectl delete deployment moodle -n moodle --ignore-not-found=true
kubectl delete deployment mysql -n moodle --ignore-not-found=true

# 5. Eliminar servicios
echo "🗑️ Eliminando servicios..."
kubectl delete service moodle -n moodle --ignore-not-found=true
kubectl delete service mysql -n moodle --ignore-not-found=true

# 6. Eliminar PVCs (¡CUIDADO! Esto eliminará todos los datos)
echo "⚠️  ELIMINANDO TODOS LOS DATOS DE MOODLE...kubectl delete pvc moodle-data-pvc -n moodle --ignore-not-found=true
kubectl delete pvc mysql-data-pvc -n moodle --ignore-not-found=true

# 7. Eliminar secrets
echo "🗑️ Eliminando secrets..."
kubectl delete secret moodle-secret -n moodle --ignore-not-found=true
kubectl delete secret mysql-secret -n moodle --ignore-not-found=true

# 8. Esperar a que se completen las eliminaciones
echo "⏳ Esperando 30 segundos para completar eliminaciones..."
sleep 30# 9. Verificar que todo esté limpio
echo "🔍 Verificando limpieza..."
kubectl get all -n moodle
kubectl get pvc -n moodle
kubectl get secrets -n moodle

echo 
echo "✅ ¡Limpieza completada!"
echo "🚀 Ahora puedes ejecutar el script de instalación de Moodle más reciente
echo ""
echo📋 Para instalar la última versión de Moodle, ejecuta:"
echo "   ./deploy-latest-moodle.sh" 