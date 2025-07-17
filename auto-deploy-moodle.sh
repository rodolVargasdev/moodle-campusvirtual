#!/bin/bash

echo "🚀 === DESPLIEGUE AUTOMÁTICO DE MOODLE PERSONALIZADO ==="
echo "📅 Fecha: $(date)"
echo ""

# Configuración
PROJECT_ID=$(gcloud config get-value project)
REGION=$(gcloud config get-value compute/region)
CLUSTER_NAME=$(gcloud container clusters list --format="value(name)" --limit=1)
IMAGE_NAME="gcr.io/$PROJECT_ID/moodle-custom"
TAG="latest"

echo "🔧 Configuración:"
echo "   Proyecto: $PROJECT_ID"
echo "   Región: $REGION"
echo "   Cluster: $CLUSTER_NAME"
echo "   Imagen: $IMAGE_NAME:$TAG"
echo ""

# Verificar que estamos conectados al cluster
echo "🔍 Verificando conexión al cluster..."
if ! kubectl cluster-info &> /dev/null; then
    echo "❌ Error: No se puede conectar al cluster"
    echo "   Ejecuta: gcloud container clusters get-credentials $CLUSTER_NAME --region=$REGION"
    exit 1
fi
echo "✅ Conexión al cluster exitosa"
echo ""

# Verificar que estamos en el directorio correcto
if [ ! -f "Dockerfile" ]; then
    echo "❌ Error: No se encontró el Dockerfile en el directorio actual"
    echo "   Asegúrate de estar en el directorio correcto"
    exit 1
fi
echo "✅ Dockerfile encontrado"
echo ""

# Crear namespace si no existe
echo "📁 Creando namespace moodle..."
kubectl create namespace moodle --dry-run=client -o yaml | kubectl apply -f -
echo "✅ Namespace moodle listo"
echo ""

# Verificar si existe el secreto SSL
echo "🔐 Verificando certificados SSL..."
if ! kubectl get secret cloudflare-cert -n moodle &> /dev/null; then
    echo "⚠️  No se encontró el secreto SSL"
    echo "   Generando certificados SSL temporales..."
    
    # Ejecutar script de generación de certificados
    if [ -f "generate-ssl-certs.sh" ]; then
        chmod +x generate-ssl-certs.sh
        ./generate-ssl-certs.sh
    else
        echo "❌ Error: No se encontró el script generate-ssl-certs.sh"
        echo "   Generando certificados manualmente..."
        
        # Generar certificados manualmente
        mkdir -p ssl-certs
        cd ssl-certs
        
        openssl genrsa -out key.pem 2048
        openssl req -new -x509 -key key.pem -out cert.pem -days 365 -subj "/C=SV/ST=San Salvador/L=San Salvador/O=Telesalud/OU=IT/CN=campusvirtual.telesalud.gob.sv"
        
        kubectl create secret tls cloudflare-cert --cert=cert.pem --key=key.pem -n moodle
        
        cd ..
        echo "✅ Certificados SSL generados y secreto creado"
    fi
else
    echo "✅ Secreto SSL ya existe"
fi
echo ""

# Crear IP estática global
echo "🌐 Creando IP estática global..."
gcloud compute addresses create moodle-ip --global --quiet || echo "ℹ️  IP estática ya existe"
echo "✅ IP estática configurada"
echo ""

# Habilitar APIs necesarias
echo "🔧 Habilitando APIs necesarias..."
gcloud services enable cloudbuild.googleapis.com --quiet
gcloud services enable containerregistry.googleapis.com --quiet
echo "✅ APIs habilitadas"
echo ""

# Construir la imagen con Cloud Build
echo "🏗️ Construyendo imagen con Cloud Build..."
echo "   Esto puede tomar varios minutos..."
gcloud builds submit --tag $IMAGE_NAME:$TAG . --quiet

if [ $? -ne 0 ]; then
    echo "❌ Error: Falló la construcción con Cloud Build"
    echo "   Verificando logs..."
    gcloud builds list --limit=1 --format="value(id)" | xargs -I {} gcloud builds log {}
    exit 1
fi
echo "✅ Imagen construida exitosamente: $IMAGE_NAME:$TAG"
echo ""

# Aplicar ConfigMap
echo "📋 Aplicando ConfigMap..."
kubectl apply -f moodle-config.yaml
echo "✅ ConfigMap aplicado"
echo ""

# Aplicar PVCs
echo "💾 Aplicando PersistentVolumeClaims..."
kubectl apply -f pvc.yaml
echo "✅ PVCs aplicados"
echo ""

# Esperar a que los PVCs estén listos
echo "⏳ Esperando a que los PVCs estén listos..."
kubectl wait --for=condition=Bound pvc/moodle-data-pvc -n moodle --timeout=300s
kubectl wait --for=condition=Bound pvc/moodle-moodledata-pvc -n moodle --timeout=300s
echo "✅ PVCs listos"
echo ""

# Crear deployment con la imagen personalizada
echo "🚀 Creando deployment con imagen personalizada..."
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
echo "✅ Deployment creado"
echo ""

# Crear service
echo "🔗 Aplicando service..."
kubectl apply -f service.yaml
echo "✅ Service aplicado"
echo ""

# Crear ingress
echo "🌐 Aplicando ingress..."
kubectl apply -f ingress.yaml
echo "✅ Ingress aplicado"
echo ""

# Limpiar archivo temporal
rm deployment-custom-final.yaml

# Mostrar estado inicial
echo "📊 Estado inicial de los recursos:"
kubectl get pods,pvc,svc -n moodle
echo ""

# Esperar a que el pod esté listo
echo "⏳ Esperando a que el pod esté listo..."
kubectl wait --for=condition=Ready pod -l app=moodle-complete -n moodle --timeout=600s

if [ $? -eq 0 ]; then
    echo "✅ Pod listo y funcionando"
else
    echo "⚠️  El pod no está listo aún, pero el despliegue continúa"
fi
echo ""

# Mostrar información final
echo "🎉 === DESPLIEGUE COMPLETADO ==="
echo ""
echo "📋 Información del despliegue:"
echo "   Imagen construida: $IMAGE_NAME:$TAG"
echo "   Namespace: moodle"
echo "   Dominio: campusvirtual.telesalud.gob.sv"
echo ""
echo "🔍 Comandos útiles para verificar:"
echo "   kubectl get pods -n moodle"
echo "   kubectl get svc -n moodle"
echo "   kubectl get ingress -n moodle"
echo "   kubectl logs -n moodle deployment/moodle --tail=50"
echo ""
echo "🌐 Para verificar la IP estática:"
echo "   gcloud compute addresses list"
echo ""
echo "📝 Para ver logs en tiempo real:"
echo "   kubectl logs -n moodle deployment/moodle -f"
echo ""
echo "🔧 Para acceder al pod:"
echo "   kubectl exec -it -n moodle deployment/moodle -- bash"
echo ""
echo "✅ ¡Moodle está siendo desplegado con PHP y Apache personalizados!" 