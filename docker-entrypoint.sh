#!/bin/bash
set -e

# Función para configurar permisos
setup_permissions() {
    echo "Configurando permisos..."
    
    # Configurar permisos para /var/www/html
    if [ -d "/var/www/html" ]; then
        chown -R www-data:www-data /var/www/html
        chmod -R 755 /var/www/html
    fi
    
    # Configurar permisos para /var/moodledata
    if [ -d "/var/moodledata" ]; then
        chown -R www-data:www-data /var/moodledata
        chmod -R 755 /var/moodledata
    fi
    
    # Crear directorios necesarios si no existen
    mkdir -p /var/www/html/moodledata
    chown -R www-data:www-data /var/www/html/moodledata
    chmod -R 755 /var/www/html/moodledata
}

# Función para verificar la base de datos
check_database() {
    echo "Verificando conexión a la base de datos..."
    
    # Variables de entorno para la base de datos
    DB_HOST=${MOODLE_DATABASE_HOST:-localhost}
    DB_PORT=${MOODLE_DATABASE_PORT_NUMBER:-3306}
    DB_NAME=${MOODLE_DATABASE_NAME:-moodle}
    DB_USER=${MOODLE_DATABASE_USER:-root}
    DB_PASS=${MOODLE_DATABASE_PASSWORD:-}
    
    # Intentar conectar a la base de datos
    if command -v mysql &> /dev/null; then
        echo "Probando conexión a MySQL..."
        mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASS" -e "SELECT 1;" > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            echo "Conexión a MySQL exitosa"
        else
            echo "Advertencia: No se pudo conectar a MySQL"
        fi
    fi
}

# Función para configurar Moodle
setup_moodle() {
    echo "Configurando Moodle..."
    
    # Crear archivo de configuración si no existe
    if [ ! -f "/var/www/html/config.php" ]; then
        echo "Creando archivo de configuración de Moodle..."
        cat > /var/www/html/config.php << 'EOF'
<?php
// Configuración básica de Moodle
$CFG = new stdClass();
$CFG->dbtype    = 'mysqli';
$CFG->dblibrary = 'native';
$CFG->dbhost    = getenv('MOODLE_DATABASE_HOST') ?: 'localhost';
$CFG->dbname    = getenv('MOODLE_DATABASE_NAME') ?: 'moodle';
$CFG->dbuser    = getenv('MOODLE_DATABASE_USER') ?: 'root';
$CFG->dbpass    = getenv('MOODLE_DATABASE_PASSWORD') ?: '';
$CFG->prefix    = 'mdl_';
$CFG->dboptions = array(
    'dbpersist' => 0,
    'dbport' => getenv('MOODLE_DATABASE_PORT_NUMBER') ?: '3306',
    'dbsocket' => '',
    'dbcollation' => 'utf8mb4_unicode_ci',
);

$CFG->wwwroot   = getenv('MOODLE_WWWROOT') ?: 'http://localhost:8080';
$CFG->dataroot  = '/var/moodledata';
$CFG->admin     = 'admin';

$CFG->directorypermissions = 02777;

require_once(__DIR__ . '/lib/setup.php');
EOF
        chown www-data:www-data /var/www/html/config.php
        chmod 644 /var/www/html/config.php
    fi
}

# Función para verificar extensiones PHP
check_php_extensions() {
    echo "Verificando extensiones PHP..."
    
    # Extensiones requeridas por Moodle
    required_extensions=(
        "gd"
        "mbstring"
        "xml"
        "soap"
        "zip"
        "curl"
        "tidy"
        "xsl"
        "intl"
        "opcache"
    )
    
    for ext in "${required_extensions[@]}"; do
        if php -m | grep -q "^$ext$"; then
            echo "✓ Extensión $ext está disponible"
        else
            echo "✗ Extensión $ext NO está disponible"
        fi
    done
}

# Función principal
main() {
    echo "=== Iniciando Moodle con configuración personalizada ==="
    
    # Configurar permisos
    setup_permissions
    
    # Verificar extensiones PHP
    check_php_extensions
    
    # Verificar base de datos
    check_database
    
    # Configurar Moodle
    setup_moodle
    
    echo "=== Configuración completada ==="
    echo "Iniciando Apache..."
    
    # Ejecutar el comando original
    exec "$@"
}

# Ejecutar función principal
main "$@" 