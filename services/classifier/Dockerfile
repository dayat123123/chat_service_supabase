FROM golang:1.27.3-bookworm@sha256:d9b6a1beb9474adc2a1ce842573639b44b2a0dd49b6669f51d3821baf9ec37c9 AS build
ARG ORT_VERSION=1.31.0
ARG ORT_NUPKG_SHA256=7e35fdb4f5adb62f01e60798e2e5ed05108f5fbbe1cca03fbcc37903cf7c5e3b
ARG ORT_LIB_SHA256=469849977cb60744ea160927e1a3a0643fd4c55c0aff743251c6d293402e334e
ARG MODEL_URL=https://huggingface.co/taufiqdp/mobilenetv4_conv_small.e2400_r224_in1k_nsfw_classifier/resolve/504317ad62086f357c9c5f70cf983726ff47efdb/mobilenetv4_conv_small.e2400_r224_in1k_nsfw_classifier.onnx
ARG MODEL_SHA256=46995c000cb285d0c0a0e5b58cc618012ed2e649d326d4fddae910951848fc40
# microsoft/onnxruntime GitHub releases were removed in Nov 2026; the NuGet package ships the identical library.
RUN apt-get update -qq \
 && apt-get install -y -qq --no-install-recommends unzip \
 && rm -rf /var/lib/apt/lists/* \
 && curl -fsSL -o /tmp/ort.nupkg "https://api.nuget.org/v3-flatcontainer/microsoft.ml.onnxruntime/${ORT_VERSION}/microsoft.ml.onnxruntime.${ORT_VERSION}.nupkg" \
 && echo "${ORT_NUPKG_SHA256}  /tmp/ort.nupkg" | sha256sum -c - \
 && mkdir -p /out/onnxruntime /out/model \
 && unzip -q -j /tmp/ort.nupkg runtimes/linux-x64/native/libonnxruntime.so LICENSE ThirdPartyNotices.txt -d /out/onnxruntime \
 && echo "${ORT_LIB_SHA256}  /out/onnxruntime/libonnxruntime.so" | sha256sum -c - \
 && curl -fsSL -o /out/model/model.onnx "${MODEL_URL}" \
 && echo "${MODEL_SHA256}  /out/model/model.onnx" | sha256sum -c -
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN cp model/manifest.json /out/model/manifest.json \
 && CGO_ENABLED=1 GOOS=linux GOARCH=amd64 go build -trimpath -ldflags="-s -w" -o /out/classifier ./cmd/classifier

# ONNX Runtime needs glibc and libstdc++. Runtime is Debian 13 because cc-debian12 still ships libssl3 with a
# HIGH CVE; the build stays on bookworm so the binary links against the older glibc.
FROM gcr.io/distroless/cc-debian13:nonroot@sha256:08476c244888bfb425bae1ae4dd7c17f093e972aab8426883d97f3c6f280f7c1
COPY --from=build /out/onnxruntime /usr/lib/onnxruntime
COPY --from=build /out/model /model
COPY --from=build /out/classifier /classifier
USER nonroot:nonroot
ENTRYPOINT ["/classifier"]
