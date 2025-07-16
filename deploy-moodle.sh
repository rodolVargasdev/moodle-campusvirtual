#!/bin/bash

echo "🚀 Iniciando despliegue completo de Moodle en GKE..."

# Configurar el contexto del cluster
echo "📋 Configurando contexto del cluster..."
kubectl config current-context

# Limpiar recursos existentes si los hay
echo "🧹 Limpiando recursos existentes..."
kubectl delete namespace moodle --ignore-not-found=true
kubectl delete pvc --all --ignore-not-found=true -n moodle

# Esperar a que se elimine el namespace
echo "⏳ Esperando eliminación del namespace..."
sleep 10

# Crear namespace
echo "📁 Creando namespace moodle..."
kubectl create namespace moodle

# Aplicar el deployment completo
echo "📦 Aplicando configuración de Moodle..."
kubectl apply -f k8s-moodle-deployment.yaml

# Esperar a que se creen los PVCs
echo "⏳ Esperando creación de PVCs..."
sleep 10

# Verificar estado de los recursos
echo "🔍 Verificando estado de los recursos..."
echo "=== PVCs ==="
kubectl get pvc -n moodle

echo "=== Pods ==="
kubectl get pods -n moodle

echo "=== Services ==="
kubectl get svc -n moodle

# Función para monitorear el estado
monitor_deployment() {
    echo "📊 Monitoreando despliegue..."
    while true; do
        echo "=== Estado actual ==="
        kubectl get pods -n moodle -o wide
        echo ""
        
        # Verificar si MySQL está listo
        mysql_ready=$(kubectl get pods -n moodle -l app=mysql -o jsonpath='{.items[0].status.phase}' 2>/dev/null)
        if [ "$mysql_ready" = "Running" ]; then
            echo "✅ MySQL está ejecutándose"
        else
            echo "⏳ MySQL aún no está listo..."
        fi
        
        # Verificar si Moodle está listo
        moodle_ready=$(kubectl get pods -n moodle -l app=moodle -o jsonpath='{.items[0].status.phase}' 2>/dev/null)
        if [ "$moodle_ready" = "Running" ]; then
            echo "✅ Moodle está ejecutándose"
            
            # Obtener IP externa
            external_ip=$(kubectl get svc moodle -n moodle -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
            if [ ! -z "$external_ip" ]; then
                echo "🌐 Moodle disponible en: http://$external_ip"
                echo "👤 Usuario: admin"
                echo "🔑 Contraseña: moodle12345"
                break
            else
                echo "⏳ Esperando asignación de IP externa..."
            fi
        else
            echo "⏳ Moodle aún no está listo..."
        fi
        
        echo "⏳ Esperando 30 segundos..."
        sleep 30
    done
}

# Iniciar monitoreo
monitor_deployment

echo ""
echo "🎉 ¡Despliegue completado!"
echo "📋 Comandos útiles:"
echo "  kubectl get pods -n moodle"
echo "  kubectl logs -f deployment/moodle -n moodle"
echo "  kubectl logs -f deployment/mysql -n moodle"
echo "  kubectl get svc -n moodle" 