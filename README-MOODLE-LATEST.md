# Moodle Latest - Despliegue en GKE

Este despliegue utiliza la imagen oficial `moodle:latest` de Docker Hub para instalar Moodle en Google Kubernetes Engine (GKE).

## Archivos Incluidos

- `deployment.yaml` - Deployment de Moodle con imagen latest
- `moodle-config.yaml` - ConfigMap con variables de entorno
- `service.yaml` - Service para exponer Moodle
- `ingress.yaml` - Ingress para acceso externo con SSL
- `pvc.yaml` - PersistentVolumeClaims para almacenamiento
- `deploy-moodle-latest.sh` - Script de despliegue
- `cleanup-moodle-latest.sh` - Script de limpieza

## Configuración

### Base de Datos
- **Host**: 10.169.65.226 (Base de datos externa)
- **Puerto**: 3306
- **Usuario**: root
- **Base de datos**: moodle

### Dominio
- **URL**: https://campusvirtual.telesalud.gob.sv

### Credenciales de Administrador
- **Usuario**: admin
- **Contraseña**: Admin123!
- **Email**: admin@telesalud.gob.sv

## Despliegue

### Prerrequisitos
1. Certificados SSL (cert.pem y key.pem) para el dominio
2. Acceso al cluster GKE
3. Permisos para crear IPs estáticas

### Pasos de Despliegue

1. **Crear el secreto SSL** (si no existe):
```bash
kubectl create secret tls cloudflare-cert --cert=cert.pem --key=key.pem -n moodle
```

2. **Ejecutar el script de despliegue**:
```bash
./deploy-moodle-latest.sh
```

3. **Verificar el estado**:
```bash
kubectl get pods -n moodle
kubectl get svc -n moodle
kubectl get ingress -n moodle
```

## Comandos Útiles

### Verificar Estado
```bash
# Estado de pods
kubectl get pods -n moodle

# Estado de servicios
kubectl get svc -n moodle

# Estado de ingress
kubectl get ingress -n moodle

# Detalles del ingress
kubectl describe ingress moodle-service -n moodle
```

### Verificar IP Estática
```bash
gcloud compute addresses list
```

### Ver Logs
```bash
# Logs del deployment
kubectl logs -n moodle deployment/moodle --tail=50

# Logs de un pod específico
kubectl logs -n moodle <pod-name> --tail=50
```

### Limpiar Todo
```bash
./cleanup-moodle-latest.sh
```

## Diferencias con Bitnami

Este despliegue usa la imagen oficial `moodle:latest` en lugar de Bitnami:

### Ventajas
- Imagen más ligera
- Actualizaciones más frecuentes
- Menos dependencias

### Configuración
- **Puerto**: 8080 (HTTP) y 8443 (HTTPS)
- **Volúmenes**: 
  - `/var/www/html` - Archivos de Moodle
  - `/var/moodledata` - Datos de Moodle
  - `/tmp` - Archivos temporales
  - `/var/cache` - Cache

## Solución de Problemas

### Pod en CrashLoopBackOff
1. Verificar logs: `kubectl logs -n moodle deployment/moodle --tail=100`
2. Verificar conectividad a la base de datos
3. Verificar permisos de los volúmenes

### Problemas de SSL
1. Verificar que el secreto `cloudflare-cert` existe
2. Verificar que los certificados son válidos
3. Verificar configuración del ingress

### Problemas de Base de Datos
1. Verificar conectividad: `kubectl run test-mysql --rm -i --tty --image=mysql:8.0 -- mysql -h 10.169.65.226 -P 3306 -u root -p'7s4bLvmszaV2CKjFd$ZV' -e "SELECT 1;"`
2. Verificar que la base de datos `moodle` existe
3. Verificar permisos del usuario root

## Notas Importantes

- La imagen `moodle:latest` requiere configuración manual de PHP y Apache
- Los volúmenes persistentes mantienen los datos entre reinicios
- El ingress redirige automáticamente HTTP a HTTPS
- La IP estática global permite DNS consistente 