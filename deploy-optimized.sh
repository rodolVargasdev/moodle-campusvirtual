#!/bin/bash

echo "🚀 DESPLIEGUE OPTIMIZADO DE MOODLE EN GKE"
echo "=========================================="
echo "Cluster: us-east1-dev-moodle-gke-02"
echo "Zona: us-east1-b"
echo ""

# Verificar contexto
echo "📋 Verificando contexto del cluster..."
kubectl config current-context
echo ""

# Verificar recursos del cluster
echo "📊 Recursos disponibles del cluster:"
echo "=== Nodos ==="
kubectl get nodes -o wide
echo ""

echo "=== Storage Classes ==="
kubectl get storageclass
echo ""

# Limpiar recursos existentes
echo "🧹 Limpiando recursos existentes..."
kubectl delete namespace moodle --ignore-not-found=true --timeout=60s
sleep 20

# Crear namespace
echo "📁 Creando namespace moodle..."
kubectl create namespace moodle

# Aplicar configuración optimizada
echo "📦 Aplicando configuración optimizada de Moodle..."
kubectl apply -f k8s-moodle-optimized.yaml

echo "⏳ Esperando 30 segundos para que se inicien los recursos..."
sleep 30

# Función para mostrar estado
show_status() {
    echo "=== Estado de PVCs ==="
    kubectl get pvc -n moodle -o wide
    
    echo ""
    echo "=== Estado de Pods ==="
    kubectl get pods -n moodle -o wide
    
    echo ""
    echo "=== Estado de Services ==="
    kubectl get svc -n moodle -o wide
    
    echo ""
    echo "=== Estado de Secrets ==="
    kubectl get secrets -n moodle
}

# Mostrar estado inicial
show_status

# Monitorear el despliegue
echo ""
echo "📊 Monitoreando despliegue..."
attempt=1
max_attempts=20

while [ $attempt -le $max_attempts ]; do
    echo ""
    echo "🔄 Intento $attempt de $max_attempts"
    echo "=================================="
    
    # Verificar estado de los pods
    mysql_status=$(kubectl get pods -n moodle -l app=mysql -o jsonpath='{.items[0].status.phase}' 2>/dev/null)
    moodle_status=$(kubectl get pods -n moodle -l app=moodle -o jsonpath='{.items[0].status.phase}' 2>/dev/null)
    
    echo "MySQL: $mysql_status"
    echo "Moodle: $moodle_status"
    
    # Verificar si hay errores
    mysql_ready=$(kubectl get pods -n moodle -l app=mysql -o jsonpath='{.items[0].status.containerStatuses[0].ready}' 2>/dev/null)
    moodle_ready=$(kubectl get pods -n moodle -l app=moodle -o jsonpath='{.items[0].status.containerStatuses[0].ready}' 2>/dev/null)
    
    if [ "$mysql_ready" = "true" ] && [ "$moodle_ready" = "true" ]; then
        echo ""
        echo "✅ ¡Ambos servicios están listos!"
        
        # Obtener IP externa
        external_ip=$(kubectl get svc moodle -n moodle -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
        if [ ! -z "$external_ip" ]; then
            echo ""
            echo "🎉 ¡MOODLE ESTÁ COMPLETAMENTE FUNCIONAL!"
            echo "========================================"
            echo "🌐 URL de acceso: http://$external_ip"
            echo "👤 Usuario: admin"
            echo "🔑 Contraseña: moodle12345"
            echo ""
            echo "📋 Información del cluster:"
            echo "   - Cluster: us-east1-dev-moodle-gke-02"
            echo "   - Zona: us-east1-b"
            echo "   - Nodos: 3"
            echo ""
            echo "🔧 Comandos útiles:"
            echo "   kubectl get pods -n moodle"
            echo "   kubectl logs -f deployment/moodle -n moodle"
            echo "   kubectl logs -f deployment/mysql -n moodle"
            echo "   kubectl get svc -n moodle"
            echo ""
            echo "📊 Monitoreo:"
            echo "   kubectl top pods -n moodle"
            echo "   kubectl describe pod -l app=moodle -n moodle"
            break
        else
            echo "⏳ Esperando asignación de IP externa..."
        fi
    else
        # Mostrar logs si hay problemas
        if [ "$mysql_status" = "Error" ] || [ "$mysql_status" = "CrashLoopBackOff" ]; then
            echo "❌ MySQL tiene problemas. Mostrando logs..."
            kubectl logs -l app=mysql -n moodle --tail=20
        fi
        
        if [ "$moodle_status" = "Error" ] || [ "$moodle_status" = "CrashLoopBackOff" ]; then
            echo "❌ Moodle tiene problemas. Mostrando logs..."
            kubectl logs -l app=moodle -n moodle --tail=20
        fi
        
        echo "⏳ Esperando 45 segundos..."
        sleep 45
    fi
    
    attempt=$((attempt + 1))
done

if [ $attempt -gt $max_attempts ]; then
    echo ""
    echo "❌ Tiempo de espera agotado. Verificando estado final..."
    show_status
    
    echo ""
    echo "🔍 Diagnóstico de problemas:"
    echo "=== Eventos del namespace ==="
    kubectl get events -n moodle --sort-by='.lastTimestamp'
    
    echo ""
    echo "=== Descripción de pods ==="
    kubectl describe pods -n moodle
fi

echo ""
echo "🏁 Proceso completado." 