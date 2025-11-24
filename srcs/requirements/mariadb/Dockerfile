# Stage 1: Builder (init datadir, envsubst conf; ephemeral deps pruned)
FROM alpine:3.21 AS builder

# System users pre-apk (your pattern; -S idempotent, avoids mariadb hook collision)
RUN addgroup -S mysql && \
    adduser -S mysql -G mysql

RUN apk add --no-cache \
        mariadb \
        mariadb-client \
        gettext  # Ephemeral: envsubst for templating (your pattern)

# Dirs + chown (post-users; pre-init; include /etc/my.cnf.d for COPY/envsubst)
RUN mkdir -p /var/lib/mysql /var/run/mysqld /var/log/mysql /etc/my.cnf.d && \
    chown -R mysql:mysql /var/lib/mysql /var/run/mysqld /var/log/mysql /etc/my.cnf.d

# Init datadir (your explicit basedir/datadir; hooks safe post-users)
RUN mariadb-install-db --user=mysql --basedir=/usr --datadir=/var/lib/mysql

# Template conf (your COPY as .template to avoid overwrite; envsubst to final my.cnf; prune intermediate)
COPY conf/my.cnf /etc/my.cnf.d/my.cnf.template
RUN envsubst '${MYSQL_PORT}' < /etc/my.cnf.d/my.cnf.template > /etc/my.cnf.d/my.cnf && \
    rm /etc/my.cnf.d/my.cnf.template  # Prune template only (output preserved; your rm pattern fixed)

# Entrypoint (your chown for USER mysql)
COPY tools/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh && \
    chown mysql:mysql /usr/local/bin/entrypoint.sh

# Stage 2: Runtime (copy artifacts; exec mariadbd non-root; your symmetric users)
FROM alpine:3.21 AS runtime

# System users pre-apk (your pattern; -S idempotent, avoids collision)
RUN addgroup -S mysql && \
    adduser -S mysql -G mysql

RUN apk add --no-cache \
        mariadb \
        mariadb-client && \
    mkdir -p /var/lib/mysql /var/run/mysqld /var/log/mysql /etc/my.cnf.d && \
    chown -R mysql:mysql /var/lib/mysql /var/run/mysqld /var/log/mysql /etc/my.cnf.d

# Copy from builder (your pre-init datadir + conf; atomic—source exists post-mkdir/envsubst)
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
