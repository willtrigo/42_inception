# Stage 1: Builder for TLS certs
FROM debian:bookworm-slim AS cert-builder
ARG TLS_CN
ARG TLS_DAYS=365
RUN apt-get update -qq && apt-get install -y --no-install-recommends openssl ca-certificates \
    && mkdir -p /etc/ssl/private /etc/ssl/certs \
    && openssl req -x509 -nodes -days ${TLS_DAYS} -newkey rsa:2048 \
       -keyout /etc/ssl/private/nginx-selfsigned.key \
       -out /etc/ssl/certs/nginx-selfsigned.crt \
       -subj "/C=FR/ST=42/L=School/O=42/CN=${TLS_CN}" \
    && chmod 600 /etc/ssl/private/nginx-selfsigned.key \
    && apt-get purge -y openssl && apt-get autoremove -y && rm -rf /var/lib/apt/lists/*

# Stage 2: Runtime
FROM debian:bookworm-slim AS runtime
RUN apt-get update -qq && apt-get install -y --no-install-recommends \
    nginx openssl ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /var/log/nginx /var/cache/nginx /run/nginx \
    && chown -R 101:101 /var/log/nginx /var/cache/nginx /run/nginx

# Copy certs
COPY --from=cert-builder /etc/ssl/ /etc/ssl/

# Config (no passwords)
COPY conf/nginx.conf /etc/nginx/nginx.conf
# COPY conf/upstream.conf /etc/nginx/conf.d/default.conf

# Non-root user (nginx:nginx)
USER 101:101
EXPOSE 443
STOPSIGNAL SIGTERM
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f https://localhost/ --insecure || exit 1

ENTRYPOINT ["nginx", "-g", "daemon off;"]
