FROM golang:1.21 AS builder

WORKDIR /workspace

ADD go.mod .
ADD go.sum .
RUN go mod download

ADD . .
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-w -s" -o config-reloader-sidecar .

# UPX compression
FROM devopsworks/golang-upx:1.23.2 AS upx

COPY --from=builder /workspace/config-reloader-sidecar /

RUN upx --best --lzma /config-reloader-sidecar

# Runtime

FROM gcr.io/distroless/static-debian11:latest

COPY --from=upx /config-reloader-sidecar .

CMD ["/config-reloader-sidecar"]
