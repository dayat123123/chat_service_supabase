FROM golang:1.27.3-alpine3.24@sha256:d200d2dd76b03a99b52651fd1325aff7dcd35422c35c01bac56571b0507f3deb AS build
WORKDIR /src
# go.su[m] copies go.sum when it exists without failing when it does not.
COPY go.mod go.su[m] ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-s -w" -o /out/media ./cmd/media

# Not distroless: CS videos are probed, remuxed (metadata removed), and thumbnailed with ffprobe/ffmpeg
# (LGPL/GPL) from the pinned Alpine package.
FROM alpine:3.22.7@sha256:2e0b81d60597f449baa56dc25d355367869d2dca4cd57e866f1e2b52af3eb55f
RUN rm -r /media \
 && apk add --no-cache ffmpeg=6.1.2-r2 \
 && addgroup -S -g 65532 nonroot \
 && adduser -S -D -H -u 65532 -G nonroot -h /tmp nonroot
COPY --from=build /out/media /media
USER 65532:65532
# Listens on 8080 (upload API) and 9100 (ops). No EXPOSE on purpose: see docker/pgbouncer/Dockerfile.
ENTRYPOINT ["/media"]
