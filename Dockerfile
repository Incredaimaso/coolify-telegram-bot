# --- Stage 1: Build TDLib and the Go Bot ---
FROM golang:1.25-bookworm AS builder

RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    gperf \
    libssl-dev \
    zlib1g-dev \
    git \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src

# 1. Clone and Build TDLib
# Changed: We fetch all tags and checkout the 1.8.0 branch which is the stable 1.8 base
RUN git clone https://github.com/tdlib/td.git && \
    cd td && \
    git checkout v1.8.0 && \
    mkdir build && \
    cd build && \
    cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX:PATH=/usr/local .. && \
    cmake --build . --target install -j$(nproc)

WORKDIR /app

# 2. Build the Go application
COPY go.mod go.sum ./
RUN go mod download

COPY . .

RUN go generate ./...

# Enable CGO so it can link to the TDLib we just built
RUN CGO_ENABLED=1 GOOS=linux go build -o bot main.go

# --- Stage 2: Final Runtime Image ---
FROM debian:bookworm-slim

WORKDIR /app

RUN apt-get update && apt-get install -y \
    ca-certificates \
    zlib1g \
    libstdc++6 \
    libssl3 \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /app/bot .
COPY --from=builder /usr/local/lib/libtdjson.so* /usr/local/lib/

RUN ldconfig

ENV LD_LIBRARY_PATH=/usr/local/lib
ENV TZ=UTC

CMD ["./bot"]
