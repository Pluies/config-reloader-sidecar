FROM golang:1.26 AS builder

WORKDIR /workspace

ADD go.mod .
ADD go.sum .
RUN go mod download

ADD . .
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-w -s" -o config-reloader-sidecar .

RUN apt update \
 && apt install upx \
 && upx --best --lzma config-reloader-sidecar

FROM gcr.io/distroless/static-debian13:latest

COPY --from=builder /workspace/config-reloader-sidecar .

CMD ["/config-reloader-sidecar"]
