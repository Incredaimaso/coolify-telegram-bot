FROM golang:1.25 AS builder

# We need build-essential/g++ to link against TDLib during the build phase
RUN apt-get update && apt-get install -y build-essential

WORKDIR /app

COPY go.mod go.sum ./
RUN go mod download

COPY . .

RUN go generate

# CHANGE: Set CGO_ENABLED=1
RUN CGO_ENABLED=1 GOOS=linux go build -o bot main.go

FROM debian:bookworm-slim

WORKDIR /app

# libstdc++6 is required for TDLib (which is C++)
RUN apt-get update && apt-get install -y \
    ca-certificates \
    zlib1g \
    libstdc++6 \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /app/bot .
COPY --from=builder /app/libtdjson.so.* ./

# Tell the OS to look in the current directory for shared libraries
ENV LD_LIBRARY_PATH=/app

CMD ["./bot"]
