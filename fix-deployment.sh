#!/bin/bash

echo "🔧 === SOLUCIONANDO CONFLICTO DE DEPLOYMENT ==="
echo ""

# Eliminar el deployment anterior
echo "🗑️ Eliminando deployment anterior..."
kubectl delete deployment moodle -n moodle --ignore-not-found=true

# Esperar a que se elimine completamente
echo "⏳ Esperando a que se elimine el deployment anterior..."
kubectl wait --for=delete deployment/moodle -n moodle --timeout=60s 2>/dev/null || echo "✅ Deployment anterior eliminado"

# Aplicar el nuevo deployment
echo "🚀 Aplicando nuevo deployment..."
kubectl apply -f simple-moodle-deployment.yaml

# Mostrar estado
echo "📊 Estado de los recursos:"
kubectl get pods,pvc,svc -n moodle

echo ""
echo "✅ ¡Deployment corregido!"
echo ""
echo "🔍 Para verificar:"
echo "   kubectl get pods -n moodle"
echo "   kubectl logs -n moodle deployment/moodle --tail=50" 