#!/bin/bash

echo "=== Limpiando despliegue de Moodle ==="

# Eliminar todos los recursos de Kubernetes
echo "Eliminando recursos de Kubernetes..."
kubectl delete -f . --ignore-not-found=true

# Eliminar namespace
echo "Eliminando namespace moodle..."
kubectl delete namespace moodle --ignore-not-found=true

# Eliminar IP estática
echo "Eliminando IP estática..."
gcloud compute addresses delete moodle-ip --global --quiet || echo "IP estática no existe"

echo ""
echo "=== Limpieza completada ==="
echo "Todos los recursos han sido eliminados." 