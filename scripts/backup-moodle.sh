#!/bin/bash

# Script para hacer backup de Moodle
# Uso: ./backup-moodle.sh [BACKUP_DIR]

set -e

# Variables por defecto
BACKUP_DIR=${1:-"./backups"}
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="moodle_backup_$DATE"

echo "💾 Iniciando backup de Moodle..."
echo "Directorio de backup: $BACKUP_DIR"
echo "Nombre del backup: $BACKUP_NAME"

# Crear directorio de backup si no existe
mkdir -p "$BACKUP_DIR"

# Verificar que kubectl esté configurado
if ! kubectl cluster-info &> /dev/null; then
    echo "❌ Error: kubectl no está configurado."
    exit 1
fi

# Obtener credenciales de MySQL
echo "🔐 Obteniendo credenciales de MySQL..."
MYSQL_PASSWORD=$(kubectl get secret moodle-mysql -n moodle -o jsonpath='{.data.mysql-password}' | base64 -d)
MYSQL_POD=$(kubectl get pods -n moodle -l app.kubernetes.io/name=mysql -o jsonpath='{.items[0].metadata.name}')

# Backup de la base de datos
echo "🗄️ Haciendo backup de la base de datos..."
kubectl exec -n moodle "$MYSQL_POD" -- mysqldump -u root -p"$MYSQL_PASSWORD" moodle > "$BACKUP_DIR/${BACKUP_NAME}_database.sql"

# Backup de los archivos de Moodle
echo "📁 Haciendo backup de los archivos de Moodle..."
MOODLE_POD=$(kubectl get pods -n moodle -l app.kubernetes.io/name=moodle -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n moodle "$MOODLE_POD" -- tar czf - /bitnami/moodle > "$BACKUP_DIR/${BACKUP_NAME}_files.tar.gz"

# Crear archivo de información del backup
echo "📝 Creando archivo de información del backup..."
cat > "$BACKUP_DIR/${BACKUP_NAME}_info.txt" << EOF
Backup de Moodle
Fecha: $(date)
Cluster: $(kubectl config current-context)
Namespace: moodle

Componentes incluidos:
- Base de datos MySQL (${BACKUP_NAME}_database.sql)
- Archivos de Moodle (${BACKUP_NAME}_files.tar.gz)

Para restaurar:
1. Restaurar base de datos: mysql -u root -p moodle < ${BACKUP_NAME}_database.sql
2. Restaurar archivos: tar xzf ${BACKUP_NAME}_files.tar.gz -C /
EOF

# Comprimir todo el backup
echo "📦 Comprimiendo backup completo..."
cd "$BACKUP_DIR"
tar czf "${BACKUP_NAME}_complete.tar.gz" "${BACKUP_NAME}_"*
rm "${BACKUP_NAME}_database.sql" "${BACKUP_NAME}_files.tar.gz" "${BACKUP_NAME}_info.txt"

echo "✅ Backup completado exitosamente!"
echo "📁 Archivo de backup: $BACKUP_DIR/${BACKUP_NAME}_complete.tar.gz"
echo ""
echo "📊 Tamaño del backup:"
ls -lh "$BACKUP_DIR/${BACKUP_NAME}_complete.tar.gz"
echo ""
echo "🔄 Para restaurar este backup, ejecuta:"
echo "./scripts/restore-moodle.sh $BACKUP_DIR/${BACKUP_NAME}_complete.tar.gz" 