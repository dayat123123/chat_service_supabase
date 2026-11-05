# PgBouncer (ISC License), built from a pinned Alpine package and run as a non-root user.
FROM alpine:3.22.7@sha256:2e0b81d60597f449baa56dc25d355367869d2dca4cd57e866f1e2b52af3eb55f

RUN apk add --no-cache pgbouncer=1.24.0-r0 \
 && addgroup -S -g 10001 pgbouncer \
 && adduser -S -D -H -u 10001 -G pgbouncer pgbouncer

COPY entrypoint.sh /usr/local/bin/pgbouncer-entrypoint.sh

USER 10001:10001
# Listens on 6432. No EXPOSE on purpose: BuildKit writes a pointer address into the EXPOSE
# history entry, so the image ID changes on every build and the container is recreated on
# every `up --build`.
ENTRYPOINT ["/bin/sh", "/usr/local/bin/pgbouncer-entrypoint.sh"]
