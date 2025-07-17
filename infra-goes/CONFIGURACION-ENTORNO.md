# Lista de Verificación para Nuevo Entorno

Antes de desplegar en un nuevo entorno, actualizar los siguientes archivos:

## 1. moodle-config.yaml
```yaml
# Cambiar estos valores:
MOODLE_EMAIL: admin@tu-dominio.com
MOODLE_SITE_NAME: "Tu Nombre de Sitio"
MOODLE_DATABASE_PASSWORD: TuNuevaContraseña123!
MOODLE_PASSWORD: TuNuevaContraseña123!
```

## 2. mariadb-deployment.yaml
```yaml
# Cambiar contraseñas en las variables de entorno:
- name: MARIADB_ROOT_PASSWORD
  value: "TuNuevaContraseña123!"
- name: MARIADB_PASSWORD  
  value: "TuNuevaContraseña123!"
```

## 3. deployment.yaml
```yaml
# Ajustar recursos si es necesario:
resources:
  requests:
    cpu: 1500m      # Cambiar según necesidades
    memory: 3Gi     # Cambiar según necesidades
  limits:
    cpu: "3"        # Cambiar según necesidades  
    memory: 6Gi     # Cambiar según necesidades
```

## 4. moodle-pvcs.yaml
```yaml
# Cambiar tamaño de almacenamiento si es necesario:
spec:
  resources:
    requests:
      storage: 10Gi    # Cambiar según necesidades
  storageClassName: standard-rwo  # Cambiar según cluster
```

## 5. ingress.yaml (si se usa)
```yaml
# Actualizar dominio y certificados:
  rules:
  - host: tu-dominio.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: moodle-service
            port:
              number: 80
  tls:
  - hosts:
    - tu-dominio.com
    secretName: tu-certificado-ssl
```

## 6. service.yaml
```yaml
# Si necesitas NodePort específico:
spec:
  type: NodePort
  ports:
  - port: 80
    targetPort: 8080
    nodePort: 30080    # Cambiar si es necesario
```

## Valores Críticos a Cambiar:
- ✅ Contraseñas (usar Kubernetes Secrets en producción)
- ✅ Dominios y certificados SSL
- ✅ Tamaños de almacenamiento
- ✅ Límites de recursos
- ✅ Nombres de StorageClass (según cluster)
- ✅ Email del administrador
- ✅ Nombre del sitio
