# docker-cli lets chaos tests stop, kill, and disconnect stack containers through docker.sock.
FROM golang:1.27.3-alpine3.24@sha256:d200d2dd76b03a99b52651fd1325aff7dcd35422c35c01bac56571b0507f3deb AS tokengen
WORKDIR /src
COPY load/tokengen/ ./
RUN CGO_ENABLED=0 go build -trimpath -ldflags='-s -w' -o /tokengen .

FROM grafana/k6:2.2.0@sha256:9bd01d6941fca969cb61bb57d2da5ee9b385fe2aa8881df3798c196564d6ace6 AS k6

FROM alpine:3.22.7@sha256:2e0b81d60597f449baa56dc25d355367869d2dca4cd57e866f1e2b52af3eb55f
RUN apk add --no-cache bash coreutils curl jq openssl postgresql17-client docker-cli procps-ng bind-tools util-linux-misc
COPY --from=k6 /usr/bin/k6 /usr/local/bin/k6
COPY --from=tokengen /tokengen /usr/local/bin/tokengen
WORKDIR /olt/tests
ENTRYPOINT ["bash", "/olt/tests/run.sh"]
