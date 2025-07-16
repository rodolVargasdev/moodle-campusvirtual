# 🚀 Moodle Escalable con Filestore en GKE

Despliegue completo de Moodle con escalado horizontal real usando Google Cloud Filestore para almacenamiento compartido.

## 🏗️ Arquitectura

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   LoadBalancer  │    │   Moodle Pod 1  │    │   Moodle Pod 2  │
│   (External IP) │◄──►│   (Port 8080)   │    │   (Port 8080)   │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                              │                       │
                              ▼                       ▼
                       ┌─────────────────┐    ┌─────────────────┐
                       │   Moodle Pod 3  │    │   MySQL Pod     │
                       │   (Port 8080)   │    │   (Port 3306)   │
                       └─────────────────┘    └─────────────────┘
                              │                       │
                              ▼                       ▼
                       ┌─────────────────┐    ┌─────────────────┐
                       │   Filestore     │    │   MySQL PVC     │
                       │   (1TB RWX)     │    │   (10Gi RWO)    │
                       └─────────────────┘    └─────────────────┘
```

## 📋 Prerrequisitos

- ✅ Cluster GKE configurado y funcionando
- ✅ `kubectl` configurado para el cluster
- ✅ `gcloud` autenticado y configurado
- ✅ Proyecto GCP con APIs habilitadas
- ✅ Red VPC configurada

## 🚀 Despliegue Rápido

### 1. Ejecutar el script principal

```bash
# Dar permisos de ejecución
chmod +x setup-filestore-moodle.sh

# Ejecutar configuración completa
./setup-filestore-moodle.sh
```

### 2. Monitorear el progreso

El script automáticamente:
- ✅ Crea instancia de Filestore (1TB)
- ✅ Configura StorageClass RWX
- ✅ Crea PersistentVolume y PVC
- ✅ Despliega Moodle con 3 réplicas
- ✅ Configura LoadBalancer
- ✅ Monitorea el estado

### 3. Acceder a Moodle

Una vez completado, obtendrás:
- **URL**: `http://[EXTERNAL-IP]`
- **Usuario**: `admin`
- **Contraseña**: `moodle12345`

## 📊 Capacidad de Usuarios

### Con 3 réplicas (configuración por defecto):
- **300-600 usuarios simultáneos**
- **150-300 usuarios activos**

### Escalar según demanda:
```bash
# Escalar a 5 réplicas
kubectl scale deployment moodle-scalable --replicas=5 -n moodle

# Escalar a 10 réplicas
kubectl scale deployment moodle-scalable --replicas=10 -n moodle
```

## 🔧 Comandos Útiles

### Monitoreo
```bash
# Ver pods
kubectl get pods -n moodle

# Ver servicios
kubectl get svc -n moodle

# Ver logs
kubectl logs -f deployment/moodle-scalable -n moodle

# Ver uso de recursos
kubectl top pods -n moodle
```

### Escalado
```bash
# Escalar horizontalmente
kubectl scale deployment moodle-scalable --replicas=5 -n moodle

# Ver estado del escalado
kubectl get pods -n moodle -l app=moodle-scalable
```

### Diagnóstico
```bash
# Ver eventos
kubectl get events -n moodle --sort-by='.lastTimestamp'

# Describir pods
kubectl describe pods -l app=moodle-scalable -n moodle

# Ver PVCs
kubectl get pvc -n moodle
```

## 🗄️ Recursos Creados

### Google Cloud:
- **Filestore Instance**: `moodle-filestore` (1TB)
- **Network**: `us-east1-dev-moodle-vpc-01`

### Kubernetes:
- **StorageClass**: `filestore-rwx`
- **PersistentVolume**: `moodle-filestore-pv`
- **PersistentVolumeClaim**: `moodle-filestore-pvc`
- **Deployment**: `moodle-scalable` (3 réplicas)
- **Service**: `moodle-scalable` (LoadBalancer)
- **ConfigMap**: `moodle-config`

## 💰 Costos Estimados

### Filestore (1TB):
- **BASIC_HDD**: ~$200/mes
- **BASIC_SSD**: ~$400/mes
- **ENTERPRISE**: ~$800/mes

### GKE:
- **3 nodos n1-standard-2**: ~$150/mes
- **LoadBalancer**: ~$20/mes

### Total estimado: $370-970/mes

## 🧹 Limpieza

### Limpieza completa:
```bash
chmod +x cleanup-filestore.sh
./cleanup-filestore.sh
```

⚠️ **ADVERTENCIA**: Esto eliminará TODOS los datos permanentemente.

## 🔒 Seguridad

- ✅ Contraseñas en Kubernetes Secrets
- ✅ MySQL solo accesible desde cluster
- ✅ Filestore en red privada
- ✅ LoadBalancer con firewall automático

## 📈 Optimizaciones

### Para alta concurrencia:
1. **Aumentar réplicas**: `kubectl scale deployment moodle-scalable --replicas=10 -n moodle`
2. **Usar Filestore Enterprise**: Mejor rendimiento
3. **Configurar Redis**: Para cache de sesiones
4. **Optimizar MySQL**: Configurar pool de conexiones

### Para producción:
1. **Configurar HTTPS**: Con cert-manager
2. **Backup automático**: De base de datos y archivos
3. **Monitoreo**: Con Prometheus/Grafana
4. **Logs centralizados**: Con Stackdriver

## 🛠️ Solución de Problemas

### Pods en Pending:
```bash
kubectl describe pods -l app=moodle-scalable -n moodle
```

### Problemas de conectividad:
```bash
kubectl logs -l app=moodle-scalable -n moodle
```

### Problemas de almacenamiento:
```bash
kubectl get pvc -n moodle
kubectl describe pvc moodle-filestore-pvc -n moodle
```

## 📞 Soporte

Para problemas específicos:
1. Verificar logs: `kubectl logs -l app=moodle-scalable -n moodle`
2. Verificar eventos: `kubectl get events -n moodle`
3. Verificar recursos: `kubectl top pods -n moodle`

---

**¡Tu Moodle escalable está listo para miles de usuarios! 🎓** 