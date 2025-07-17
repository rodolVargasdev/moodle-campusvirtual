#!/bin/bash

echo "🔧 === CORRIGIENDO DOCKERFILE ==="
echo ""

# Verificar si el Dockerfile existe
if [ ! -f "Dockerfile" ]; then
    echo "❌ Error: No se encontró el Dockerfile"
    exit 1
fi

# Verificar la primera línea del Dockerfile
FIRST_LINE=$(head -1 Dockerfile)
echo "📋 Primera línea actual: $FIRST_LINE"

if [[ "$FIRST_LINE" == *"moodle:latest"* ]]; then
    echo "⚠️  Corrigiendo Dockerfile..."
    
    # Crear backup
    cp Dockerfile Dockerfile.backup
    
    # Reemplazar la primera línea
    sed -i '1s|FROM moodle:latest|FROM bitnami/moodle:latest|' Dockerfile
    
    echo "✅ Dockerfile corregido"
    echo "📋 Nueva primera línea: $(head -1 Dockerfile)"
else
    echo "✅ Dockerfile ya está correcto"
fi

echo ""
echo "🚀 Ahora puedes ejecutar el despliegue:"
echo "   ./auto-deploy-moodle.sh" 