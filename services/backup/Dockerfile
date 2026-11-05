FROM golang:1.27.3-alpine3.24@sha256:d200d2dd76b03a99b52651fd1325aff7dcd35422c35c01bac56571b0507f3deb AS build
WORKDIR /src
# go.su[m] copies go.sum when it exists without failing when it does not.
COPY go.mod go.su[m] ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-s -w" -o /out/backup ./cmd/backup

# Not distroless: needs pg_receivewal, pg_basebackup, pg_verifybackup, postgres/pg_ctl 17 (PostgreSQL License)
# and restic (BSD-2-Clause) from pinned Alpine packages.
FROM alpine:3.22.7@sha256:2e0b81d60597f449baa56dc25d355367869d2dca4cd57e866f1e2b52af3eb55f
RUN apk add --no-cache postgresql17=17.11-r0 postgresql17-client=17.11-r0 restic=0.18.0-r7 \
 && addgroup -S -g 10001 backup \
 && adduser -S -D -H -u 10001 -G backup -h /var/lib/olt-backup backup \
 && install -d -o 10001 -g 10001 -m 0700 /var/lib/olt-backup
COPY --from=build /out/backup /usr/local/bin/backup
USER 10001:10001
# Listens on 8080. No EXPOSE on purpose: see docker/pgbouncer/Dockerfile.
ENTRYPOINT ["/usr/local/bin/backup"]
