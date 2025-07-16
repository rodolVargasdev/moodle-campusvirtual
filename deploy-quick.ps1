# Script de despliegue rápido de Moodle en GCP
# Este script automatiza todo el proceso de despliegue

param(
    [string]$PROJECT_ID = "tu-project-id",
    [string]$ZONE = "us-central1-a",
    [string]$CLUSTER_NAME = "moodle-cluster",
    [string]$MYSQL_PASSWORD = "moodle123!",
    [string]$MOODLE_PASSWORD = "admin123!"
)

Write-Host "🚀 Despliegue rápido de Moodle en GCP" -ForegroundColor Green
Write-Host "=====================================" -ForegroundColor Green

# Verificar herramientas
Write-Host "🔍 Verificando herramientas..." -ForegroundColor Cyan

$tools = @("gcloud", "kubectl", "helm")
foreach ($tool in $tools) {
    try {
        & $tool version | Out-Null
        Write-Host "✅ $tool está instalado" -ForegroundColor Green
    } catch {
        Write-Host "❌ $tool no está instalado" -ForegroundColor Red
        Write-Host "Por favor instala $tool antes de continuar" -ForegroundColor Yellow
        exit 1
    }
}

# Paso 1: Configurar GCP
Write-Host ""
Write-Host "📋 Paso 1: Configurando GCP..." -ForegroundColor Yellow
& "$PSScriptRoot\scripts\setup-gcp.ps1" -PROJECT_ID $PROJECT_ID -ZONE $ZONE -CLUSTER_NAME $CLUSTER_NAME

# Paso 2: Desplegar Moodle
Write-Host ""
Write-Host "📚 Paso 2: Desplegando Moodle..." -ForegroundColor Yellow
& "$PSScriptRoot\scripts\deploy-moodle.ps1" -MYSQL_PASSWORD $MYSQL_PASSWORD -MOODLE_PASSWORD $MOODLE_PASSWORD

Write-Host ""
Write-Host "🎉 ¡Despliegue completado exitosamente!" -ForegroundColor Green
Write-Host ""
Write-Host "📋 Resumen:" -ForegroundColor Yellow
Write-Host "Proyecto: $PROJECT_ID" -ForegroundColor White
Write-Host "Cluster: $CLUSTER_NAME" -ForegroundColor White
Write-Host "Zona: $ZONE" -ForegroundColor White
Write-Host "Contraseña MySQL: $MYSQL_PASSWORD" -ForegroundColor White
Write-Host "Contraseña Moodle: $MOODLE_PASSWORD" -ForegroundColor White
Write-Host ""
Write-Host "🔗 Para acceder a Moodle, obtén la IP externa con:" -ForegroundColor Yellow
Write-Host "kubectl get svc -n ingress-nginx" -ForegroundColor White
Write-Host ""
Write-Host "⚠️ IMPORTANTE: Cambia las contraseñas por defecto después del primer acceso." -ForegroundColor Red 