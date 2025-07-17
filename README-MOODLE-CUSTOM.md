# Moodle Personalizado - PHP y Apache Configurados

Este despliegue crea una imagen personalizada de Moodle con PHP y Apache completamente configurados para funcionar en Google Kubernetes Engine (GKE).

## 🏗️ Arquitectura

### Imagen Personalizada
- **Base**: `moodle:latest` (imagen oficial)
- **PHP**: Configurado con todas las extensiones necesarias para Moodle
- **Apache**: Configurado con módulos de seguridad, cache y compresión
- **Extensiones PHP**: gd, mbstring, xml, soap, zip, curl, tidy, xsl, intl, opcache, imagick

### Configuración PHP
- **Memory Limit**: 2GB
- **Max Execution Time**: 1800 segundos
- **Max Input Vars**: 5000
- **Upload Max Filesize**: 100MB
- **Post Max Size**: 100MB

### Configuración Apache
- **Módulos**: rewrite, ssl, headers, expires, deflate
- **Seguridad**: Headers de seguridad configurados
- **Cache**: Configuración optimizada para archivos estáticos
- **Compresión**: Gzip habilitado

## 📁 Archivos Incluidos

### Archivos de Construcción
- `Dockerfile` - Imagen personalizada con PHP y Apache
- `apache-moodle.conf` - Configuración de Apache para Moodle
- `docker-entrypoint.sh` - Script de inicio personalizado

### Scripts de Despliegue
- `deploy-custom-moodle.sh` - Despliegue completo (recomendado)
- `build-with-cloudbuild.sh` - Solo construcción con Cloud Build
- `build-and-deploy.sh` - Construcción local y despliegue

### Archivos YAML
- `deployment.yaml` - Deployment básico (sin imagen personalizada)
- `moodle-config.yaml` - ConfigMap con variables de entorno
- `service.yaml` - Service NodePort
- `ingress.yaml` - Ingress con SSL
- `pvc.yaml` - PersistentVolumeClaims

## 🚀 Despliegue

### Opción 1: Despliegue Completo (Recomendado)
```bash
# Ejecutar el script completo
./deploy-custom-moodle.sh
```

Este script:
1. Construye la imagen con Cloud Build
2. Crea el namespace y recursos necesarios
3. Despliega Moodle con la imagen personalizada
4. Configura service e ingress

### Opción 2: Construcción y Despliegue Separados
```bash
# 1. Construir imagen
./build-with-cloudbuild.sh

# 2. Desplegar recursos
kubectl apply -f moodle-config.yaml
kubectl apply -f pvc.yaml
kubectl apply -f service.yaml
kubectl apply -f ingress.yaml

# 3. Actualizar deployment con nueva imagen
kubectl set image deployment/moodle moodle=gcr.io/PROJECT_ID/moodle-custom:latest -n moodle
```

## 🔧 Configuración

### Variables de Entorno (ConfigMap)
```yaml
MOODLE_DATABASE_HOST: 10.169.65.226
MOODLE_DATABASE_NAME: moodle
MOODLE_DATABASE_USER: root
MOODLE_DATABASE_PASSWORD: 7s4bLvmszaV2CKjFd$ZV
MOODLE_DATABASE_PORT_NUMBER: 3306
MOODLE_USERNAME: admin
MOODLE_PASSWORD: Admin123!
MOODLE_EMAIL: admin@telesalud.gob.sv
MOODLE_SITE_NAME: Moodle Telesalud
```

### Volúmenes
- `/var/www/html` - Archivos de Moodle (PVC: moodle-data-pvc)
- `/var/moodledata` - Datos de Moodle (PVC: moodle-moodledata-pvc)
- `/tmp` - Archivos temporales (EmptyDir)
- `/var/cache` - Cache (EmptyDir)

## 📊 Monitoreo

### Verificar Estado
```bash
# Estado de pods
kubectl get pods -n moodle

# Logs del deployment
kubectl logs -n moodle deployment/moodle --tail=50

# Estado de servicios
kubectl get svc -n moodle

# Estado de ingress
kubectl get ingress -n moodle
```

### Verificar Imagen
```bash
# Listar imágenes construidas
gcloud container images list-tags gcr.io/PROJECT_ID/moodle-custom

# Ver detalles de la imagen
gcloud container images describe gcr.io/PROJECT_ID/moodle-custom:latest
```

## 🔍 Solución de Problemas

### Pod en CrashLoopBackOff
1. **Verificar logs**:
   ```bash
   kubectl logs -n moodle deployment/moodle --tail=100
   ```

2. **Verificar construcción de imagen**:
   ```bash
   gcloud builds list --limit=5
   ```

3. **Verificar extensiones PHP**:
   ```bash
   kubectl exec -n moodle deployment/moodle -- php -m
   ```

### Problemas de Base de Datos
1. **Verificar conectividad**:
   ```bash
   kubectl run test-mysql --rm -i --tty --image=mysql:8.0 -- \
     mysql -h 10.169.65.226 -P 3306 -u root -p'7s4bLvmszaV2CKjFd$ZV' -e "SELECT 1;"
   ```

2. **Verificar permisos**:
   ```bash
   kubectl exec -n moodle deployment/moodle -- \
     mysql -h 10.169.65.226 -P 3306 -u root -p'7s4bLvmszaV2CKjFd$ZV' -e "SHOW GRANTS;"
   ```

### Problemas de Construcción
1. **Verificar Dockerfile**:
   ```bash
   docker build -t test-moodle .
   ```

2. **Verificar Cloud Build**:
   ```bash
   gcloud builds log BUILD_ID
   ```

## 🛠️ Personalización

### Modificar Configuración PHP
Editar el `Dockerfile` y cambiar las líneas de configuración PHP:
```dockerfile
RUN echo "memory_limit = 4G" >> /usr/local/etc/php/conf.d/moodle.ini
```

### Modificar Configuración Apache
Editar `apache-moodle.conf` para cambiar la configuración de Apache.

### Agregar Extensiones PHP
Agregar extensiones en el `Dockerfile`:
```dockerfile
RUN docker-php-ext-install -j$(nproc) nueva_extension
```

## 🧹 Limpieza

### Eliminar Todo
```bash
# Eliminar recursos de Kubernetes
kubectl delete -f . --ignore-not-found=true

# Eliminar namespace
kubectl delete namespace moodle --ignore-not-found=true

# Eliminar imagen
gcloud container images delete gcr.io/PROJECT_ID/moodle-custom:latest --quiet

# Eliminar IP estática
gcloud compute addresses delete moodle-ip --global --quiet
```

## 📝 Notas Importantes

- La imagen personalizada tarda más en construirse pero incluye todas las dependencias
- Cloud Build es más eficiente que construcción local
- Los volúmenes persistentes mantienen los datos entre reinicios
- La configuración incluye headers de seguridad y optimizaciones de rendimiento
- El script de entrada verifica extensiones PHP y conectividad de base de datos 