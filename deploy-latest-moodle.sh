#!/bin/bash

echo🚀 INSTALANDO LA ÚLTIMA VERSIÓN DE MOODLE"
echo "=========================================="

# Verificar conexión al cluster
if ! kubectl cluster-info &> /dev/null; then
    echo "❌ Error: No se puede conectar al cluster"
    exit 1
fi

echo "✅ Conexión al cluster verificada# Verificar que el namespace moodle existe
if ! kubectl get namespace moodle &> /dev/null; then
    echo "❌ Error: El namespace moodle' no existe"
    exit 1
fi

echo "✅ Namespace 'moodle encontrado"

#1Crear secrets
echo "🔐 Creando secrets..."
kubectl create secret generic mysql-secret \
  --from-literal=mysql-password=MySecurePassword123! \
  --from-literal=mysql-root-password=MySecureRootPassword123! \
  -n moodle --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic moodle-secret \
  --from-literal=moodle-password=AdminPassword123! \
  -n moodle --dry-run=client -o yaml | kubectl apply -f -

#2ear PVC para MySQL
echo "💾 Creando PVC para MySQL..."
cat <<EOF | kubectl apply -f -
apiVersion: v1: PersistentVolumeClaim
metadata:
  name: mysql-data-pvc
  namespace: moodle
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 8Gi
  storageClassName: standard
EOF

#3rear PVC para Moodle
echo "💾 Creando PVC para Moodle..."
cat <<EOF | kubectl apply -f -
apiVersion: v1: PersistentVolumeClaim
metadata:
  name: moodle-data-pvc
  namespace: moodle
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
  storageClassName: standard
EOF

# 4. Desplegar MySQL
echo "🗄️ Desplegando MySQL..."
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mysql
  namespace: moodle
  labels:
    app: mysql
spec:
  replicas:1elector:
    matchLabels:
      app: mysql
  template:
    metadata:
      labels:
        app: mysql
    spec:
      containers:
      - name: mysql
        image: bitnami/mysql:80    ports:
        - containerPort: 3306      env:
        - name: MYSQL_DATABASE
          value: moodle"
        - name: MYSQL_USER
          value: moodle"
        - name: MYSQL_PASSWORD
          valueFrom:
            secretKeyRef:
              name: mysql-secret
              key: mysql-password
        - name: MYSQL_ROOT_PASSWORD
          valueFrom:
            secretKeyRef:
              name: mysql-secret
              key: mysql-root-password
        volumeMounts:
        - name: mysql-data
          mountPath: /bitnami/mysql
        resources:
          requests:
            memory: "512i            cpu: "250m          limits:
            memory:1Gi            cpu: "50m"
      volumes:
      - name: mysql-data
        persistentVolumeClaim:
          claimName: mysql-data-pvc
EOF

#5rear servicio para MySQL
echo "🌐 Creando servicio para MySQL..."
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: mysql
  namespace: moodle
  labels:
    app: mysql
spec:
  ports:
  - port: 3306   targetPort:336 selector:
    app: mysql
EOF

# 6. Esperar a que MySQL esté listo
echo ⏳ Esperando a que MySQL esté listo..."
kubectl wait --for=condition=ready pod -l app=mysql -n moodle --timeout=3007. Desplegar Moodle con la ÚLTIMA versión
echo "🎓 Desplegando Moodle (última versión)..."
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: moodle
  namespace: moodle
  labels:
    app: moodle
spec:
  replicas:1elector:
    matchLabels:
      app: moodle
  template:
    metadata:
      labels:
        app: moodle
    spec:
      containers:
      - name: moodle
        image: bitnami/moodle:latest
        ports:
        - containerPort: 8080      env:
        - name: MOODLE_DATABASE_HOST
          value:mysql"
        - name: MOODLE_DATABASE_PORT_NUMBER
          value: "3306        - name: MOODLE_DATABASE_NAME
          value: moodle"
        - name: MOODLE_DATABASE_USER
          value: moodle"
        - name: MOODLE_DATABASE_PASSWORD
          valueFrom:
            secretKeyRef:
              name: mysql-secret
              key: mysql-password
        - name: MOODLE_USERNAME
          value:admin"
        - name: MOODLE_PASSWORD
          valueFrom:
            secretKeyRef:
              name: moodle-secret
              key: moodle-password
        - name: MOODLE_EMAIL
          value: "admin@moodle.local"
        - name: MOODLE_SITE_NAME
          value: Mi Campus Virtual"
        - name: MOODLE_SKIP_BOOTSTRAP
          value: "no"
        - name: MOODLE_DATABASE_TYPE
          value: mysqli"
        - name: MOODLE_ENABLE_HTTPS
          value: "no"
        - name: MOODLE_ENABLE_EMPTY_PASSWORD
          value: "no"
        - name: MOODLE_ENABLE_DATABASE_SSL
          value: "no"
        volumeMounts:
        - name: moodle-data
          mountPath: /bitnami/moodle
        resources:
          requests:
            memory:1Gi            cpu: "500m          limits:
            memory:2Gi            cpu: "1       livenessProbe:
          httpGet:
            path: /
            port: 8080
          initialDelaySeconds: 60     periodSeconds: 30
          timeoutSeconds: 1
          failureThreshold: 3
        readinessProbe:
          httpGet:
            path: /
            port: 8080
          initialDelaySeconds: 30     periodSeconds: 10
          timeoutSeconds: 1
          failureThreshold:3    volumes:
      - name: moodle-data
        persistentVolumeClaim:
          claimName: moodle-data-pvc
EOF

#8rear servicio LoadBalancer para Moodle
echo "🌐 Creando LoadBalancer para Moodle..."
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: moodle
  namespace: moodle
  labels:
    app: moodle
spec:
  type: LoadBalancer
  ports:
  - port: 80   targetPort: 8080
    protocol: TCP
  selector:
    app: moodle
EOF

# 9. Esperar a que Moodle esté listo
echo ⏳ Esperando a que Moodle esté listo..."
kubectl wait --for=condition=ready pod -l app=moodle -n moodle --timeout=600s

# 10. Verificar estado final
echo "🔍 Verificando estado final...
echo 📊Pods:kubectl get pods -n moodle

echo ""
echo🌐 Servicios:"
kubectl get services -n moodle

echo
echo 💾PVCs:"
kubectl get pvc -n moodle

# 11btener IP del LoadBalancer
echo ho 🌐 IP del LoadBalancer:"
LB_IP=$(kubectl get service moodle -n moodle -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo Configurándose...")
echo "Moodle estará disponible en: http://$LB_IP

#12 Verificar versión de Moodle
echo "
echo "📋 Verificando versión de Moodle...
sleep 30bectl exec -n moodle -it $(kubectl get pods -n moodle -l app=moodle -o jsonpath='{.items[0].metadata.name}) -- cat /opt/bitnami/moodle/version.php | grep "\$release || echoVerificando versión...
echo ho "✅ ¡Instalación completada!"
echo 🎓 Moodle (última versión) está listo para usar
echo 
echo "🔧 Comandos útiles:"
echo   - Ver logs: kubectl logs -n moodle -l app=moodle -f"
echo "  - Ver estado: kubectl get pods -n moodle"
echo   - Ver servicios: kubectl get services -n moodle"
echo - Acceder: http://$LB_IP
echo ""
echo "👤 Credenciales por defecto:"
echo "  - Usuario: admin"
echo "  - Contraseña: AdminPassword123!" 