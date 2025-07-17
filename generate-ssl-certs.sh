#!/bin/bash

echo "🔐 === GENERANDO CERTIFICADOS SSL TEMPORALES ==="
echo ""

# Verificar si OpenSSL está disponible
if ! command -v openssl &> /dev/null; then
    echo "❌ Error: OpenSSL no está disponible"
    echo "   Instalando OpenSSL..."
    apt-get update && apt-get install -y openssl
fi

# Crear directorio para certificados
mkdir -p ssl-certs
cd ssl-certs

echo "🔧 Generando certificado SSL temporal..."
echo "   Dominio: campusvirtual.telesalud.gob.sv"
echo ""

# Generar clave privada
openssl genrsa -out key.pem 2048

# Generar certificado autofirmado
openssl req -new -x509 -key key.pem -out cert.pem -days 365 -subj "/C=SV/ST=San Salvador/L=San Salvador/O=Telesalud/OU=IT/CN=campusvirtual.telesalud.gob.sv"

# Verificar que los archivos se crearon
if [ -f "cert.pem" ] && [ -f "key.pem" ]; then
    echo "✅ Certificados generados exitosamente:"
    echo "   cert.pem - Certificado público"
    echo "   key.pem - Clave privada"
    echo ""
    
    # Mostrar información del certificado
    echo "📋 Información del certificado:"
    openssl x509 -in cert.pem -text -noout | grep -E "(Subject:|Issuer:|Not Before|Not After)"
    echo ""
    
    # Crear secreto en Kubernetes
    echo "🔐 Creando secreto SSL en Kubernetes..."
    kubectl create secret tls cloudflare-cert --cert=cert.pem --key=key.pem -n moodle --dry-run=client -o yaml | kubectl apply -f -
    
    if [ $? -eq 0 ]; then
        echo "✅ Secreto SSL creado exitosamente"
    else
        echo "❌ Error al crear el secreto SSL"
        exit 1
    fi
    
else
    echo "❌ Error: No se pudieron generar los certificados"
    exit 1
fi

echo ""
echo "🎉 === CERTIFICADOS SSL LISTOS ==="
echo ""
echo "📝 Notas importantes:"
echo "   - Estos son certificados autofirmados para desarrollo"
echo "   - Para producción, usa certificados de una CA confiable"
echo "   - Los certificados expiran en 365 días"
echo ""
echo "🔍 Para verificar el secreto:"
echo "   kubectl get secret cloudflare-cert -n moodle"
echo ""
echo "🚀 Ahora puedes ejecutar el despliegue:"
echo "   ./auto-deploy-moodle.sh" 