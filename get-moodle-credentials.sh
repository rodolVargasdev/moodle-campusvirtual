#!/bin/bash

echo🔐 OBTENIENDO CREDENCIALES DE MOODLE"
echo "===================================="

# Verificar conexión al cluster
if ! kubectl cluster-info &> /dev/null; then
    echo "❌ Error: No se puede conectar al cluster"
    exit 1
fi

echo "✅ Conexión al cluster verificada"

# 1ar si el namespace moodle existe
if ! kubectl get namespace moodle &> /dev/null; then
    echo "❌ Error: El namespace moodle' no existe"
    exit 1
fi

echo "✅ Namespace 'moodle encontrado"

# 2. Verificar si hay pods de Moodle corriendo
if ! kubectl get pods -n moodle -l app=moodle &> /dev/null; then
    echo "❌ Error: No hay pods de Moodle corriendo"
    exit 1i

echo✅ Pods de Moodle encontrados"

# 3. Obtener credenciales desde los secrets
echo cho "🔍 CREDENCIALES DESDE SECRETS:"
echo "=============================="

# Verificar si existe el secret de Moodle
if kubectl get secret moodle-secret -n moodle &> /dev/null; then
    echo 📋 Secret de Moodle encontrado:"
    echo   Usuario: admin"
    echo    Contraseña: $(kubectl get secret moodle-secret -n moodle -o jsonpath='{.data.moodle-password}' | base64 -d)
else    echo❌ Secret de Moodle no encontrado"
fi

echo erificar si existe el secret de MySQL
if kubectl get secret mysql-secret -n moodle &> /dev/null; then
    echo "📋 Secret de MySQL encontrado:"
    echo   Usuario: moodle"
    echo    Contraseña: $(kubectl get secret mysql-secret -n moodle -o jsonpath='{.data.mysql-password}' | base64 -d)"
    echo  Root Password: $(kubectl get secret mysql-secret -n moodle -o jsonpath={.data.mysql-root-password}' | base64 -d)
else    echo ❌Secret de MySQL no encontrado
fi
# 4. Obtener credenciales desde variables de entorno del pod
echo cho "🔍 CREDENCIALES DESDE POD:"
echo "=========================="

MOODLE_POD=$(kubectl get pods -n moodle -l app=moodle -o jsonpath='{.items[0].metadata.name}2/dev/null)

if ! -z "$MOODLE_POD]; then
    echo 📋 Pod de Moodle: $MOODLE_POD"
    echo ""
    echo "🔧 Variables de entorno del pod:    kubectl exec -n moodle $MOODLE_POD -- env | grep -E (MOODLE_USERNAME|MOODLE_EMAIL|MOODLE_DATABASE_)" | sort
else
    echo "❌ No se pudo obtener el pod de Moodle
fi
# 5. Obtener credenciales desde la base de datos (si es posible)
echo cho "🔍 CREDENCIALES DESDE BASE DE DATOS:"
echo "====================================

MYSQL_POD=$(kubectl get pods -n moodle -l app=mysql -o jsonpath='{.items[0].metadata.name}2/dev/null)

if  ! -z "$MYSQL_POD]; then
    echo📋 Pod de MySQL: $MYSQL_POD"
    echo ""
    echo "🔧 Intentando obtener usuarios de Moodle desde la base de datos..."
    
    # Obtener la contraseña de MySQL
    MYSQL_PASSWORD=$(kubectl get secret mysql-secret -n moodle -o jsonpath='{.data.mysql-password}' | base642dev/null)
    
    if [ ! -z$MYSQL_PASSWORD" ]; then
        echo 📊 Usuarios en la base de datos Moodle:"
        kubectl exec -n moodle $MYSQL_POD -- mysql -u moodle -p$MYSQL_PASSWORD moodle -eSELECT username, email, firstname, lastname FROM mdl_user WHERE deleted = 0 AND suspended =0 ORDER BY id LIMIT 10>/dev/null || echo❌No se pudo acceder a la base de datos else
        echo "❌ No se pudo obtener la contraseña de MySQL"
    fi
else
    echo "❌ No se pudo obtener el pod de MySQL
fi

# 6. Obtener información de acceso
echo ho 🌐INFORMACIÓN DE ACCESO:"
echo========================"

# Obtener IP del LoadBalancer
LB_IP=$(kubectl get service moodle -n moodle -o jsonpath='{.status.loadBalancer.ingress[0].ip}2/dev/null)

if! -z $LB_IP" ] && [ $LB_IP" != null]; then
    echo "✅ Moodle está disponible en: http://$LB_IP
else
    echo "⏳ LoadBalancer aún configurándose...  echo "🔍 Verificando estado del servicio:"
    kubectl get service moodle -n moodle
fi

# 7. Verificar estado de los pods
echo echo📊 ESTADO DE LOS PODS:"
echo=====================kubectl get pods -n moodle

echo ""
echo "✅ ¡Credenciales obtenidas!
echo 
echo "🔧 Comandos útiles adicionales:"
echo "  - Ver logs de Moodle: kubectl logs -n moodle -l app=moodle -f"
echo "  - Ver logs de MySQL: kubectl logs -n moodle -l app=mysql -f"
echo "  - Acceder al pod de Moodle: kubectl exec -it -n moodle $MOODLE_POD -- bash"
echo "  - Acceder a MySQL: kubectl exec -it -n moodle $MYSQL_POD -- mysql -u moodle -p" 