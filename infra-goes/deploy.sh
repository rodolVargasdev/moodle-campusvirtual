#!/bin/bash

# Script de Despliegue de Moodle
# Este script despliega Moodle con cluster MariaDB

set -e

# Configuración
NAMESPACE="moodle"
MARIADB_PASSWORD="Admin123!"
MOODLE_PASSWORD="Admin123!"

echo "Creando namespace..."
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

echo "Desplegando cluster MariaDB..."
kubectl apply -f mariadb-deployment.yaml

echo "Esperando a que MariaDB esté listo..."
kubectl wait --for=condition=ready pod -l app=mariadb -n $NAMESPACE --timeout=300s

echo "Creando PVCs..."
kubectl apply -f moodle-pvcs.yaml

echo "Aplicando configuración de Moodle..."
kubectl apply -f moodle-config.yaml

echo "Desplegando Moodle..."
kubectl apply -f deployment.yaml

echo "Creando servicio..."
kubectl apply -f service.yaml

echo "Esperando a que Moodle esté listo..."
kubectl wait --for=condition=ready pod -l app=moodle-complete -n $NAMESPACE --timeout=600s

echo "¡Despliegue completado!"
echo "Para acceder a Moodle:"
echo "kubectl port-forward -n $NAMESPACE svc/moodle-service 8080:80"
echo "Luego visitar: http://localhost:8080"
