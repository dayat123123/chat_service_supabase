FROM golang:1.27.3-alpine3.24@sha256:d200d2dd76b03a99b52651fd1325aff7dcd35422c35c01bac56571b0507f3deb AS build
WORKDIR /src
# go.su[m] copies go.sum when it exists without failing when it does not.
COPY go.mod go.su[m] ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-s -w" -o /out/media ./cmd/media

FROM gcr.io/distroless/static-debian12:nonroot@sha256:afa5c872c891853ca7fcf1f12c3edb23f7eeef36189728842dd51042ff57f7ab
COPY --from=build /out/media /media
USER nonroot:nonroot
# Listens on 8080 (upload API) and 9100 (ops). No EXPOSE on purpose: see docker/pgbouncer/Dockerfile.
ENTRYPOINT ["/media"]
