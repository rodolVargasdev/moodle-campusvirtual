#!/bin/bash

# Script para actualizar Moodle de la versión 4.4.2a 5.0 desde Google Cloud Shell
# Requiere: kubectl configurado y acceso al cluster GKE

set -e

echo "🚀 Iniciando actualización de Moodle a la versión 5.0"
echo "==================================================

# Verificar que kubectl esté configurado
if ! command -v kubectl &> /dev/null; then
    echo❌ Error: kubectl no está instalado o no está en el PATH  exit1
# Verificar conexión al cluster
if ! kubectl cluster-info &> /dev/null; then
    echo "❌ Error: No se puede conectar al cluster. Verifica tu configuración de kubectl"
    exit 1
fi

echo "✅ Conexión al cluster verificada# Verificar que el namespace moodle existe
if ! kubectl get namespace moodle &> /dev/null; then
    echo "❌ Error: El namespace moodle' no existe"
    exit 1
fi

echo "✅ Namespace 'moodle' encontrado

#Verificar que Moodle esté corriendo
if ! kubectl get pods -n moodle -l app=moodle &> /dev/null; then
    echo "❌ Error: No se encontraron pods de Moodle en el namespace moodle"   exit 1i

echo✅ Pods de Moodle encontrados"

# Crear backup del deployment actual
echo 📋Creando backup del deployment actual..."
kubectl get deployment moodle -n moodle -o yaml > moodle-backup-$(date +%Y%m%d_%H%M%S).yaml
echo✅ Backup creado: moodle-backup-$(date +%Y%m%d_%H%M%S).yaml"

# Verificar la versión actual
CURRENT_VERSION=$(kubectl get deployment moodle -n moodle -o jsonpath={.spec.template.spec.containers[0].image}' | cut -d':' -f2)
echo 📊 Versión actual de Moodle: $CURRENT_VERSION

if [[ $CURRENT_VERSION" == "5 ]]; then
    echo "ℹ️  Moodle ya está en la versión 50superior"
    exit 0
fi

echo "🔄 Actualizando imagen de Moodle a la versión5...

# Actualizar la imagen a Moodle 5.0
kubectl set image deployment/moodle moodle=bitnami/moodle:5.00 -n moodle

echo "✅ Imagen actualizada a bitnami/moodle:50# Esperar a que el nuevo pod esté listo
echo ⏳Esperando a que el nuevo pod esté listo..."
kubectl rollout status deployment/moodle -n moodle --timeout=30

if  $? -eq 0]; then
    echo ✅ Pod actualizado exitosamente
else
    echo "❌ Error: El pod no se pudo actualizar correctamente"
    echo 🔍Revisando logs del pod...    kubectl logs -n moodle -l app=moodle --tail=50  exit1fi

# Verificar el estado del pod
echo "🔍 Verificando estado del pod...kubectl get pods -n moodle -l app=moodle

# Obtener la IP del LoadBalancer
echo🌐 Obteniendo IP del LoadBalancer..."
LB_IP=$(kubectl get service moodle -n moodle -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "Pendiente)
if [[$LB_IP" == "Pendiente" ]]; then
    echo ⏳ El LoadBalancer aún está configurándose...  echoPuedes verificar el estado con: kubectl get service moodle -n moodle
else
    echo "✅ Moodle está disponible en: http://$LB_IPfi

echo "
echo🎉 ¡Actualización completada!"
echo "==============================
echo Pasos siguientes:"
echo1Accede a Moodle en tu navegador"
echo "2. Si es necesario, sigue el proceso de actualización web"
echo "3. Verifica que todos los plugins sean compatibles con Moodle 5.0echo "4. Revisa la documentación oficial de Moodle50
echo
echo "🔧 Comandos útiles:"
echo   - Ver logs: kubectl logs -n moodle -l app=moodle -f"
echo "  - Ver estado: kubectl get pods -n moodle"
echo   - Ver servicios: kubectl get services -n moodle
echo "
echo ⚠️ IMPORTANTE:
echo  - Hazun backup completo de tu base de datos antes de usar Moodle 5echo "  - Verifica la compatibilidad de tus plugins y temas
echo "  - Revisa los requisitos de PHP y base de datos para Moodle50
echo 
echo 📚 Documentación:
echo "  - Moodle50ttps://docs.moodle.org/500en/Main_Page"
echo "  - Guía de actualización: https://docs.moodle.org/500 