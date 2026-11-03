FROM golang:1.27.3-bookworm@sha256:d9b6a1beb9474adc2a1ce842573639b44b2a0dd49b6669f51d3821baf9ec37c9 AS build
ARG ORT_VERSION=1.31.0
ARG ORT_SHA256=cc5c72baf5ae5c8238a6841f0897227be2d02826b9cf98eaf02fdefaeeb03a57
ARG MODEL_URL=https://huggingface.co/taufiqdp/mobilenetv4_conv_small.e2400_r224_in1k_nsfw_classifier/resolve/504317ad62086f357c9c5f70cf983726ff47efdb/mobilenetv4_conv_small.e2400_r224_in1k_nsfw_classifier.onnx
ARG MODEL_SHA256=46995c000cb285d0c0a0e5b58cc618012ed2e649d326d4fddae910951848fc40
RUN curl -fsSL -o /tmp/ort.tgz "https://github.com/microsoft/onnxruntime/releases/download/v${ORT_VERSION}/onnxruntime-linux-x64-${ORT_VERSION}.tgz" \
 && echo "${ORT_SHA256}  /tmp/ort.tgz" | sha256sum -c - \
 && tar -xzf /tmp/ort.tgz -C /tmp \
 && mkdir -p /out/onnxruntime /out/model \
 && cp "/tmp/onnxruntime-linux-x64-${ORT_VERSION}/lib/libonnxruntime.so.${ORT_VERSION}" /out/onnxruntime/libonnxruntime.so \
 && cp "/tmp/onnxruntime-linux-x64-${ORT_VERSION}/LICENSE" "/tmp/onnxruntime-linux-x64-${ORT_VERSION}/ThirdPartyNotices.txt" /out/onnxruntime/ \
 && curl -fsSL -o /out/model/model.onnx "${MODEL_URL}" \
 && echo "${MODEL_SHA256}  /out/model/model.onnx" | sha256sum -c -
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN cp model/manifest.json /out/model/manifest.json \
 && CGO_ENABLED=1 GOOS=linux GOARCH=amd64 go build -trimpath -ldflags="-s -w" -o /out/classifier ./cmd/classifier

# Butuh glibc + libstdc++ untuk ONNX Runtime; di-pin ke digest.
FROM gcr.io/distroless/cc-debian12:nonroot@sha256:9dac0a79194e45a7da0158a9c6da57b217585af0786db3845d1f0ec1a0dd182f
COPY --from=build /out/onnxruntime /usr/lib/onnxruntime
COPY --from=build /out/model /model
COPY --from=build /out/classifier /classifier
USER nonroot:nonroot
ENTRYPOINT ["/classifier"]
