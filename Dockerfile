FROM moodle:latest

# Instalar dependencias adicionales
RUN apt-get update && apt-get install -y \
    libpng-dev \
    libjpeg-dev \
    libfreetype6-dev \
    libzip-dev \
    libxml2-dev \
    libgd-dev \
    libonig-dev \
    libcurl4-openssl-dev \
    libssl-dev \
    libmcrypt-dev \
    libreadline-dev \
    libtidy-dev \
    libxslt1-dev \
    libmagickwand-dev \
    imagemagick \
    ghostscript \
    unzip \
    curl \
    wget \
    git \
    && rm -rf /var/lib/apt/lists/*

# Configurar PHP
RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) \
    gd \
    mbstring \
    xml \
    soap \
    zip \
    curl \
    tidy \
    xsl \
    intl \
    opcache

# Instalar extensiones adicionales
RUN pecl install imagick \
    && docker-php-ext-enable imagick

# Configurar PHP para Moodle
RUN echo "memory_limit = 2G" >> /usr/local/etc/php/conf.d/moodle.ini \
    && echo "max_execution_time = 1800" >> /usr/local/etc/php/conf.d/moodle.ini \
    && echo "max_input_vars = 5000" >> /usr/local/etc/php/conf.d/moodle.ini \
    && echo "upload_max_filesize = 100M" >> /usr/local/etc/php/conf.d/moodle.ini \
    && echo "post_max_size = 100M" >> /usr/local/etc/php/conf.d/moodle.ini \
    && echo "max_input_time = 300" >> /usr/local/etc/php/conf.d/moodle.ini \
    && echo "output_buffering = 4096" >> /usr/local/etc/php/conf.d/moodle.ini

# Configurar Apache
RUN a2enmod rewrite \
    && a2enmod ssl \
    && a2enmod headers \
    && a2enmod expires \
    && a2enmod deflate

# Crear directorio para moodledata
RUN mkdir -p /var/moodledata \
    && chown -R www-data:www-data /var/moodledata \
    && chmod 755 /var/moodledata

# Configurar Apache para Moodle
COPY apache-moodle.conf /etc/apache2/sites-available/000-default.conf

# Script de inicio personalizado
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

EXPOSE 8080 8443

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["apache2-foreground"] 