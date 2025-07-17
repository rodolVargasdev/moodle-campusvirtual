#!/bin/bash

echo "🚀 === DESPLIEGUE SIMPLE DE MOODLE ==="
echo "📅 Fecha: $(date)"
echo ""

# Crear namespace
echo "📁 Creando namespace moodle..."
kubectl create namespace moodle --dry-run=client -o yaml | kubectl apply -f -

# Crear IP estática si no existe
echo "🌐 Verificando IP estática..."
gcloud compute addresses create moodle-ip --global --quiet || echo "✅ IP estática ya existe"

# Generar certificados SSL si no existen
echo "🔐 Verificando certificados SSL..."
if ! kubectl get secret cloudflare-cert -n moodle &> /dev/null; then
    echo "⚠️  Generando certificados SSL temporales..."
    mkdir -p ssl-certs
    cd ssl-certs
    openssl genrsa -out key.pem 2048
    openssl req -new -x509 -key key.pem -out cert.pem -days 365 -subj "/C=SV/ST=San Salvador/L=San Salvador/O=Telesalud/OU=IT/CN=campusvirtual.telesalud.gob.sv"
    kubectl create secret tls cloudflare-cert --cert=cert.pem --key=key.pem -n moodle
    cd ..
    echo "✅ Certificados SSL generados"
else
    echo "✅ Certificados SSL ya existen"
fi

# Verificar si existe un deployment anterior
echo "🔍 Verificando deployment anterior..."
if kubectl get deployment moodle -n moodle &> /dev/null; then
    echo "⚠️  Eliminando deployment anterior..."
    kubectl delete deployment moodle -n moodle
    echo "⏳ Esperando a que se elimine..."
    kubectl wait --for=delete deployment/moodle -n moodle --timeout=60s 2>/dev/null || echo "✅ Deployment anterior eliminado"
fi

# Aplicar configuración
echo "📋 Aplicando configuración de Moodle..."
kubectl apply -f simple-moodle-deployment.yaml

# Esperar a que los PVCs estén listos
echo "⏳ Esperando PVCs..."
kubectl wait --for=condition=Bound pvc/moodle-data-pvc -n moodle --timeout=300s
kubectl wait --for=condition=Bound pvc/moodle-moodledata-pvc -n moodle --timeout=300s

# Mostrar estado
echo "📊 Estado de los recursos:"
kubectl get pods,pvc,svc -n moodle

echo ""
echo "🎉 === DESPLIEGUE COMPLETADO ==="
echo ""
echo "📋 Información:"
echo "   Imagen: bitnami/moodle:latest"
echo "   Dominio: campusvirtual.telesalud.gob.sv"
echo "   Usuario: admin"
echo "   Contraseña: Admin123!"
echo ""
echo "🔍 Comandos útiles:"
echo "   kubectl get pods -n moodle"
echo "   kubectl logs -n moodle deployment/moodle --tail=50"
echo "   kubectl get ingress -n moodle"
echo ""
echo "✅ ¡Moodle está siendo desplegado!" 