#!/bin/bash

echo "=== Despliegue completo de Moodle personalizado ==="

# Configuración
PROJECT_ID=$(gcloud config get-value project)
IMAGE_NAME="gcr.io/$PROJECT_ID/moodle-custom"
TAG="latest"

echo "Proyecto: $PROJECT_ID"
echo "Imagen: $IMAGE_NAME:$TAG"

# Verificar que estamos en el directorio correcto
if [ ! -f "Dockerfile" ]; then
    echo "Error: No se encontró el Dockerfile en el directorio actual"
    exit 1
fi

# Crear namespace si no existe
echo "Creando namespace moodle..."
kubectl create namespace moodle --dry-run=client -o yaml | kubectl apply -f -

# Crear IP estática global
echo "Creando IP estática global..."
gcloud compute addresses create moodle-ip --global --quiet || echo "IP estática ya existe"

# Habilitar Cloud Build API
echo "Verificando Cloud Build API..."
gcloud services enable cloudbuild.googleapis.com

# Construir la imagen con Cloud Build
echo "Construyendo imagen con Cloud Build..."
gcloud builds submit --tag $IMAGE_NAME:$TAG .

if [ $? -ne 0 ]; then
    echo "Error: Falló la construcción con Cloud Build"
    exit 1
fi

# Crear ConfigMap si no existe
echo "Aplicando ConfigMap..."
kubectl apply -f moodle-config.yaml

# Crear PVCs si no existen
echo "Aplicando PVCs..."
kubectl apply -f pvc.yaml

# Esperar a que los PVCs estén listos
echo "Esperando a que los PVCs estén listos..."
kubectl wait --for=condition=Bound pvc/moodle-data-pvc -n moodle --timeout=300s
kubectl wait --for=condition=Bound pvc/moodle-moodledata-pvc -n moodle --timeout=300s

# Crear deployment con la imagen personalizada
echo "Creando deployment con imagen personalizada..."
cat > deployment-custom-final.yaml << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: moodle
  namespace: moodle
spec:
  progressDeadlineSeconds: 600
  replicas: 1
  selector:
    matchLabels:
      app: moodle-complete
  strategy:
    type: Recreate
  template:
    metadata:
      labels:
        app: moodle-complete
    spec:
      containers:
      - envFrom:
        - configMapRef:
            name: moodle-config
        image: $IMAGE_NAME:$TAG
        imagePullPolicy: Always
        livenessProbe:
          failureThreshold: 3
          httpGet:
            path: /login/index.php
            port: 8080
            scheme: HTTP
          initialDelaySeconds: 120
          periodSeconds: 30
          successThreshold: 1
          timeoutSeconds: 10
        name: moodle
        ports:
        - containerPort: 8080
          name: http
          protocol: TCP
        - containerPort: 8443
          name: https
          protocol: TCP
        readinessProbe:
          failureThreshold: 3
          httpGet:
            path: /login/index.php
            port: 8080
            scheme: HTTP
          initialDelaySeconds: 60
          periodSeconds: 10
          successThreshold: 1
          timeoutSeconds: 5
        resources:
          limits:
            cpu: "3"
            ephemeral-storage: 2Gi
            memory: 6Gi
          requests:
            cpu: 1500m
            ephemeral-storage: 2Gi
            memory: 3Gi
        terminationMessagePath: /dev/termination-log
        terminationMessagePolicy: File
        volumeMounts:
        - mountPath: /var/www/html
          name: moodle-data
        - mountPath: /var/moodledata
          name: moodle-moodledata
        - mountPath: /tmp
          name: moodle-tmp
        - mountPath: /var/cache
          name: moodle-cache
      dnsPolicy: ClusterFirst
      restartPolicy: Always
      schedulerName: default-scheduler
      securityContext:
        seccompProfile:
          type: RuntimeDefault
      terminationGracePeriodSeconds: 30
      tolerations:
      - effect: NoSchedule
        key: kubernetes.io/arch
        operator: Equal
        value: amd64
      volumes:
      - name: moodle-data
        persistentVolumeClaim:
          claimName: moodle-data-pvc
      - name: moodle-moodledata
        persistentVolumeClaim:
          claimName: moodle-moodledata-pvc
      - emptyDir:
          medium: Memory
          sizeLimit: 1Gi
        name: moodle-tmp
      - emptyDir:
          medium: Memory
          sizeLimit: 512Mi
        name: moodle-cache
EOF

kubectl apply -f deployment-custom-final.yaml

# Crear service
echo "Aplicando service..."
kubectl apply -f service.yaml

# Crear ingress
echo "Aplicando ingress..."
kubectl apply -f ingress.yaml

# Limpiar archivo temporal
rm deployment-custom-final.yaml

# Mostrar estado inicial
echo "Estado inicial de los recursos:"
kubectl get pods,pvc,svc -n moodle

echo ""
echo "=== Despliegue completado ==="
echo "Imagen construida: $IMAGE_NAME:$TAG"
echo ""
echo "Para verificar el estado:"
echo "  kubectl get pods -n moodle"
echo "  kubectl get svc -n moodle"
echo "  kubectl get ingress -n moodle"
echo ""
echo "Para ver logs:"
echo "  kubectl logs -n moodle deployment/moodle --tail=50"
echo ""
echo "Para verificar la IP estática:"
echo "  gcloud compute addresses list" 