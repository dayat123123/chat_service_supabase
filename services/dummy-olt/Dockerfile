FROM golang:1.24.5-alpine3.22@sha256:daae04ebad0c21149979cd8e9db38f565ecefd8547cf4a591240dc1972cf1399 AS build
WORKDIR /src
# go.su[m]: ikut disalin jika sudah ada, tanpa gagal jika belum.
COPY go.mod go.su[m] ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-s -w" -o /out/dummy-olt ./cmd/dummy-olt

# Di-pin ke digest: tag "nonroot" bisa bergeser.
FROM gcr.io/distroless/static-debian12:nonroot@sha256:afa5c872c891853ca7fcf1f12c3edb23f7eeef36189728842dd51042ff57f7ab
COPY --from=build /out/dummy-olt /dummy-olt
USER nonroot:nonroot
EXPOSE 8090
ENTRYPOINT ["/dummy-olt"]
CMD ["serve"]
