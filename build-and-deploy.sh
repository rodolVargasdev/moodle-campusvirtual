#!/bin/bash

echo "=== Construyendo y desplegando Moodle personalizado ==="

# Configuración
PROJECT_ID=$(gcloud config get-value project)
REGION=$(gcloud config get-value compute/region)
CLUSTER_NAME=$(gcloud container clusters list --format="value(name)" --limit=1)
IMAGE_NAME="gcr.io/$PROJECT_ID/moodle-custom"
TAG="latest"

echo "Proyecto: $PROJECT_ID"
echo "Región: $REGION"
echo "Cluster: $CLUSTER_NAME"
echo "Imagen: $IMAGE_NAME:$TAG"

# Verificar que estamos en el directorio correcto
if [ ! -f "Dockerfile" ]; then
    echo "Error: No se encontró el Dockerfile en el directorio actual"
    exit 1
fi

# Configurar Docker para usar gcloud como helper
echo "Configurando Docker para GCR..."
gcloud auth configure-docker

# Construir la imagen
echo "Construyendo imagen Docker..."
docker build -t $IMAGE_NAME:$TAG .

if [ $? -ne 0 ]; then
    echo "Error: Falló la construcción de la imagen"
    exit 1
fi

# Subir la imagen a Google Container Registry
echo "Subiendo imagen a Google Container Registry..."
docker push $IMAGE_NAME:$TAG

if [ $? -ne 0 ]; then
    echo "Error: Falló el push de la imagen"
    exit 1
fi

# Actualizar el deployment con la nueva imagen
echo "Actualizando deployment con la nueva imagen..."

# Crear un archivo temporal con la nueva imagen
cat > deployment-custom.yaml << EOF
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

# Aplicar el deployment actualizado
kubectl apply -f deployment-custom.yaml

# Limpiar archivo temporal
rm deployment-custom.yaml

echo ""
echo "=== Despliegue completado ==="
echo "Para verificar el estado:"
echo "  kubectl get pods -n moodle"
echo "  kubectl logs -n moodle deployment/moodle --tail=50"
echo ""
echo "Para ver la imagen construida:"
echo "  gcloud container images list-tags $IMAGE_NAME" 