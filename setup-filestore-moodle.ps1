# PowerShell script para configuración de Moodle escalable con Filestore

Write-Host "🚀 CONFIGURACIÓN COMPLETA DE MOODLE ESCALABLE CON FILESTORE (POWERSHELL)" -ForegroundColor Green
Write-Host "======================================================================" -ForegroundColor Green

# Variables de configuración
$PROJECT_ID = "g-moddle-dev-prj-jnld"
$CLUSTER_NAME = "us-east1-dev-moodle-gke-02"
$ZONE = "us-east1-b"
$FILESTORE_NAME = "moodle-filestore"
$FILESTORE_TIER = "BASIC_HDD"
$FILESTORE_SIZE_GB = "1024"
$FILESTORE_NETWORK = "us-east1-dev-moodle-vpc-01"

Write-Host "📋 Configuración:" -ForegroundColor Yellow
Write-Host "   Proyecto: $PROJECT_ID" -ForegroundColor White
Write-Host "   Cluster: $CLUSTER_NAME" -ForegroundColor White
Write-Host "   Zona: $ZONE" -ForegroundColor White
Write-Host "   Filestore: $FILESTORE_NAME" -ForegroundColor White
Write-Host ""

# Verificar que gcloud esté configurado
Write-Host "🔍 Verificando configuración de gcloud..." -ForegroundColor Yellow
try {
    $null = gcloud config get-value project 2>$null
} catch {
    Write-Host "❌ Error: gcloud no está configurado. Ejecuta 'gcloud auth login' primero." -ForegroundColor Red
    exit 1
}

# Configurar proyecto
Write-Host "📁 Configurando proyecto..." -ForegroundColor Yellow
gcloud config set project $PROJECT_ID

# Habilitar APIs necesarias
Write-Host "🔧 Habilitando APIs necesarias..." -ForegroundColor Yellow
gcloud services enable file.googleapis.com
gcloud services enable compute.googleapis.com

