FROM golang:1.21 AS builder
ARG TARGETARCH
ARG TARGETOS
WORKDIR /workspace

ADD go.mod .
ADD go.sum .
RUN go mod download

ADD . .
RUN CGO_ENABLED=0 GOOS=${TARGETOS} GOARCH=${TARGETARCH} go build -ldflags="-w -s" -o config-reloader-sidecar .

# Runtime
FROM gcr.io/distroless/static-debian11:latest

COPY --from=builder /workspace/config-reloader-sidecar .

CMD ["/config-reloader-sidecar"]
