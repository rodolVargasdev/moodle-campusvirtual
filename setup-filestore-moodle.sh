#!/bin/bash

echo "🚀 CONFIGURACIÓN COMPLETA DE MOODLE ESCALABLE CON FILESTORE"
echo "=========================================================="

# Variables de configuración
PROJECT_ID="g-moddle-dev-prj-jnld"
CLUSTER_NAME="us-east1-dev-moodle-gke-02"
ZONE="us-east1-b"
FILESTORE_NAME="moodle-filestore"
FILESTORE_TIER="BASIC_HDD"
FILESTORE_SIZE_GB="1024"
FILESTORE_NETWORK="us-east1-dev-moodle-vpc-01"

echo "📋 Configuración:"
echo "   Proyecto: $PROJECT_ID"
echo "   Cluster: $CLUSTER_NAME"
echo "   Zona: $ZONE"
echo "   Filestore: $FILESTORE_NAME"
echo ""

# Verificar que gcloud esté configurado
echo "🔍 Verificando configuración de gcloud..."
if ! gcloud config get-value project &>/dev/null; then
    echo "❌ Error: gcloud no está configurado. Ejecuta 'gcloud auth login' primero."
    exit 1
fi

# Configurar proyecto
echo "📁 Configurando proyecto..."
gcloud config set project $PROJECT_ID

# Habilitar APIs necesarias
echo "🔧 Habilitando APIs necesarias..."
gcloud services enable file.googleapis.com
gcloud services enable compute.googleapis.com

# Crear Filestore instance
echo "🗄️ Creando instancia de Filestore..."
gcloud filestore instances create $FILESTORE_NAME \
    --zone=$ZONE \
    --tier=$FILESTORE_TIER \
    --file-share=name="moodle-share",capacity=${FILESTORE_SIZE_GB}GB \
    --network=name=$FILESTORE_NETWORK \
    --description="Filestore para Moodle escalable"

# Obtener IP del Filestore
echo "⏳ Esperando que Filestore esté listo..."
sleep 30
FILESTORE_IP=$(gcloud filestore instances describe $FILESTORE_NAME --zone=$ZONE --format="value(fileShares[0].ipAddresses[0])")
echo "✅ Filestore creado con IP: $FILESTORE_IP"

# Crear StorageClass para Filestore
echo "📦 Creando StorageClass para Filestore..."
cat <<EOF | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: filestore-rwx
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
EOF

# Crear PersistentVolume para Filestore
echo "💾 Creando PersistentVolume..."
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolume
metadata:
  name: moodle-filestore-pv
spec:
  capacity:
    storage: ${FILESTORE_SIZE_GB}Gi
  accessModes:
    - ReadWriteMany
  persistentVolumeReclaimPolicy: Retain
  storageClassName: filestore-rwx
  nfs:
    server: $FILESTORE_IP
    path: /moodle-share
EOF

# Crear PVC para Filestore
echo "🔗 Creando PersistentVolumeClaim..."
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: moodle-filestore-pvc
  namespace: moodle
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: filestore-rwx
  resources:
    requests:
      storage: ${FILESTORE_SIZE_GB}Gi
EOF

# Limpiar deployment anterior
echo "🧹 Limpiando deployment anterior..."
kubectl delete deployment moodle-scaled -n moodle --ignore-not-found=true
kubectl delete service moodle-scaled -n moodle --ignore-not-found=true
kubectl delete pvc moodle-data-pvc-rwm -n moodle --ignore-not-found=true

# Crear deployment escalable con Filestore
echo "🚀 Creando deployment escalable con Filestore..."
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: moodle-config
  namespace: moodle
data:
  MOODLE_DATABASE_HOST: "mysql"
  MOODLE_DATABASE_PORT_NUMBER: "3306"
  MOODLE_DATABASE_NAME: "moodle"
  MOODLE_DATABASE_USER: "moodle"
  MOODLE_DATABASE_TYPE: "mysqli"
  MOODLE_ENABLE_HTTPS: "no"
  MOODLE_ENABLE_EMPTY_PASSWORD: "no"
  MOODLE_ENABLE_DATABASE_SSL: "no"
  MOODLE_EXTRA_INSTALL_ARGS: "--allow-unstable"
  MOODLE_SITE_NAME: "Campus Virtual GKE Escalable"
  MOODLE_SKIP_BOOTSTRAP: "no"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: moodle-scalable
  namespace: moodle
  labels:
    app: moodle-scalable