# Verificar si Filestore ya existe
Write-Host "🔍 Verificando si Filestore ya existe..." -ForegroundColor Yellow
try {
    $FILESTORE_IP = gcloud filestore instances describe $FILESTORE_NAME --zone=$ZONE --format="value(fileShares[0].ipAddresses[0])" 2>$null
    if ($FILESTORE_IP) {
        Write-Host "✅ Filestore ya existe, IP: $FILESTORE_IP" -ForegroundColor Green
    } else {
        throw "No se pudo obtener IP"
    }
} catch {
    # Crear Filestore instance con nombre de volumen válido
    Write-Host "🗄️ Creando instancia de Filestore..." -ForegroundColor Yellow
    gcloud filestore instances create $FILESTORE_NAME `
        --zone=$ZONE `
        --tier=$FILESTORE_TIER `
        --file-share=name="moodleshare",capacity=${FILESTORE_SIZE_GB}GB `
        --network=name=$FILESTORE_NETWORK `
        --description="Filestore para Moodle escalable"

    # Obtener IP del Filestore
    Write-Host "⏳ Esperando que Filestore esté listo..." -ForegroundColor Yellow
    Start-Sleep -Seconds 60
    $FILESTORE_IP = gcloud filestore instances describe $FILESTORE_NAME --zone=$ZONE --format="value(fileShares[0].ipAddresses[0])"
    Write-Host "✅ Filestore creado con IP: $FILESTORE_IP" -ForegroundColor Green
}

# Verificar que tenemos la IP
if (-not $FILESTORE_IP) {
    Write-Host "❌ Error: No se pudo obtener la IP del Filestore" -ForegroundColor Red
    exit 1
}

# Crear StorageClass para Filestore
Write-Host "📦 Creando StorageClass para Filestore..." -ForegroundColor Yellow
@"
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: filestore-rwx
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
"@ | kubectl apply -f -

# Crear PersistentVolume para Filestore
Write-Host "💾 Creando PersistentVolume..." -ForegroundColor Yellow
@"
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
    path: /moodleshare
"@ | kubectl apply -f -

# Crear PVC para Filestore
Write-Host "🔗 Creando PersistentVolumeClaim..." -ForegroundColor Yellow
@"
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
"@ | kubectl apply -f -

# Limpiar deployment anterior
Write-Host "🧹 Limpiando deployment anterior..." -ForegroundColor Yellow
kubectl delete deployment moodle-scalable -n moodle --ignore-not-found=true
kubectl delete service moodle-scalable -n moodle --ignore-not-found=true
kubectl delete deployment moodle-scaled -n moodle --ignore-not-found=true
kubectl delete service moodle-scaled -n moodle --ignore-not-found=true
kubectl delete pvc moodle-data-pvc-rwm -n moodle --ignore-not-found=true

# Verificar que el PVC esté vinculado
Write-Host "⏳ Verificando PVC..." -ForegroundColor Yellow
Start-Sleep -Seconds 10
$PVC_STATUS = kubectl get pvc moodle-filestore-pvc -n moodle -o jsonpath='{.status.phase}' 2>$null
if ($PVC_STATUS -ne "Bound") {
    Write-Host "❌ Error: PVC no está vinculado. Estado: $PVC_STATUS" -ForegroundColor Red
    kubectl describe pvc moodle-filestore-pvc -n moodle
    exit 1
}
Write-Host "✅ PVC vinculado correctamente" -ForegroundColor Green

# Crear deployment escalable con Filestore
Write-Host "🚀 Creando deployment escalable con Filestore..." -ForegroundColor Yellow
@"
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
"@ | kubectl apply -f -

Write-Host "⏳ Esperando 60 segundos para que se inicien los pods..." -ForegroundColor Yellow
Start-Sleep -Seconds 60

# Monitorear el despliegue
Write-Host "📊 Monitoreando despliegue..." -ForegroundColor Yellow
$attempt = 1
$max_attempts = 20

while ($attempt -le $max_attempts) {
    Write-Host ""
    Write-Host "🔄 Intento $attempt de $max_attempts" -ForegroundColor Cyan
    Write-Host "==================================" -ForegroundColor Cyan
    
    # Verificar estado de los pods
    kubectl get pods -n moodle -l app=moodle-scalable
    
    # Verificar si todos los pods están listos
    $ready_pods = (kubectl get pods -n moodle -l app=moodle-scalable --no-headers 2>$null | Select-String "Running").Count
    $total_pods = (kubectl get pods -n moodle -l app=moodle-scalable --no-headers 2>$null).Count
    
    if ($ready_pods -eq $total_pods -and $total_pods -gt 0) {
        Write-Host ""
        Write-Host "✅ ¡Todos los pods están ejecutándose!" -ForegroundColor Green
        
        # Obtener IP externa
        $external_ip = kubectl get svc moodle-scalable -n moodle -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>$null
        if ($external_ip) {
            Write-Host ""
            Write-Host "🎉 ¡MOODLE ESCALABLE ESTÁ LISTO!" -ForegroundColor Green
            Write-Host "=================================" -ForegroundColor Green
            Write-Host "🌐 URL de acceso: http://$external_ip" -ForegroundColor White
            Write-Host "👤 Usuario: admin" -ForegroundColor White
            Write-Host "🔑 Contraseña: moodle12345" -ForegroundColor White
            Write-Host ""
            Write-Host "📊 Información del escalado:" -ForegroundColor Yellow
            Write-Host "   - Pods ejecutándose: $ready_pods" -ForegroundColor White
            Write-Host "   - Filestore IP: $FILESTORE_IP" -ForegroundColor White
            Write-Host "   - Storage: ${FILESTORE_SIZE_GB}GB compartido" -ForegroundColor White
            Write-Host ""
            Write-Host "🔧 Comandos útiles:" -ForegroundColor Yellow
            Write-Host "   kubectl get pods -n moodle" -ForegroundColor White
            Write-Host "   kubectl scale deployment moodle-scalable --replicas=5 -n moodle" -ForegroundColor White
            Write-Host "   kubectl get svc -n moodle" -ForegroundColor White
            break
        } else {
            Write-Host "⏳ Esperando asignación de IP externa..." -ForegroundColor Yellow
        }
    } else {
        Write-Host "⏳ Esperando que los pods estén listos... ($ready_pods/$total_pods)" -ForegroundColor Yellow
        
        # Mostrar logs si hay problemas
        if ($attempt -gt 5) {
            Write-Host "🔍 Mostrando logs de pods con problemas..." -ForegroundColor Yellow
            kubectl logs -l app=moodle-scalable -n moodle --tail=10
        }
        
        Start-Sleep -Seconds 30
    }
    
    $attempt++
}

if ($attempt -gt $max_attempts) {
    Write-Host ""
    Write-Host "❌ Tiempo de espera agotado. Verificando estado final..." -ForegroundColor Red
    kubectl get pods -n moodle
    kubectl get svc -n moodle
    Write-Host ""
    Write-Host "🔍 Para diagnosticar problemas:" -ForegroundColor Yellow
    Write-Host "   kubectl describe pods -l app=moodle-scalable -n moodle" -ForegroundColor White
    Write-Host "   kubectl logs -l app=moodle-scalable -n moodle" -ForegroundColor White
}

Write-Host ""
Write-Host "🏁 Configuración completada." -ForegroundColor Green
Write-Host "📋 Recursos creados:" -ForegroundColor Yellow
Write-Host "   - Filestore: $FILESTORE_NAME" -ForegroundColor White
Write-Host "   - StorageClass: filestore-rwx" -ForegroundColor White
Write-Host "   - PersistentVolume: moodle-filestore-pv" -ForegroundColor White
Write-Host "   - Deployment: moodle-scalable (3 réplicas)" -ForegroundColor White
Write-Host "   - Service: moodle-scalable (LoadBalancer)" -ForegroundColor White 