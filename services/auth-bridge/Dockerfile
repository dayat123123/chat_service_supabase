FROM golang:1.24.5-alpine3.22 AS build
WORKDIR /src
# go.su[m]: ikut disalin jika sudah ada, tanpa gagal jika belum.
COPY go.mod go.su[m] ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-s -w" -o /out/auth-bridge ./cmd/auth-bridge

# Di-pin ke digest: tag "nonroot" bisa bergeser.
FROM gcr.io/distroless/static-debian12:nonroot@sha256:afa5c872c891853ca7fcf1f12c3edb23f7eeef36189728842dd51042ff57f7ab
COPY --from=build /out/auth-bridge /auth-bridge
USER nonroot:nonroot
EXPOSE 8080
ENTRYPOINT ["/auth-bridge"]
