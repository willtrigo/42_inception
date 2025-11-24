# Stage 1: Builder (init datadir, envsubst conf; ephemeral to minimize runtime bloat)
FROM alpine:3.21 AS builder
RUN apk add --no-cache \
        mariadb \
        mariadb-client \
        gettext  # Ephemeral: envsubst for templating only

# System users + dirs (Alpine -S for non-priv; your chown pattern)
RUN addgroup -S mysql && \
    adduser -S mysql -G mysql && \
    mkdir -p /var/lib/mysql /var/run/mysqld /var/log/mysql && \
    chown -R mysql:mysql /var/lib/mysql /var/run/mysqld /var/log/mysql

# Init datadir (your mariadb-install-db; basedir/datadir explicit)
RUN mariadb-install-db --user=mysql --basedir=/usr --datadir=/var/lib/mysql

# Template conf (your envsubst; vars from .env)
COPY conf/my.cnf /etc/my.cnf.d/my.cnf
RUN envsubst '${MYSQL_PORT}' < /etc/my.cnf.d/my.cnf > /etc/my.cnf.d/my.cnf && \
    rm /etc/my.cnf.d/my.cnf  # Prune intermediate (immutable)

# Entrypoint (chown for USER mysql)
COPY tools/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh && \
    chown mysql:mysql /usr/local/bin/entrypoint.sh

# Stage 2: Runtime (copy artifacts; exec mariadbd as non-root)
FROM alpine:3.21 AS runtime
RUN apk add --no-cache \
        mariadb \
        mariadb-client && \
    addgroup -S mysql && \
    adduser -S mysql -G mysql && \
    mkdir -p /var/lib/mysql /var/run/mysqld /var/log/mysql && \
    chown -R mysql:mysql /var/lib/mysql /var/run/mysqld /var/log/mysql

# Copy from builder (pre-init datadir + conf; atomic chown)
COPY --from=builder --chown=mysql:mysql /var/lib/mysql /var/lib/mysql
COPY --from=builder --chown=mysql:mysql /etc/my.cnf.d/my.cnf /etc/my.cnf.d/
COPY --from=builder --chown=mysql:mysql /usr/local/bin/entrypoint.sh /usr/local/bin/

USER mysql
EXPOSE 3306
STOPSIGNAL SIGTERM
HEALTHCHECK --interval=30s --timeout=10s --start-period=90s --retries=3 \
    CMD mariadb-admin ping --connect-timeout=5 --silent || exit 1

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["mariadbd", "--user=mysql", "--datadir=/var/lib/mysql"]
