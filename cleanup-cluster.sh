#!/bin/bash

# Script para limpiar el cluster GKE y dejar solo lo necesario para Moodle
# Elimina recursos innecesarios y mantiene solo Moodle funcionando

set -e

echo🧹 Iniciando limpieza del cluster GKE"
echo "=====================================

# Verificar que kubectl esté configurado
if ! command -v kubectl &> /dev/null; then
    echo❌ Error: kubectl no está instalado o no está en el PATH  exit1
# Verificar conexión al cluster
if ! kubectl cluster-info &> /dev/null; then
    echo "❌ Error: No se puede conectar al cluster. Verifica tu configuración de kubectl"
    exit 1
fi

echo "✅ Conexión al cluster verificada# Verificar que el namespace moodle existe
if ! kubectl get namespace moodle &> /dev/null; then
    echo "❌ Error: El namespace moodle' no existe"
    exit 1
fi

echo "✅ Namespace 'moodle' encontrado"

# Función para eliminar recursos de un namespace
cleanup_namespace() {
    local namespace=$1    echo "🧹 Limpiando namespace: $namespace"
    
    # Eliminar deployments
    kubectl get deployments -n $namespace -o name 2>/dev/null | while read deployment; do
        if [$deployment != *moodle"* ]] && [$deployment !=*mysql; then
            echo   🗑️  Eliminando deployment: $deployment"
            kubectl delete $deployment -n $namespace --ignore-not-found=true
        fi
    done
    
    # Eliminar services
    kubectl get services -n $namespace -o name 2>/dev/null | while read service; do
        if $service != *moodle"* ]] && [ "$service !=*mysql; then
            echo   🗑️Eliminando service: $service"
            kubectl delete $service -n $namespace --ignore-not-found=true
        fi
    done
    
    # Eliminar pods huérfanos (no controlados por deployments)
    kubectl get pods -n $namespace -o name 2>/dev/null | while read pod; do
        if [[ $pod != *moodle*]] && [[ $pod !=*mysql; then
            echo   🗑️  Eliminando pod huérfano: $pod"
            kubectl delete $pod -n $namespace --ignore-not-found=true
        fi
    done
    
    # Eliminar PVCs no utilizados
    kubectl get pvc -n $namespace -o name 2>/dev/null | while read pvc; do
        if [[ $pvc!= *moodle-data-pvc*]] && [[$pvc" != *"mysql-data-pvc"* ]]; then
            echo   🗑️  Eliminando PVC: $pvc"
            kubectl delete $pvc -n $namespace --ignore-not-found=true
        fi
    done
    
    # Eliminar configmaps no utilizados
    kubectl get configmaps -n $namespace -o name 2>/dev/null | while read configmap; do
        if [[ $configmap != *"kube-root-ca"* ]]; then
            echo   🗑️ Eliminando configmap: $configmap"
            kubectl delete $configmap -n $namespace --ignore-not-found=true
        fi
    done
    
    # Eliminar secrets no utilizados
    kubectl get secrets -n $namespace -o name 2>/dev/null | while read secret; do
        if [ "$secret" != *"moodle-secret"* ]] && [[ "$secret" != *mysql-secret"* ]] && [[ "$secret" != *"default-token"* ]]; then
            echo   🗑️ Eliminando secret: $secret"
            kubectl delete $secret -n $namespace --ignore-not-found=true
        fi
    done
}

# Limpiar namespace moodle
cleanup_namespacemoodle

# Limpiar otros namespaces del sistema (solo recursos no críticos)
echo "🧹 Limpiando recursos del sistema..."

# Eliminar PVs no utilizados
echo  🔍 Verificando PersistentVolumes no utilizados...
kubectl get pv -o name 2>/dev/null | while read pv; do
    status=$(kubectl get $pv -o jsonpath='{.status.phase}')
    if [[ "$status" == "Available ]]; then
        echo 🗑️  Eliminando PV no utilizado: $pv"
        kubectl delete $pv --ignore-not-found=true
    fi
done

# Eliminar StorageClasses no utilizados (excepto los estándar)
echo  🔍 Verificando StorageClasses..."
kubectl get storageclass -o name 2>/dev/null | while read sc; do
    if [[ "$sc" != *"standard"* ]] && $sc" != *"fast"* ]]; then
        echo   🗑️Eliminando StorageClass: $sc"
        kubectl delete $sc --ignore-not-found=true
    fi
done

# Verificar estado final de Moodle
echo "
echo "🔍 Verificando estado final de Moodle..."
echo "========================================"

# Verificar pods de Moodle
echo 📊 Pods de Moodle:kubectl get pods -n moodle -l app=moodle

# Verificar pods de MySQL
echo "
echo 📊 Pods de MySQL:kubectl get pods -n moodle -l app=mysql

# Verificar servicios
echo ""
echo📊 Servicios:"
kubectl get services -n moodle

# Verificar PVCs
echo ""
echo "📊 PersistentVolumeClaims:"
kubectl get pvc -n moodle

# Verificar LoadBalancer IP
echo "
echo "🌐 LoadBalancer IP:"
kubectl get service moodle -n moodle -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "Configurándose...

echo
echo ✅ Limpieza completada!"
echo======================"
echo "Moodle debería estar funcionando en:echohttp://$(kubectl get service moodle -n moodle -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echoIP_PENDIENTE)
echo 
echo "🔧 Comandos útiles:"
echo   - Ver logs: kubectl logs -n moodle -l app=moodle -f"
echo "  - Ver estado: kubectl get pods -n moodle"
echo   - Ver servicios: kubectl get services -n moodle"
echo- Ver eventos: kubectl get events -n moodle --sort-by=.lastTimestamp 