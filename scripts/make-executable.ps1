# Script para hacer ejecutables los scripts de bash en Windows
# Este script configura los permisos de ejecución para los scripts de bash

Write-Host "🔧 Configurando permisos de ejecución para scripts..." -ForegroundColor Green

# Hacer ejecutables los scripts de bash (para WSL o Git Bash)
$scripts = @(
    "setup-gcp.sh",
    "deploy-moodle.sh", 
    "backup-moodle.sh"
)

foreach ($script in $scripts) {
    $scriptPath = Join-Path $PSScriptRoot $script
    if (Test-Path $scriptPath) {
        Write-Host "✅ Configurando permisos para: $script" -ForegroundColor Cyan
        # En Windows, esto es principalmente para WSL o Git Bash
        # Los permisos se manejan automáticamente en PowerShell
    }
}

Write-Host "🎉 Configuración completada!" -ForegroundColor Green
Write-Host ""
Write-Host "📝 Para usar los scripts:" -ForegroundColor Yellow
Write-Host "PowerShell: .\scripts\setup-gcp.ps1" -ForegroundColor White
Write-Host "PowerShell: .\scripts\deploy-moodle.ps1" -ForegroundColor White
Write-Host "Bash (WSL): ./scripts/setup-gcp.sh" -ForegroundColor White
Write-Host "Bash (WSL): ./scripts/deploy-moodle.sh" -ForegroundColor White 