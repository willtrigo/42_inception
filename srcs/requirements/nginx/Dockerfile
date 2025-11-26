# Stage 1: Builder for TLS certs
FROM alpine:3.21 AS cert-builder

RUN apk add --no-cache openssl

ARG TLS_CN
ARG TLS_DAYS=365

RUN mkdir -p /etc/ssl/private /etc/ssl/certs \
    && openssl req -x509 -nodes -days ${TLS_DAYS} -newkey rsa:2048 \
       -keyout /etc/ssl/private/nginx.key \
       -out /etc/ssl/certs/nginx.crt \
       -subj "/C=FR/ST=42/L=School/O=42/CN=${TLS_CN}" \
    && chmod 644 /etc/ssl/certs/nginx.crt \
    && chmod 644 /etc/ssl/private/nginx.key  # More permissive for testing

# Stage 2: Runtime
FROM alpine:3.21 AS runtime

RUN apk add --no-cache nginx curl \
    && mkdir -p /var/log/nginx /var/cache/nginx /run/nginx /var/www/html

# Copy certs
COPY --from=cert-builder /etc/ssl/ /etc/ssl/

# Copy nginx configuration
COPY conf/nginx.conf /etc/nginx/nginx.conf

EXPOSE 443

STOPSIGNAL SIGTERM

HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f https://localhost/ --insecure || exit 1

CMD ["nginx", "-g", "daemon off;"]
