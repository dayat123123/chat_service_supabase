FROM golang:1.27.3-alpine3.24@sha256:d200d2dd76b03a99b52651fd1325aff7dcd35422c35c01bac56571b0507f3deb AS build
WORKDIR /src
# go.su[m] copies go.sum when it exists without failing when it does not.
COPY go.mod go.su[m] ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-s -w" -o /out/healer ./cmd/healer \
 && mkdir -p /out/state

FROM gcr.io/distroless/static-debian12:nonroot@sha256:afa5c872c891853ca7fcf1f12c3edb23f7eeef36189728842dd51042ff57f7ab
COPY --from=build /out/healer /healer
# A fresh state volume inherits the nonroot owner from this directory.
COPY --from=build --chown=65532:65532 /out/state /var/lib/olt-healer
USER nonroot:nonroot
# No ports and no network (network_mode: none): it only talks to the Docker Engine API over the unix socket.
ENTRYPOINT ["/healer"]
