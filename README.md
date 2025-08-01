# 🎓 Moodle en Google Cloud Platform (GKE)

Despliegue completo de Moodle en Google Kubernetes Engine (GKE) con MySQL y almacenamiento persistente.

## 🏗️ Arquitectura

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   LoadBalancer  │    │   Moodle Pod    │    │   MySQL Pod     │
│   (External IP) │◄──►│   (Port 8080)   │◄──►│   (Port 3306)   │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                              │                       │
                              ▼                       ▼
                       ┌─────────────────┐    ┌─────────────────┐
                       │ Moodle PVC      │    │ MySQL PVC       │
                       │ (20Gi)          │    │ (10Gi)          │
                       └─────────────────┘    └─────────────────┘
```

## 📋 Prerrequisitos

- ✅ Cluster GKE configurado y funcionando
- ✅ `kubectl` configurado para el cluster
- ✅ Namespace `moodle` creado
- ✅ Storage classes disponibles

## 🚀 Despliegue Rápido

### Opción 1: Despliegue Automático (Recomendado)

```bash
# Dar permisos de ejecución al script
chmod +x deploy-simple.sh

# Ejecutar el despliegue completo
./deploy-simple.sh
```

### Opción 2: Despliegue Manual

```bash
# 1. Limpiar recursos existentes
kubectl delete namespace moodle --ignore-not-found=true
sleep 15

# 2. Crear namespace
kubectl create namespace moodle

# 3. Aplicar configuración
kubectl apply -f k8s-moodle-simple.yaml

# 4. Monitorear el despliegue
kubectl get pods -n moodle -w
```

## 📊 Monitoreo del Despliegue

```bash
# Ver estado de los pods
kubectl get pods -n moodle

# Ver logs de Moodle
kubectl logs -f deployment/moodle -n moodle

# Ver logs de MySQL
kubectl logs -f deployment/mysql -n moodle

# Ver servicios
kubectl get svc -n moodle

# Ver PVCs
kubectl get pvc -n moodle
```

## 🌐 Acceso a Moodle

Una vez que el despliegue esté completo:

```bash
# Obtener la IP externa
kubectl get svc moodle -n moodle
```

**Credenciales de acceso:**
- **URL**: `http://[EXTERNAL-IP]`
- **Usuario**: `admin`
- **Contraseña**: `moodle12345`

## 🔧 Configuración

### Variables de Entorno Importantes

- `MOODLE_DATABASE_HOST`: `mysql`
- `MOODLE_DATABASE_NAME`: `moodle`
- `MOODLE_USERNAME`: `admin`
- `MOODLE_PASSWORD`: `moodle12345`
- `MOODLE_EMAIL`: `admin@moodle.local`

### Recursos Asignados

- **MySQL**: 512Mi RAM, 250m CPU
- **Moodle**: 1Gi RAM, 500m CPU
- **Almacenamiento**: 10Gi (MySQL) + 20Gi (Moodle)

## 🛠️ Solución de Problemas

### Pod en CrashLoopBackOff

```bash
# Ver logs detallados
kubectl describe pod -l app=moodle -n moodle
kubectl logs -f deployment/moodle -n moodle
```

### PVC sin vincular

```bash
# Verificar storage classes
kubectl get storageclass

# Verificar PVCs
kubectl get pvc -n moodle
kubectl describe pvc -n moodle
```

### Problemas de conectividad de base de datos

```bash
# Verificar que MySQL esté corriendo
kubectl get pods -l app=mysql -n moodle

# Probar conectividad desde Moodle
kubectl exec -it deployment/moodle -n moodle -- mysql -h mysql -u moodle -p
```

## 🧹 Limpieza

```bash
# Eliminar todo el namespace (incluye todos los recursos)
kubectl delete namespace moodle

# Verificar eliminación
kubectl get namespace moodle
```

## 📁 Estructura de Archivos

```
moodle-campusvirtual/
├── k8s-moodle-deployment.yaml    # Configuración completa
├── k8s-moodle-simple.yaml        # Configuración simplificada
├── deploy-moodle.sh              # Script de despliegue completo
├── deploy-simple.sh              # Script de despliegue simplificado
└── README.md                     # Este archivo
```

## 🔒 Seguridad

- Las contraseñas están codificadas en base64 en los secrets
- MySQL solo es accesible desde dentro del cluster
- Moodle expuesto a través de LoadBalancer (puede configurarse con HTTPS)

## 📈 Escalabilidad

Para escalar Moodle:

```bash
# Escalar a 3 réplicas
kubectl scale deployment moodle --replicas=3 -n moodle

# Verificar escalado
kubectl get pods -n moodle
```

## 🎯 Estado del Proyecto

- ✅ Cluster GKE configurado
- ✅ Storage classes disponibles
- ✅ Namespace moodle creado
- ✅ Configuración de despliegue lista
- ✅ Scripts de automatización creados

**¡Listo para desplegar! 🚀**

