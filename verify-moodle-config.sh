#!/bin/bash

echo🔍 VERIFICANDO CONFIGURACIÓN DE MOODLE Y LOADBALANCER"
echo "=================================================="

# Verificar conexión al cluster
if ! kubectl cluster-info &> /dev/null; then
    echo "❌ Error: No se puede conectar al cluster"
    exit 1
fi

echo "✅ Conexión al cluster verificada"

# 1. Verificar namespace
echo "📁 VERIFICANDO NAMESPACE:"
echo "========================"
kubectl get namespace moodle
echo ""

# 2. Verificar todos los recursos en el namespace
echo "📊 RECURSOS EN EL NAMESPACE MOODLE:"
echo "=================================="
kubectl get all -n moodle
echo ""

# 3. Verificar configuración del LoadBalancer
echo "🌐 CONFIGURACIÓN DEL LOADBALANCER:"
echo "================================="
kubectl get service moodle -n moodle -o yaml
echo ""

# 4. Verificar detalles del servicio
echo "🔧 DETALLES DEL SERVICIO MOODLE:"
echo "==============================="
kubectl describe service moodle -n moodle
echo ""

# 5. Verificar endpoints
echo "📍 ENDPOINTS DEL SERVICIO:"
echo "========================="
kubectl get endpoints moodle -n moodle
echo ""

# 6. Verificar configuración de los pods
echo "📦 CONFIGURACIÓN DE LOS PODS:"
echo "============================"
kubectl get pods -n moodle -o wide
echo ""

# 7. Verificar configuración del deployment
echo "🚀 CONFIGURACIÓN DEL DEPLOYMENT:"
echo "==============================="
kubectl get deployment moodle -n moodle -o yaml
echo ""

# 8. Verificar variables de entorno
echo "🔧 VARIABLES DE ENTORNO:"
echo "======================="
MOODLE_POD=$(kubectl get pods -n moodle -l app=moodle -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ ! -z "$MOODLE_POD" ]; then
    echo "Pod de Moodle: $MOODLE_POD"
    kubectl exec -n moodle $MOODLE_POD -- env | grep -E "(MOODLE_|MYSQL_)" | sort
else
    echo "❌ No se pudo obtener el pod de Moodle"
fi
echo ""

# 9. Verificar conectividad del LoadBalancer
echo "🌐 VERIFICANDO CONECTIVIDAD:"
echo "==========================="
LB_IP=$(kubectl get service moodle -n moodle -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
if [ ! -z "$LB_IP" ] && [ "$LB_IP" != "null" ]; then
    echo "✅ LoadBalancer IP: $LB_IP"
    echo "🔗 URL de acceso: http://$LB_IP"
    
    # Verificar si responde HTTP
    echo "🔍 Verificando respuesta HTTP..."
    if command -v curl &> /dev/null; then
        HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://$LB_IP --connect-timeout 10)
        if [ "$HTTP_STATUS" = "200" ]; then
            echo "✅ HTTP Status: $HTTP_STATUS - Moodle responde correctamente"
        else
            echo "⚠️  HTTP Status: $HTTP_STATUS - Verificar configuración"
        fi
    else
        echo "ℹ️  curl no disponible para verificar conectividad"
    fi
else
    echo "⏳ LoadBalancer aún configurándose..."
fi
echo ""

# 10. Verificar logs del LoadBalancer
echo "📋 LOGS DEL LOADBALANCER:"
echo "========================"
kubectl get events -n moodle --sort-by='.lastTimestamp' | grep -i "loadbalancer\|service" | tail -10
echo ""

# 11. Verificar configuración de red
echo "🌐 CONFIGURACIÓN DE RED:"
echo "======================="
echo "🔍 Verificando puertos..."
kubectl get service moodle -n moodle -o jsonpath='{.spec.ports[0].port} -> {.spec.ports[0].targetPort}'
echo ""

# 12. Verificar health checks
echo "💚 VERIFICANDO HEALTH CHECKS:"
echo "============================"
if [ ! -z "$MOODLE_POD" ]; then
    echo "🔍 Liveness Probe:"
    kubectl get pod $MOODLE_POD -n moodle -o jsonpath='{.spec.containers[0].livenessProbe}' | jq . 2>/dev/null || echo "No disponible"
    echo ""
    echo "🔍 Readiness Probe:"
    kubectl get pod $MOODLE_POD -n moodle -o jsonpath='{.spec.containers[0].readinessProbe}' | jq . 2>/dev/null || echo "No disponible"
else
    echo "❌ No se pudo obtener información del pod"
fi
echo ""

# 13. Verificar recursos asignados
echo "💾 RECURSOS ASIGNADOS:"
echo "====================="
kubectl get pods -n moodle -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[0].resources.requests.memory}{"\t"}{.spec.containers[0].resources.limits.memory}{"\n"}{end}'
echo ""

echo "✅ Verificación completada!"
echo ""
echo "🔧 Comandos útiles adicionales:"
echo "  - Ver logs en tiempo real: kubectl logs -n moodle -l app=moodle -f"
echo "  - Ver eventos: kubectl get events -n moodle --sort-by='.lastTimestamp'"
echo "  - Verificar conectividad: curl -I http://$LB_IP"
echo "  - Acceder al pod: kubectl exec -it -n moodle $MOODLE_POD -- bash" 