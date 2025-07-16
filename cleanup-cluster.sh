#!/bin/bash

echo "🧹 LIMPIEZA COMPLETA DEL CLUSTER GKE"
echo "======================================"

# Verificar contexto actual
echo "📋 Contexto actual del cluster:"
kubectl config current-context
echo ""

# Listar todos los namespaces
echo "📁 Namespaces existentes:"
kubectl get namespaces
echo ""

# Eliminar namespace moodle si existe
echo "🗑️ Eliminando namespace moodle..."
kubectl delete namespace moodle --ignore-not-found=true --timeout=60s

# Eliminar cualquier PVC huérfano en otros namespaces
echo "🗑️ Limpiando PVCs huérfanos..."
kubectl get pvc --all-namespaces | grep moodle | awk '{print $1, $2}' | while read namespace pvc; do
    if [ ! -z "$namespace" ] && [ ! -z "$pvc" ]; then
        echo "Eliminando PVC $pvc en namespace $namespace"
        kubectl delete pvc $pvc -n $namespace --ignore-not-found=true
    fi
done

# Eliminar cualquier deployment de moodle en otros namespaces
echo "🗑️ Limpiando deployments de moodle..."
kubectl get deployments --all-namespaces | grep moodle | awk '{print $1, $2}' | while read namespace deployment; do
    if [ ! -z "$namespace" ] && [ ! -z "$deployment" ]; then
        echo "Eliminando deployment $deployment en namespace $namespace"
        kubectl delete deployment $deployment -n $namespace --ignore-not-found=true
    fi
done

# Eliminar cualquier service de moodle en otros namespaces
echo "🗑️ Limpiando services de moodle..."
kubectl get services --all-namespaces | grep moodle | awk '{print $1, $2}' | while read namespace service; do
    if [ ! -z "$namespace" ] && [ ! -z "$service" ]; then
        echo "Eliminando service $service en namespace $namespace"
        kubectl delete service $service -n $namespace --ignore-not-found=true
    fi
done

# Eliminar cualquier secret de moodle en otros namespaces
echo "🗑️ Limpiando secrets de moodle..."
kubectl get secrets --all-namespaces | grep moodle | awk '{print $1, $2}' | while read namespace secret; do
    if [ ! -z "$namespace" ] && [ ! -z "$secret" ]; then
        echo "Eliminando secret $secret en namespace $namespace"
        kubectl delete secret $secret -n $namespace --ignore-not-found=true
    fi
done

# Esperar a que se completen las eliminaciones
echo "⏳ Esperando 30 segundos para completar eliminaciones..."
sleep 30

# Verificar que no queden recursos de moodle
echo "🔍 Verificando limpieza..."
echo "=== PVCs restantes ==="
kubectl get pvc --all-namespaces | grep -i moodle || echo "No se encontraron PVCs de moodle"

echo "=== Deployments restantes ==="
kubectl get deployments --all-namespaces | grep -i moodle || echo "No se encontraron deployments de moodle"

echo "=== Services restantes ==="
kubectl get services --all-namespaces | grep -i moodle || echo "No se encontraron services de moodle"

echo "=== Secrets restantes ==="
kubectl get secrets --all-namespaces | grep -i moodle || echo "No se encontraron secrets de moodle"

# Verificar estado del cluster
echo ""
echo "📊 Estado actual del cluster:"
echo "=== Nodos ==="
kubectl get nodes -o wide

echo ""
echo "=== Storage Classes ==="
kubectl get storageclass

echo ""
echo "=== Namespaces ==="
kubectl get namespaces

echo ""
echo "✅ ¡Limpieza completada!"
echo "🎯 El cluster está listo para el nuevo despliegue de Moodle"
echo ""
echo "📋 Para continuar, ejecuta:"
echo "   ./deploy-simple.sh" 