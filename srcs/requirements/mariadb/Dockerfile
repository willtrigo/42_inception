# Stage 1: Builder (any deps if needed; none here)
FROM debian:bookworm-slim AS builder

# Stage 2: Runtime
FROM debian:bookworm-slim AS runtime
RUN apt-get update -qq && apt-get install -y --no-install-recommends \
    mariadb-server pwgen \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /var/lib/mysql /var/run/mysqld /var/log/mysql \
    && chown -R mysql:mysql /var/lib/mysql /var/run/mysqld /var/log/mysql \
    && find /etc/mysql/ -type f -exec chmod 644 {} + \
    && find /etc/mysql/ -type d -exec chmod 755 {} +

COPY --chown=mysql:mysql tools/entrypoint.sh /usr/local/bin/
COPY conf/my.cnf /etc/mysql/conf.d/my.cnf

USER mysql
EXPOSE 3306
STOPSIGNAL SIGTERM
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD mariadb-admin ping -u root --password="$$(cat /run/secrets/db_root_password)" || exit 1

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["mysqld"]
