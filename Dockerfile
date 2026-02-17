# --- Stage 1: Build Stage (TDLib + Bot) ---
FROM golang:1.25-bookworm AS builder

# Install build dependencies for TDLib
RUN apt-get update && apt-get install -y \
    build-essential cmake gperf libssl-dev zlib1g-dev git \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src

# 1. Clone and Build LATEST TDLib
# (This step takes 20-40 mins - it is the "engine" for gotdbot)
RUN git clone https://github.com/tdlib/td.git && \
    cd td && \
    mkdir build && \
    cd build && \
    cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX:PATH=/usr/local .. && \
    cmake --build . --target install -j$(nproc)

WORKDIR /app

# 2. Build your Go Bot
COPY go.mod go.sum ./
RUN go mod download

COPY . .

# Build the bot binary (CGO_ENABLED=0 is fine for gotdbot as it uses purego)
RUN CGO_ENABLED=0 GOOS=linux go build -o bot main.go

# --- Stage 2: Final Runtime Image ---
FROM debian:bookworm-slim

WORKDIR /app

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    ca-certificates \
    zlib1g \
    libstdc++6 \
    libssl3 \
    && rm -rf /var/lib/apt/lists/*

# Copy the bot binary
COPY --from=builder /app/bot .

# Copy the compiled TDLib shared objects
COPY --from=builder /usr/local/lib/libtdjson.so* /usr/local/lib/

# CRITICAL: Fix for "libtdjson.so.1.8.60: No such file"
# We create a symlink so the bot finds the library under the specific name it wants
RUN ln -s /usr/local/lib/libtdjson.so /usr/local/lib/libtdjson.so.1.8.60 && \
    ldconfig

# Ensure the system looks in /usr/local/lib for the library
ENV LD_LIBRARY_PATH=/usr/local/lib
ENV TZ=UTC

CMD ["./bot"]
