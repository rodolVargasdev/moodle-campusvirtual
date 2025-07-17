#!/bin/bash

echo "🚀 === SOLUCIÓN RÁPIDA Y DESPLIEGUE ==="
echo "📅 Fecha: $(date)"
echo ""

# 1. Forzar actualización del repositorio
echo "🔄 Actualizando repositorio..."
git reset --hard HEAD
git pull origin moodle-custom-php-apache
echo "✅ Repositorio actualizado"
echo ""

# 2. Verificar y corregir Dockerfile
echo "🔧 Verificando Dockerfile..."
FIRST_LINE=$(head -1 Dockerfile)
echo "📋 Primera línea actual: $FIRST_LINE"

if [[ "$FIRST_LINE" == *"moodle:latest"* ]]; then
    echo "⚠️  Corrigiendo Dockerfile..."
    sed -i '1s|FROM moodle:latest|FROM bitnami/moodle:latest|' Dockerfile
    echo "✅ Dockerfile corregido"
    echo "📋 Nueva primera línea: $(head -1 Dockerfile)"
else
    echo "✅ Dockerfile ya está correcto"
fi
echo ""

# 3. Verificar certificados SSL
echo "🔐 Verificando certificados SSL..."
if ! kubectl get secret cloudflare-cert -n moodle &> /dev/null; then
    echo "⚠️  Generando certificados SSL..."
    
    # Crear directorio para certificados
    mkdir -p ssl-certs
    cd ssl-certs
    
    # Generar certificados
    openssl genrsa -out key.pem 2048
    openssl req -new -x509 -key key.pem -out cert.pem -days 365 -subj "/C=SV/ST=San Salvador/L=San Salvador/O=Telesalud/OU=IT/CN=campusvirtual.telesalud.gob.sv"
    
    # Crear secreto
    kubectl create secret tls cloudflare-cert --cert=cert.pem --key=key.pem -n moodle
    
    cd ..
    echo "✅ Certificados SSL generados"
else
    echo "✅ Certificados SSL ya existen"
fi
echo ""

# 4. Configuración
PROJECT_ID=$(gcloud config get-value project)
IMAGE_NAME="gcr.io/$PROJECT_ID/moodle-custom"
TAG="latest"

echo "🔧 Configuración:"
echo "   Proyecto: $PROJECT_ID"
echo "   Imagen: $IMAGE_NAME:$TAG"
echo ""

# 5. Construir imagen
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

# 6. Aplicar recursos
echo "📋 Aplicando recursos..."
kubectl apply -f moodle-config.yaml
kubectl apply -f pvc.yaml
echo "✅ Recursos aplicados"
echo ""

# 7. Esperar PVCs
echo "⏳ Esperando PVCs..."
kubectl wait --for=condition=Bound pvc/moodle-data-pvc -n moodle --timeout=300s
kubectl wait --for=condition=Bound pvc/moodle-moodledata-pvc -n moodle --timeout=300s
echo "✅ PVCs listos"
echo ""

# 8. Crear deployment
echo "🚀 Creando deployment..."
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

# 9. Aplicar service e ingress
echo "🔗 Aplicando service e ingress..."
kubectl apply -f service.yaml
kubectl apply -f ingress.yaml
echo "✅ Service e ingress aplicados"
echo ""

# 10. Limpiar y mostrar estado
rm deployment-custom-final.yaml

echo "📊 Estado de los recursos:"
kubectl get pods,pvc,svc -n moodle
echo ""

echo "🎉 === DESPLIEGUE COMPLETADO ==="
echo ""
echo "📋 Información:"
echo "   Imagen: $IMAGE_NAME:$TAG"
echo "   Dominio: campusvirtual.telesalud.gob.sv"
echo ""
echo "🔍 Comandos útiles:"
echo "   kubectl get pods -n moodle"
echo "   kubectl logs -n moodle deployment/moodle --tail=50"
echo "   kubectl get ingress -n moodle"
echo ""
echo "✅ ¡Moodle está siendo desplegado!" 