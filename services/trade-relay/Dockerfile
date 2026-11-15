FROM golang:1.27.3-alpine3.24@sha256:d200d2dd76b03a99b52651fd1325aff7dcd35422c35c01bac56571b0507f3deb AS build
RUN apk add --no-cache build-base pkgconf zeromq-dev
WORKDIR /src
COPY go.mod go.su[m] ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=1 GOOS=linux go build -trimpath -ldflags="-s -w" -o /out/trade-relay ./cmd/trade-relay
RUN CGO_ENABLED=1 GOOS=linux go build -trimpath -ldflags="-s -w" -o /out/dummy-iproxy ./cmd/dummy-iproxy

FROM alpine:3.24@sha256:f59abe656b692d901e184be3445e084786602108599d2a51d229c0f5a48c71bf
RUN apk add --no-cache zeromq ca-certificates && adduser -D -H -u 65532 nonroot
COPY --from=build /out/trade-relay /trade-relay
COPY --from=build /out/dummy-iproxy /dummy-iproxy
USER 65532:65532
ENTRYPOINT ["/trade-relay"]
