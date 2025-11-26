# Stage 1: Builder (extract WP core; minimal deps for tarball)
FROM alpine:3.21 AS builder

# System users pre-apk (idempotent; www-data UID/GID 82 for WP chown)
RUN getent group www-data >/dev/null || addgroup -S www-data && \
    getent passwd www-data >/dev/null || adduser -S www-data -G www-data

RUN apk add --no-cache \
        wget ca-certificates && \
    mkdir -p /tmp/wp && \
    cd /tmp/wp && \
    wget -qO- https://wordpress.org/latest.tar.gz | tar xz --strip-components=1 && \
    chown -R www-data:www-data /tmp/wp

# Stage 2: Runtime (PHP83-FPM + ca-certificates/curl for PHAR + WP core + WP-CLI)
FROM alpine:3.21 AS runtime

# System users pre-apk (idempotent)
RUN getent group www-data >/dev/null || addgroup -S www-data && \
    getent passwd www-data >/dev/null || adduser -S www-data -G www-data

RUN apk add --no-cache \
        ca-certificates \
        curl \
        php83 \
        php83-phar \
        php83-fpm \
        php83-mysqli \
        php83-curl \
        php83-gd \
        php83-mbstring \
        php83-xml \
        php83-zip \
        php83-zlib \
        php83-opcache && \
    mkdir -p /var/log/php /var/www/html /run/php /var/lib/php/{session,wsdl} /usr/local/bin/ /etc/php83/php-fpm.d/ && \
    chown -R www-data:www-data /var/www/html /var/log/php /run/php /var/lib/php /usr/local/bin/ /etc/php83/php-fpm.d/

# Install WP-CLI (PHAR from pinned releases; executable, PATH-integrated; verified)
RUN curl --retry 3 --retry-delay 5 -fsSL https://github.com/wp-cli/wp-cli/releases/download/v2.12.0/wp-cli-2.12.0.phar -o /usr/local/bin/wp && \
    chmod +x /usr/local/bin/wp && \
    wp --info  # Immutable smoke-test (fails build on corruption/unavailability)

# Copy artifacts (chown to www-data for non-root runtime)
COPY --from=builder --chown=www-data:www-data /tmp/wp /var/www/html
COPY tools/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh && \
    chown www-data:www-data /usr/local/bin/entrypoint.sh

# PHP-FPM conf (Alpine path: php83/php-fpm.d/www.conf)
COPY conf/php-fpm.conf /etc/php83/php-fpm.d/www.conf

USER www-data
EXPOSE 9000
STOPSIGNAL SIGTERM
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD ["/usr/local/bin/wp", "core", "is-installed", "--allow-root"] || exit 1

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["php-fpm83"]
