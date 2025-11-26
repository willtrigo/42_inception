FROM alpine:3.21

# Install MariaDB and dependencies
RUN apk add --no-cache \
    mariadb \
    mariadb-client \
    su-exec && \
    rm -rf /var/cache/apk/*

# Create necessary directories with proper permissions
RUN mkdir -p \
    /var/lib/mysql \
    /run/mysqld \
    /var/log/mysql \
    /etc/my.cnf.d && \
    chown -R mysql:mysql \
    /var/lib/mysql \
    /run/mysqld \
    /var/log/mysql \
    /etc/my.cnf.d && \
    chmod 755 /run/mysqld /var/lib/mysql /var/log/mysql

# Copy configuration
COPY conf/my.cnf /etc/my.cnf.d/mariadb-server.cnf
RUN chown mysql:mysql /etc/my.cnf.d/mariadb-server.cnf

# Copy entrypoint script
COPY tools/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Expose port
EXPOSE 3306

# Healthcheck
HEALTHCHECK --interval=10s --timeout=5s --start-period=60s --retries=5 \
    CMD mariadb-admin ping -h localhost --silent || exit 1

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
