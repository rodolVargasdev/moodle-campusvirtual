#!/bin/bash

# Script simple para limpiar el cluster y resolver problemas de Moodle
echo "🧹 Limpieza simple del cluster GKE"
echo "=================================="

# Verificar conexión
if ! kubectl cluster-info &> /dev/null; then
    echo "❌ Error: No se puede conectar al cluster"
    exit 1
fi

echo "✅ Conexión verificada

# Eliminar pods problemáticos en estado ContainerCreating
echo "🗑️ Eliminando pods problemáticos...kubectl get pods -n moodle --field-selector=status.phase=Pending -o name | xargs -r kubectl delete -n moodle

# Eliminar pods duplicados de Moodle (mantener solo el más reciente)
echo "🔍 Verificando pods duplicados..."
MOODLE_PODS=$(kubectl get pods -n moodle -l app=moodle --sort-by=.metadata.creationTimestamp -o name | tail -n +2)
if ! -z$MOODLE_PODS]; then
    echo "🗑️ Eliminando pods duplicados de Moodle..."
    echo $MOODLE_PODS" | xargs -r kubectl delete -n moodle
fi

# Eliminar pods duplicados de MySQL
echo "🔍 Verificando pods duplicados de MySQL...
MYSQL_PODS=$(kubectl get pods -n moodle -l app=mysql --sort-by=.metadata.creationTimestamp -o name | tail -n +2
if  ! -z "$MYSQL_PODS]; then
    echo "🗑️ Eliminando pods duplicados de MySQL...    echo$MYSQL_PODS" | xargs -r kubectl delete -n moodle
fi

# Forzar restart de deployments
echo "🔄 Reiniciando deployments..."
kubectl rollout restart deployment/moodle -n moodle
kubectl rollout restart deployment/mysql -n moodle

# Esperar a que se estabilicen
echo ⏳ Esperando estabilización..."
sleep 30

# Verificar estado final
echo o📊 Estado final:"
echo ================kubectl get pods -n moodle
echo ""
kubectl get services -n moodle
echo ho 🌐 IP del LoadBalancer:"
kubectl get service moodle -n moodle -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "Configurándose...

echo
echo ✅ Limpieza completada!" 