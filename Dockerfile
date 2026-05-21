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

# Intentional info leak: expose phpinfo + a couple of bait files.
COPY assets/info.php          /var/www/html/info.php
COPY assets/adminer.php       /var/www/html/adminer.php
COPY assets/debug.log         /var/www/html/debug.log
COPY assets/wp-config.php.bak /var/www/html/wp-config.php.bak
COPY assets/dump.sql          /var/www/html/dump.sql
COPY assets/.env              /var/www/html/.env
COPY assets/htaccess           /var/www/html/.htaccess
COPY assets/git-head           /var/www/html/.git/HEAD
COPY assets/git-config         /var/www/html/.git/config

# Plugins ZIPs (mounted in by install.sh from /plugins/ on host) plus a marker.
COPY assets/lab-banner.txt /var/www/html/lab-banner.txt

EXPOSE 80
