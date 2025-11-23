# Stage 1: Builder (install WP, deps)
FROM debian:bookworm-slim AS builder
RUN apt-get update -qq && apt-get install -y --no-install-recommends \
    wget ca-certificates gnupg lsb-release \
    && mkdir -p /tmp/wp \
    && cd /tmp/wp \
    && wget -qO- https://wordpress.org/latest.tar.gz | tar xz --strip-components=1 \
    && chown -R 33:33 /tmp/wp

# Stage 2: Runtime (PHP-FPM + WP)
FROM debian:bookworm-slim AS runtime
RUN apt-get update -qq && apt-get install -y --no-install-recommends \
    php8.2-fpm php8.2-mysql php8.2-curl php8.2-gd php8.2-mbstring php8.2-xml php8.2-zip php8.2-xmlrpc \
    && apt-get clean && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /var/log/php /var/www/html /run/php \
    && chown -R www-data:www-data /var/www/html /var/log/php /run/php

# Copy WP from builder
COPY --from=builder --chown=www-data:www-data /tmp/wp /var/www/html
COPY --chown=www-data:www-data tools/entrypoint.sh /usr/local/bin/

# PHP-FPM config
COPY conf/php-fpm.conf /etc/php/8.2/fpm/php-fpm.conf
COPY conf/www.conf /etc/php/8.2/fpm/pool.d/www.conf

USER www-data
EXPOSE 9000
STOPSIGNAL SIGTERM
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD ["/usr/local/bin/wp", "core", "is-installed", "--allow-root"] || exit 1

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["php-fpm8.2"]
