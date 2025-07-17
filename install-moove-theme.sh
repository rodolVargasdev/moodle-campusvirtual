#!/bin/bash

# Script para instalar el tema Moove en Moodle (Kubernetes)
# Requiere: kubectl configurado y acceso al cluster

set -e

echo "=== Instalación del tema Moove en Moodle ==="

# Obtener el nombre del pod de Moodle
POD_NAME=$(kubectl get pods -l app.kubernetes.io/name=moodle -o jsonpath='{.items[0].metadata.name}')

if [ -z "$POD_NAME" ]; then
    echo "Error: No se pudo encontrar el pod de Moodle"
    exit 1
fi

echo "Pod de Moodle encontrado: $POD_NAME"

# Verificar que el pod esté ejecutándose
POD_STATUS=$(kubectl get pod $POD_NAME -o jsonpath='{.status.phase}')
if [ "$POD_STATUS" != "Running" ]; then
    echo "Error: El pod de Moodle no está ejecutándose (estado: $POD_STATUS)"
    exit 1
fi

echo "Estado del pod: $POD_STATUS"

echo "Creando directorio temporal para el tema..."
kubectl exec $POD_NAME -- mkdir -p /tmp/moove-theme

echo "Descargando el tema Moove..."
kubectl exec $POD_NAME -- wget -O /tmp/moove-theme.zip https://github.com/willianmano/moodle-theme_moove/archive/refs/heads/master.zip

if ! kubectl exec $POD_NAME -- test -f /tmp/moove-theme.zip; then
    echo "Error: No se pudo descargar el tema Moove"
    exit 1
fi

echo "Descomprimiendo el tema..."
kubectl exec $POD_NAME -- unzip -o /tmp/moove-theme.zip -d /tmp/

echo "Instalando el tema en Moodle..."
kubectl exec $POD_NAME -- cp -r /tmp/moodle-theme_moove-master /bitnami/moodle/theme/moove

echo "Estableciendo permisos..."
kubectl exec $POD_NAME -- chown -R daemon:daemon /bitnami/moodle/theme/moove
kubectl exec $POD_NAME -- chmod -R 755 /bitnami/moodle/theme/moove

echo "Limpiando archivos temporales..."
kubectl exec $POD_NAME -- rm -rf /tmp/moove-theme.zip /tmp/moodle-theme_moove-master

echo

echo "=== Instalación completada ==="
echo "El tema Moove ha sido instalado exitosamente."
echo

echo "Para activarlo:"
echo "1. Accede a tu sitio de Moodle"
echo "2. Ve a Administración del sitio > Apariencia > Temas"
echo "3. Busca 'Moove' y haz clic en 'Usar tema' para activarlo." 