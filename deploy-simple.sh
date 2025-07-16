#!/bin/bash

echo "🚀 Despliegue simplificado de Moodle en GKE..."

# Limpiar todo
echo "🧹 Limpiando recursos existentes..."
kubectl delete namespace moodle --ignore-not-found=true
sleep 15

# Crear namespace
echo "📁 Creando namespace moodle..."
kubectl create namespace moodle

# Aplicar configuración
echo "📦 Aplicando configuración de Moodle..."
kubectl apply -f k8s-moodle-simple.yaml

echo "⏳ Esperando 30 segundos para que se inicien los pods..."
sleep 30

# Monitorear el despliegue
echo "📊 Monitoreando despliegue..."
while true; do
    echo "=== Estado de los pods ==="
    kubectl get pods -n moodle -o wide
    
    echo ""
    echo "=== Estado de los servicios ==="
    kubectl get svc -n moodle
    
    echo ""
    echo "=== Estado de los PVCs ==="
    kubectl get pvc -n moodle
    
    # Verificar si ambos pods están corriendo
    mysql_status=$(kubectl get pods -n moodle -l app=mysql -o jsonpath='{.items[0].status.phase}' 2>/dev/null)
    moodle_status=$(kubectl get pods -n moodle -l app=moodle -o jsonpath='{.items[0].status.phase}' 2>/dev/null)
    
    if [ "$mysql_status" = "Running" ] && [ "$moodle_status" = "Running" ]; then
        echo ""
        echo "✅ ¡Ambos servicios están ejecutándose!"
        
        # Obtener IP externa
        external_ip=$(kubectl get svc moodle -n moodle -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
        if [ ! -z "$external_ip" ]; then
            echo ""
            echo "🎉 ¡MOODLE ESTÁ LISTO!"
            echo "🌐 URL: http://$external_ip"
            echo "👤 Usuario: admin"
            echo "🔑 Contraseña: moodle12345"
            echo ""
            echo "📋 Comandos útiles:"
            echo "  kubectl logs -f deployment/moodle -n moodle"
            echo "  kubectl logs -f deployment/mysql -n moodle"
            echo "  kubectl get pods -n moodle"
            break
        else
            echo "⏳ Esperando asignación de IP externa..."
        fi
    else
        echo ""
        echo "⏳ MySQL: $mysql_status, Moodle: $moodle_status"
        echo "⏳ Esperando 30 segundos más..."
    fi
    
    sleep 30
done 