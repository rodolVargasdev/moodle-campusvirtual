# Script para configurar GCP y GKE para Moodle en Windows PowerShell
# Uso: .\setup-gcp.ps1 [PROJECT_ID] [ZONE] [CLUSTER_NAME]

param(
    [string]$PROJECT_ID = "tu-project-id",
    [string]$ZONE = "us-central1-a",
    [string]$CLUSTER_NAME = "moodle-cluster"
)

Write-Host "🚀 Configurando GCP y GKE para Moodle..." -ForegroundColor Green
Write-Host "Proyecto: $PROJECT_ID" -ForegroundColor Yellow
Write-Host "Zona: $ZONE" -ForegroundColor Yellow
Write-Host "Cluster: $CLUSTER_NAME" -ForegroundColor Yellow

# Verificar que gcloud esté instalado
try {
    gcloud version | Out-Null
} catch {
    Write-Host "❌ Error: gcloud no está instalado. Por favor instala Google Cloud SDK." -ForegroundColor Red
    exit 1
}

# Verificar que kubectl esté instalado
try {
    kubectl version --client | Out-Null
} catch {
    Write-Host "❌ Error: kubectl no está instalado. Por favor instala kubectl." -ForegroundColor Red
    exit 1
}

# Autenticarse con GCP
Write-Host "🔐 Autenticándose con GCP..." -ForegroundColor Cyan
gcloud auth login

# Configurar proyecto
Write-Host "📋 Configurando proyecto: $PROJECT_ID" -ForegroundColor Cyan
gcloud config set project $PROJECT_ID

# Habilitar APIs necesarias
Write-Host "🔧 Habilitando APIs necesarias..." -ForegroundColor Cyan
gcloud services enable container.googleapis.com
gcloud services enable compute.googleapis.com
gcloud services enable dns.googleapis.com

# Crear cluster GKE
Write-Host "🏗️ Creando cluster GKE: $CLUSTER_NAME" -ForegroundColor Cyan
gcloud container clusters create $CLUSTER_NAME `
  --zone=$ZONE `
  --num-nodes=3 `
  --machine-type=n1-standard-2 `
  --disk-size=50 `
  --enable-autoscaling `
  --min-nodes=1 `
  --max-nodes=5 `
  --enable-network-policy `
  --enable-ip-alias `
  --addons=HttpLoadBalancing,HorizontalPodAutoscaling

# Configurar kubectl
Write-Host "⚙️ Configurando kubectl..." -ForegroundColor Cyan
gcloud container clusters get-credentials $CLUSTER_NAME --zone=$ZONE

# Verificar cluster
Write-Host "✅ Verificando cluster..." -ForegroundColor Cyan
kubectl cluster-info
kubectl get nodes

Write-Host "🎉 Configuración de GCP y GKE completada!" -ForegroundColor Green
Write-Host ""
Write-Host "📝 Próximos pasos:" -ForegroundColor Yellow
Write-Host "1. Instalar Helm: https://helm.sh/docs/intro/install/" -ForegroundColor White
Write-Host "2. Ejecutar: .\scripts\deploy-moodle.ps1" -ForegroundColor White
Write-Host ""
Write-Host "🔗 Para ver el cluster en la consola web:" -ForegroundColor Yellow
Write-Host "https://console.cloud.google.com/kubernetes/clusters/details/$ZONE/$CLUSTER_NAME" -ForegroundColor White 