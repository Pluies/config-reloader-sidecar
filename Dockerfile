FROM golang:1.23 AS builder
ARG TARGETARCH
ARG TARGETOS

WORKDIR /workspace

ADD go.mod .
ADD go.sum .
RUN go mod download

ADD . .
RUN CGO_ENABLED=0 GOOS=${TARGETOS} GOARCH=${TARGETARCH} go build -ldflags="-w -s" -o config-reloader-sidecar .

# Runtime

FROM gcr.io/distroless/static-debian12:latest

COPY --from=builder /workspace/config-reloader-sidecar .

CMD ["/config-reloader-sidecar"]
