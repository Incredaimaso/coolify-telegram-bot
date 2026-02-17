# --- Stage 1: Build TDLib and the Go Bot ---
FROM golang:1.25-bookworm AS builder

# Install build dependencies for TDLib
RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    gperf \
    libssl-dev \
    zlib1g-dev \
    git \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src

# 1. Clone and Build TDLib v1.8.60
# We use -j$(nproc) to use all available CPU cores for faster building
RUN git clone https://github.com/tdlib/td.git && \
    cd td && \
    git checkout v1.8.60 && \
    mkdir build && \
    cd build && \
    cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX:PATH=/usr/local .. && \
    cmake --build . --target install -j$(nproc)

WORKDIR /app

# 2. Build the Go application
COPY go.mod go.sum ./
RUN go mod download

COPY . .

# Run any code generation if required by your bot
RUN go generate ./...

# Enable CGO so it can link to the TDLib we just built
RUN CGO_ENABLED=1 GOOS=linux go build -o bot main.go

# --- Stage 2: Final Runtime Image ---
FROM debian:bookworm-slim

WORKDIR /app

# Install runtime dependencies (SSL and C++ standard library)
RUN apt-get update && apt-get install -y \
    ca-certificates \
    zlib1g \
    libstdc++6 \
    libssl3 \
    && rm -rf /var/lib/apt/lists/*

# Copy the compiled bot binary from builder
COPY --from=builder /app/bot .

# Copy the compiled TDLib shared objects from the builder's system path
COPY --from=builder /usr/local/lib/libtdjson.so* /usr/local/lib/

# Refresh the shared library cache so the OS finds libtdjson
RUN ldconfig

# Set environment variables
ENV LD_LIBRARY_PATH=/usr/local/lib
ENV TZ=UTC

CMD ["./bot"]
