# Despliegue de Moodle en Kubernetes

Este repositorio contiene los manifiestos de Kubernetes para desplegar Moodle con cluster MariaDB Galera.

## Arquitectura
- **Moodle**: Despliegue de un solo pod con almacenamiento ReadWriteOnce
- **Base de datos**: Cluster MariaDB Galera (3 pods) para alta disponibilidad
- **Almacenamiento**: Volúmenes persistentes estándar para persistencia de datos
- **Sesiones**: Almacenamiento de sesiones basado en base de datos para escalabilidad

## Prerequisitos
- Cluster de Kubernetes con soporte para controlador CSI
- kubectl configurado
- StorageClass `standard-rwo` disponible

## Despliegue Rápido
```bash
# Hacer el script ejecutable
chmod +x deploy.sh

# Desplegar todo
./deploy.sh
```

## Pasos de Despliegue Manual
1. Crear namespace:
   ```bash
   kubectl create namespace moodle
   ```

2. Desplegar cluster MariaDB:
   ```bash
   kubectl apply -f mariadb-deployment.yaml
   ```

3. Esperar a que MariaDB esté listo:
   ```bash
   kubectl wait --for=condition=ready pod -l app=mariadb -n moodle --timeout=300s
   ```

4. Crear almacenamiento:
   ```bash
   kubectl apply -f moodle-pvcs.yaml
   ```

5. Aplicar configuración:
   ```bash
   kubectl apply -f moodle-config.yaml
   ```

6. Desplegar Moodle:
   ```bash
   kubectl apply -f deployment.yaml
   ```

7. Crear servicio:
   ```bash
   kubectl apply -f service.yaml
   ```

8. (Opcional) Aplicar ingress:
   ```bash
   kubectl apply -f ingress.yaml
   ```

## Configuración
### Conexión a Base de Datos
- Host: `mariadb-read.moodle.svc.cluster.local`
- Base de datos: `moodle`
- Usuario: `moodle`
- Contraseña: `Admin123!` (cambiar en producción)

### Administrador de Moodle
- Usuario: `admin`
- Contraseña: `Admin123!` (cambiar en producción)
- Email: `admin@telesalud.gob.sv`

## Cambios Específicos por Entorno
Antes de desplegar en un nuevo entorno, consultar `CONFIGURACION-ENTORNO.md` para la lista completa de cambios necesarios.

Cambios principales:

1. **moodle-config.yaml**:
   - `MOODLE_EMAIL`
   - `MOODLE_SITE_NAME`
   - Contraseñas (usar secrets en producción)

2. **ingress.yaml** (si se usa):
   - Nombres de dominio
   - Certificados SSL
   - Direcciones IP

3. **Almacenamiento**:
   - Nombres de clases de almacenamiento
   - Tamaños de volúmenes

## Monitoreo
Verificar estado del despliegue:
```bash
kubectl get pods -n moodle
kubectl get pvc -n moodle
kubectl get svc -n moodle
```

## Escalado
Para escalar Moodle (requiere almacenamiento ReadWriteMany):
```bash
kubectl scale deployment moodle --replicas=3 -n moodle
```

## Respaldo
Los respaldos de la base de datos deben configurarse para el cluster MariaDB.
Los snapshots de PVC pueden usarse para respaldo de datos de aplicación.

## Solución de Problemas
- Revisar logs del pod: `kubectl logs -n moodle <pod-name>`
- Revisar eventos: `kubectl get events -n moodle`
- Port forward para pruebas: `kubectl port-forward -n moodle svc/moodle-service 8080:80`
