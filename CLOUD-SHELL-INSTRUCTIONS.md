# 🚀 Instrucciones para Desplegar desde Cloud Shell

## 📋 Prerrequisitos

1. **Acceso a Cloud Shell** con permisos de administrador
2. **Cluster GKE** configurado y funcionando
3. **Certificados SSL** para el dominio (cert.pem y key.pem)

## 🔄 Pasos para Desplegar

### 1. Clonar el Repositorio
```bash
# Clonar el repositorio
git clone https://github.com/rodolVargasdev/moodle-campusvirtual.git
cd moodle-campusvirtual

# Cambiar a la rama con la configuración personalizada
git checkout moodle-custom-php-apache
```

### 2. Configurar Certificados SSL
```bash
# Crear el secreto SSL (reemplaza con tus certificados)
kubectl create secret tls cloudflare-cert --cert=cert.pem --key=key.pem -n moodle
```

### 3. Ejecutar Despliegue Automático
```bash
# Hacer el script ejecutable
chmod +x auto-deploy-moodle.sh

# Ejecutar el despliegue automático
./auto-deploy-moodle.sh
```

## 📊 Monitoreo del Despliegue

### Verificar Estado
```bash
# Estado de pods
kubectl get pods -n moodle

# Estado de servicios
kubectl get svc -n moodle

# Estado de ingress
kubectl get ingress -n moodle

# Logs del deployment
kubectl logs -n moodle deployment/moodle --tail=50
```

### Verificar IP Estática
```bash
# Ver IP asignada
gcloud compute addresses list

# Ver detalles del ingress
kubectl describe ingress moodle-service -n moodle
```

## 🔧 Comandos Útiles

### Acceder al Pod
```bash
# Acceder al contenedor
kubectl exec -it -n moodle deployment/moodle -- bash

# Verificar extensiones PHP
kubectl exec -n moodle deployment/moodle -- php -m

# Verificar configuración PHP
kubectl exec -n moodle deployment/moodle -- php -i | grep memory_limit
```

### Ver Logs en Tiempo Real
```bash
# Logs del deployment
kubectl logs -n moodle deployment/moodle -f

# Logs de un pod específico
kubectl logs -n moodle <pod-name> -f
```

### Verificar Base de Datos
```bash
# Probar conectividad
kubectl run test-mysql --rm -i --tty --image=mysql:8.0 -- \
  mysql -h 10.169.65.226 -P 3306 -u root -p'7s4bLvmszaV2CKjFd$ZV' -e "SELECT 1;"
```

## 🧹 Limpieza

### Limpieza Automática
```bash
# Ejecutar limpieza automática
chmod +x auto-cleanup-moodle.sh
./auto-cleanup-moodle.sh
```

### Limpieza Manual
```bash
# Eliminar recursos específicos
kubectl delete -f . --ignore-not-found=true
kubectl delete namespace moodle --ignore-not-found=true
gcloud container images delete gcr.io/PROJECT_ID/moodle-custom:latest --quiet
gcloud compute addresses delete moodle-ip --global --quiet
```

## 🔍 Solución de Problemas

### Pod en CrashLoopBackOff
```bash
# Ver logs detallados
kubectl logs -n moodle deployment/moodle --previous --tail=100

# Verificar eventos
kubectl describe pod -n moodle -l app=moodle-complete

# Reiniciar deployment
kubectl rollout restart deployment moodle -n moodle
```

### Problemas de Construcción
```bash
# Ver logs de Cloud Build
gcloud builds list --limit=5
gcloud builds log BUILD_ID

# Reconstruir imagen
./build-with-cloudbuild.sh
```

### Problemas de Conectividad
```bash
# Verificar conectividad a base de datos
kubectl run test-connection --rm -i --tty --image=busybox -- nc -zv 10.169.65.226 3306

# Verificar DNS
kubectl run test-dns --rm -i --tty --image=busybox -- nslookup campusvirtual.telesalud.gob.sv
```

## 📝 Notas Importantes

- **Tiempo de Construcción**: La imagen personalizada puede tardar 10-15 minutos en construirse
- **Recursos**: El deployment requiere al menos 3GB de RAM y 1.5 CPU
- **Almacenamiento**: Se crean 2 PVCs de 10GB y 20GB respectivamente
- **Dominio**: Asegúrate de que el DNS apunte a la IP estática asignada
- **Certificados**: Los certificados SSL deben ser válidos para el dominio

## 🆘 Soporte

Si encuentras problemas:

1. **Verificar logs**: `kubectl logs -n moodle deployment/moodle --tail=100`
2. **Verificar eventos**: `kubectl get events -n moodle --sort-by='.lastTimestamp'`
3. **Verificar recursos**: `kubectl get all -n moodle`
4. **Revisar configuración**: `kubectl describe deployment moodle -n moodle`

## 🔄 Actualizaciones

Para actualizar la imagen:

```bash
# Reconstruir y desplegar
./auto-deploy-moodle.sh

# O solo actualizar la imagen
kubectl set image deployment/moodle moodle=gcr.io/PROJECT_ID/moodle-custom:latest -n moodle
``` 