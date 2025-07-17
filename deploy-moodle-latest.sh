#!/bin/bash

echo "=== Desplegando Moodle con imagen latest ==="

# Verificar que estamos conectados al cluster
echo "Verificando conexión al cluster..."
kubectl cluster-info

# Crear namespace si no existe
echo "Creando namespace moodle..."
kubectl create namespace moodle --dry-run=client -o yaml | kubectl apply -f -

# Crear IP estática global
echo "Creando IP estática global..."
gcloud compute addresses create moodle-ip --global --quiet || echo "IP estática ya existe"

# Aplicar todos los archivos YAML
echo "Aplicando configuración de Moodle..."
kubectl apply -f .

# Esperar a que los PVCs estén listos
echo "Esperando a que los PVCs estén listos..."
kubectl wait --for=condition=Bound pvc/moodle-data-pvc -n moodle --timeout=300s
kubectl wait --for=condition=Bound pvc/moodle-moodledata-pvc -n moodle --timeout=300s

# Mostrar estado inicial
echo "Estado inicial de los recursos:"
kubectl get pods,pvc,svc -n moodle

echo ""
echo "=== Despliegue completado ==="
echo "Para verificar el estado:"
echo "  kubectl get pods -n moodle"
echo "  kubectl get svc -n moodle"
echo "  kubectl get ingress -n moodle"
echo ""
echo "Para ver logs:"
echo "  kubectl logs -n moodle deployment/moodle --tail=50"
echo ""
echo "Para verificar la IP estática:"
echo "  gcloud compute addresses list" 