spec:
  replicas: 3
  selector:
    matchLabels:
      app: moodle-scalable
  template:
    metadata:
      labels:
        app: moodle-scalable
    spec:
      containers:
      - name: moodle
        image: bitnami/moodle:4.3.4
        ports:
        - containerPort: 8080
        env:
        - name: MOODLE_DATABASE_HOST
          valueFrom:
            configMapKeyRef:
              name: moodle-config
              key: MOODLE_DATABASE_HOST
        - name: MOODLE_DATABASE_PORT_NUMBER
          valueFrom:
            configMapKeyRef:
              name: moodle-config
              key: MOODLE_DATABASE_PORT_NUMBER
        - name: MOODLE_DATABASE_NAME
          valueFrom:
            configMapKeyRef:
              name: moodle-config
              key: MOODLE_DATABASE_NAME
        - name: MOODLE_DATABASE_USER
          valueFrom:
            configMapKeyRef:
              name: moodle-config
              key: MOODLE_DATABASE_USER
        - name: MOODLE_DATABASE_PASSWORD
          valueFrom:
            secretKeyRef:
              name: mysql-secret
              key: mysql-password
        - name: MOODLE_USERNAME
          value: "admin"
        - name: MOODLE_PASSWORD
          value: "moodle12345"
        - name: MOODLE_EMAIL
          value: "admin@moodle.local"
        - name: MOODLE_SITE_NAME
          valueFrom:
            configMapKeyRef:
              name: moodle-config
              key: MOODLE_SITE_NAME
        - name: MOODLE_SKIP_BOOTSTRAP
          valueFrom:
            configMapKeyRef:
              name: moodle-config
              key: MOODLE_SKIP_BOOTSTRAP
        - name: MOODLE_DATABASE_TYPE
          valueFrom:
            configMapKeyRef:
              name: moodle-config
              key: MOODLE_DATABASE_TYPE
        - name: MOODLE_ENABLE_HTTPS
          valueFrom:
            configMapKeyRef:
              name: moodle-config
              key: MOODLE_ENABLE_HTTPS
        - name: MOODLE_ENABLE_EMPTY_PASSWORD
          valueFrom:
            configMapKeyRef:
              name: moodle-config
              key: MOODLE_ENABLE_EMPTY_PASSWORD
        - name: MOODLE_ENABLE_DATABASE_SSL
          valueFrom:
            configMapKeyRef:
              name: moodle-config
              key: MOODLE_ENABLE_DATABASE_SSL
        - name: MOODLE_EXTRA_INSTALL_ARGS
          valueFrom:
            configMapKeyRef:
              name: moodle-config
              key: MOODLE_EXTRA_INSTALL_ARGS
        volumeMounts:
        - name: moodle-data
          mountPath: /bitnami/moodle
        resources:
          requests:
            memory: "1Gi"
            cpu: "500m"
          limits:
            memory: "2Gi"
            cpu: "1000m"
        readinessProbe:
          httpGet:
            path: /
            port: 8080
            httpHeaders:
            - name: Host
              value: localhost
          initialDelaySeconds: 120
          periodSeconds: 20
          timeoutSeconds: 10
          failureThreshold: 3
          successThreshold: 1
        livenessProbe:
          httpGet:
            path: /
            port: 8080
            httpHeaders:
            - name: Host
              value: localhost
          initialDelaySeconds: 180
          periodSeconds: 30
          timeoutSeconds: 10
          failureThreshold: 3
          successThreshold: 1
      volumes:
      - name: moodle-data
        persistentVolumeClaim:
          claimName: moodle-filestore-pvc
---
apiVersion: v1
kind: Service
metadata:
  name: moodle-scalable
  namespace: moodle
  labels:
    app: moodle-scalable
spec:
  type: LoadBalancer
  ports:
  - port: 80
    targetPort: 8080
    protocol: TCP
    name: http
  selector:
    app: moodle-scalable
  sessionAffinity: None
EOF

echo "⏳ Esperando 60 segundos para que se inicien los pods..."
sleep 60

# Monitorear el despliegue
echo "📊 Monitoreando despliegue..."
attempt=1
max_attempts=15

while [ $attempt -le $max_attempts ]; do
    echo ""
    echo "🔄 Intento $attempt de $max_attempts"
    echo "=================================="
    
    # Verificar estado de los pods
    kubectl get pods -n moodle -l app=moodle-scalable
    
    # Verificar si todos los pods están listos
    ready_pods=$(kubectl get pods -n moodle -l app=moodle-scalable --no-headers | grep -c "Running")
    total_pods=$(kubectl get pods -n moodle -l app=moodle-scalable --no-headers | wc -l)
    
    if [ "$ready_pods" -eq "$total_pods" ] && [ "$total_pods" -gt 0 ]; then
        echo ""
        echo "✅ ¡Todos los pods están ejecutándose!"
        
        # Obtener IP externa
        external_ip=$(kubectl get svc moodle-scalable -n moodle -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
        if [ ! -z "$external_ip" ]; then
            echo ""
            echo "🎉 ¡MOODLE ESCALABLE ESTÁ LISTO!"
            echo "================================="
            echo "🌐 URL de acceso: http://$external_ip"
            echo "👤 Usuario: admin"
            echo "🔑 Contraseña: moodle12345"
            echo ""
            echo "📊 Información del escalado:"
            echo "   - Pods ejecutándose: $ready_pods"
            echo "   - Filestore IP: $FILESTORE_IP"
            echo "   - Storage: ${FILESTORE_SIZE_GB}GB compartido"
            echo ""
            echo "🔧 Comandos útiles:"
            echo "   kubectl get pods -n moodle"
            echo "   kubectl scale deployment moodle-scalable --replicas=5 -n moodle"
            echo "   kubectl get svc -n moodle"
            break
        else
            echo "⏳ Esperando asignación de IP externa..."
        fi
    else
        echo "⏳ Esperando que los pods estén listos... ($ready_pods/$total_pods)"
        sleep 30
    fi
    
    attempt=$((attempt + 1))
done

if [ $attempt -gt $max_attempts ]; then
    echo ""
    echo "❌ Tiempo de espera agotado. Verificando estado final..."
    kubectl get pods -n moodle
    kubectl get svc -n moodle
    echo ""
    echo "🔍 Para diagnosticar problemas:"
    echo "   kubectl describe pods -n moodle"
    echo "   kubectl logs -l app=moodle-scalable -n moodle"
fi

echo ""
echo "🏁 Configuración completada."
echo "📋 Recursos creados:"
echo "   - Filestore: $FILESTORE_NAME"
echo "   - StorageClass: filestore-rwx"
echo "   - PersistentVolume: moodle-filestore-pv"
echo "   - Deployment: moodle-scalable (3 réplicas)"
echo "   - Service: moodle-scalable (LoadBalancer)" 