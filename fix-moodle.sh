#!/bin/bash

echo "🔧 Arreglando Moodle - Eliminando pods problemáticos"
echo "====================================================# Eliminar pods en estado Pending/ContainerCreating
echo "🗑️ Eliminando pods problemáticos..."
kubectl delete pod moodle-6d984f7798z9x8j -n moodle --ignore-not-found=true
kubectl delete pod mysql-857949ztml8 -n moodle --ignore-not-found=true

# Forzar restart de deployments
echo "🔄 Reiniciando deployments..."
kubectl rollout restart deployment/moodle -n moodle
kubectl rollout restart deployment/mysql -n moodle

# Esperar y verificar
echo "⏳ Esperando 30 segundos...sleep 30 📊 Estado actual:kubectl get pods -n moodle
echo ho 🌐 IP del LoadBalancer:"
kubectl get service moodle -n moodle -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "Configurándose..."

echo "✅ ¡Listo!" 