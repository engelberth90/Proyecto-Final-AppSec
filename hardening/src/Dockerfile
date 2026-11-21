# wordpress-vulnerable-lab — imagen endurecida
# Basado en el laboratorio de Ayi NEDJIMI (MIT). Modificado para el proyecto de
# mitigación: Proyecto-Final-AppSec.
#
# M-08: la imagen base se actualiza de WordPress 5.3 / PHP 7.4 / Apache 2.4.38
# (sin soporte, hallazgo 2.4) a una versión soportada: la última de WordPress
# sobre PHP 8.3 y el Apache que acompaña a esa imagen. El núcleo y los
# complementos se llevan a su última versión en apply/m08-componentes-desactualizados.sh.

FROM wordpress:php8.3-apache

LABEL maintainer="Proyecto-Final-AppSec"
LABEL org.opencontainers.image.description="WordPress lab endurecido — mitigacion de vulnerabilidades sobre el laboratorio de Ayi NEDJIMI."

ENV DEBIAN_FRONTEND=noninteractive
# Herramientas de línea de comandos para los scripts de instalación y verificación.
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        curl ca-certificates less unzip git default-mysql-client procps; \
    rm -rf /var/lib/apt/lists/*

# wp-cli para los scripts de instalación/verificación.
RUN curl -fsSL -o /usr/local/bin/wp \
        https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar && \
    chmod +x /usr/local/bin/wp && \
    wp --info --allow-root || true

# Apache: WordPress y varios complementos requieren AllowOverride para .htaccess.
RUN a2enmod rewrite headers expires

# M-08: PHP no anuncia su versión en la cabecera X-Powered-By.
COPY hardening/src/php/zz-hardening.ini /usr/local/etc/php/conf.d/zz-hardening.ini

# M-01 / M-02: .htaccess endurecido (sin archivos sensibles, Options -Indexes).
COPY hardening/src/htaccess    /var/www/html/.htaccess

# M-01 / M-02 / M-04 / M-08: configuración de Apache (bloqueo de dotfiles,
# respaldos, logs y xmlrpc.php; retirada de cabeceras; ServerTokens/Signature).
COPY hardening/src/apache/zz-hardening.conf /etc/apache2/conf-available/zz-hardening.conf
RUN a2enconf zz-hardening

# M-02: sin mod_autoindex Apache no puede generar listados de directorios.
RUN a2dismod -f autoindex

# M-01: el log de depuración de WordPress vive fuera del webroot.
RUN install -d -o www-data -g www-data -m 0750 /var/log/wordpress

# M-03 / M-04 / M-08: mu-plugins de endurecimiento.
COPY --chown=www-data:www-data hardening/src/mu-plugins/ /var/www/html/wp-content/mu-plugins/

EXPOSE 80
