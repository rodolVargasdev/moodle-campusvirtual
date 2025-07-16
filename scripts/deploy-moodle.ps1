# Script para desplegar Moodle en GKE en Windows PowerShell
# Uso: .\deploy-moodle.ps1 [DOMAIN] [MYSQL_PASSWORD] [MOODLE_PASSWORD]

param(
    [string]$DOMAIN = "moodle.local",
    [string]$MYSQL_PASSWORD = "moodle123!",
    [string]$MOODLE_PASSWORD = "admin123!"
)

Write-Host "🚀 Desplegando Moodle en GKE..." -ForegroundColor Green
Write-Host "Dominio: $DOMAIN" -ForegroundColor Yellow
Write-Host "Contraseña MySQL: $MYSQL_PASSWORD" -ForegroundColor Yellow
Write-Host "Contraseña Moodle: $MOODLE_PASSWORD" -ForegroundColor Yellow

# Verificar que helm esté instalado
try {
    helm version | Out-Null
} catch {
    Write-Host "❌ Error: helm no está instalado. Por favor instala Helm." -ForegroundColor Red
    exit 1
}

# Verificar que kubectl esté configurado
try {
    kubectl cluster-info | Out-Null
} catch {
    Write-Host "❌ Error: kubectl no está configurado. Ejecuta primero: .\scripts\setup-gcp.ps1" -ForegroundColor Red
    exit 1
}

# Agregar repositorios de Helm
Write-Host "📦 Agregando repositorios de Helm..." -ForegroundColor Cyan
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

# Crear namespaces
Write-Host "🏷️ Creando namespaces..." -ForegroundColor Cyan
kubectl apply -f k8s/namespace.yaml

# Aplicar storage classes
Write-Host "💾 Aplicando storage classes..." -ForegroundColor Cyan
kubectl apply -f k8s/storage-class.yaml

# Instalar Nginx Ingress Controller
Write-Host "🌐 Instalando Nginx Ingress Controller..." -ForegroundColor Cyan
helm install nginx-ingress ingress-nginx/ingress-nginx `
  --namespace ingress-nginx `
  --create-namespace `
  --set controller.service.type=LoadBalancer `
  --wait

# Esperar a que el Load Balancer esté listo
Write-Host "⏳ Esperando a que el Load Balancer esté listo..." -ForegroundColor Cyan
kubectl wait --namespace ingress-nginx `
  --for=condition=ready pod `
  --selector=app.kubernetes.io/component=controller `
  --timeout=300s

# Obtener IP externa
Write-Host "🔍 Obteniendo IP externa..." -ForegroundColor Cyan
$EXTERNAL_IP = ""
while (-not $EXTERNAL_IP) {
    $EXTERNAL_IP = kubectl get svc -n ingress-nginx nginx-ingress-ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
    if (-not $EXTERNAL_IP) {
        Write-Host "⏳ Esperando IP externa..." -ForegroundColor Yellow
        Start-Sleep -Seconds 10
    }
}

Write-Host "✅ IP Externa obtenida: $EXTERNAL_IP" -ForegroundColor Green

# Instalar MySQL
Write-Host "🗄️ Instalando MySQL..." -ForegroundColor Cyan
helm install moodle-mysql bitnami/mysql `
  --namespace moodle `
  --set auth.rootPassword="$MYSQL_PASSWORD" `
  --set auth.database=moodle `
  --set auth.username=moodle `
  --set auth.password="$MYSQL_PASSWORD" `
  --set primary.persistence.size=20Gi `
  --set primary.persistence.storageClass=standard-rwo `
  --wait

# Esperar a que MySQL esté listo
Write-Host "⏳ Esperando a que MySQL esté listo..." -ForegroundColor Cyan
kubectl wait --namespace moodle `
  --for=condition=ready pod `
  --selector=app.kubernetes.io/name=mysql `
  --timeout=300s

# Actualizar values.yaml con la IP externa
Write-Host "📝 Actualizando configuración con IP externa..." -ForegroundColor Cyan
$valuesContent = Get-Content charts/moodle/values.yaml -Raw
$valuesContent = $valuesContent -replace "moodle.local", "$EXTERNAL_IP.nip.io"
$valuesContent = $valuesContent -replace "http://moodle.local", "http://$EXTERNAL_IP.nip.io"
$valuesContent | Set-Content charts/moodle/values.yaml

# Instalar Moodle
Write-Host "📚 Instalando Moodle..." -ForegroundColor Cyan
helm install moodle ./charts/moodle `
  --namespace moodle `
  --set database.host=moodle-mysql.moodle.svc.cluster.local `
  --set database.name=moodle `
  --set database.user=moodle `
  --set database.password="$MYSQL_PASSWORD" `
  --set persistence.size=50Gi `
  --set moodle.password="$MOODLE_PASSWORD" `
  --set moodle.siteurl="http://$EXTERNAL_IP.nip.io" `
  --wait

# Esperar a que Moodle esté listo
Write-Host "⏳ Esperando a que Moodle esté listo..." -ForegroundColor Cyan
kubectl wait --namespace moodle `
  --for=condition=ready pod `
  --selector=app.kubernetes.io/name=moodle `
  --timeout=300s

# Verificar el despliegue
Write-Host "✅ Verificando despliegue..." -ForegroundColor Cyan
kubectl get pods -n moodle
kubectl get svc -n moodle
kubectl get ingress -n moodle

Write-Host ""
Write-Host "🎉 ¡Moodle desplegado exitosamente!" -ForegroundColor Green
Write-Host ""
Write-Host "📋 Información de acceso:" -ForegroundColor Yellow
Write-Host "URL: http://$EXTERNAL_IP.nip.io" -ForegroundColor White
Write-Host "Usuario: admin" -ForegroundColor White
Write-Host "Contraseña: $MOODLE_PASSWORD" -ForegroundColor White
Write-Host ""
Write-Host "🔧 Para verificar el estado:" -ForegroundColor Yellow
Write-Host "kubectl get pods -n moodle" -ForegroundColor White
Write-Host "kubectl logs -f deployment/moodle -n moodle" -ForegroundColor White
Write-Host ""
Write-Host "🗄️ Para acceder a MySQL:" -ForegroundColor Yellow
Write-Host "kubectl exec -it `$(kubectl get pods -n moodle -l app.kubernetes.io/name=mysql -o jsonpath='{.items[0].metadata.name}') -n moodle -- mysql -u root -p" -ForegroundColor White
Write-Host ""
Write-Host "⚠️ IMPORTANTE: Cambia las contraseñas por defecto después del primer acceso." -ForegroundColor Red 