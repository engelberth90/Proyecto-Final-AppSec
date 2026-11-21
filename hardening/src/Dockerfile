# wordpress-vulnerable-lab — custom WordPress image
# Author: Ayi NEDJIMI
#
# Pinned to an old-ish base on purpose: WP 5.3 + PHP 7.4 so the
# installed-plugin matrix lights up CVE fingerprints.

FROM wordpress:5.3-php7.4-apache

LABEL maintainer="Ayi NEDJIMI <ayinedjimi@users.noreply.github.com>"
LABEL org.opencontainers.image.source="https://github.com/ayinedjimi/wordpress-vulnerable-lab"
LABEL org.opencontainers.image.description="Intentionally vulnerable WordPress lab — for security training, CTF and scanner benchmarking."

ENV DEBIAN_FRONTEND=noninteractive
# WordPress 5.3 image is on Debian Buster which is EOL — point apt at the archive
# so we can still install useful CLI tools inside the lab.
RUN set -eux; \
    printf 'deb http://archive.debian.org/debian buster main\n\
deb http://archive.debian.org/debian buster-updates main\n\
deb http://archive.debian.org/debian-security buster/updates main\n' \
      > /etc/apt/sources.list; \
    printf 'Acquire::Check-Valid-Until "false";\n' \
      > /etc/apt/apt.conf.d/99no-check-valid-until; \
    apt-get -o Acquire::AllowInsecureRepositories=true update || true; \
    apt-get install -y --no-install-recommends --allow-unauthenticated \
        curl ca-certificates less unzip git default-mysql-client \
        nano netcat procps || true; \
    rm -rf /var/lib/apt/lists/*

# wp-cli for the install/reset/verify scripts.
RUN curl -fsSL -o /usr/local/bin/wp \
        https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar && \
    chmod +x /usr/local/bin/wp && \
    wp --info --allow-root || true

# Apache: allow .htaccess overrides everywhere (misconfig demo + WP rewrite).
RUN a2enmod rewrite headers expires
RUN sed -i 's|AllowOverride None|AllowOverride All|g' /etc/apache2/apache2.conf

# M-01: no se copian al webroot archivos de configuración, respaldos, volcados,
# logs, metadatos de git ni herramientas de diagnóstico (info.php, adminer.php).
# Lo que no está en el webroot no se puede descargar.
# M-02: .htaccess endurecido (Options -Indexes en lugar de +Indexes).
COPY hardening/src/htaccess    /var/www/html/.htaccess

# M-01: capa de defensa en Apache (bloquea dotfiles, respaldos, volcados y logs).
# M-02: desactiva Indexes en el directorio del sitio.
COPY hardening/src/apache/zz-hardening.conf /etc/apache2/conf-available/zz-hardening.conf
RUN a2enconf zz-hardening

# M-02: sin mod_autoindex Apache no puede generar listados de directorios,
# aunque un .htaccess de la aplicación o de un complemento active Indexes.
RUN a2dismod -f autoindex

# M-01: el log de depuración de WordPress vive fuera del webroot.
RUN install -d -o www-data -g www-data -m 0750 /var/log/wordpress

# Plugins ZIPs (mounted in by install.sh from /plugins/ on host) plus a marker.
COPY assets/lab-banner.txt /var/www/html/lab-banner.txt

EXPOSE 80
