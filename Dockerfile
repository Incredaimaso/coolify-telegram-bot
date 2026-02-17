# --- Stage 1: Build TDLib and Bot ---
FROM golang:1.25-bookworm AS builder

# Install build-essential and tools for TDLib
RUN apt-get update && apt-get install -y \
    build-essential cmake gperf libssl-dev zlib1g-dev git \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src

# 1. Build TDLib from source
# This ensures the .so file is created from scratch
RUN git clone https://github.com/tdlib/td.git && \
    cd td && \
    mkdir build && \
    cd build && \
    cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX:PATH=/usr/local .. && \
    cmake --build . --target install -j$(nproc)

WORKDIR /app

# 2. Build the Go Bot binary
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o bot main.go

# --- Stage 2: Final Runtime (Contained) ---
FROM debian:bookworm-slim

WORKDIR /app

# Install runtime dependencies (standard for C++ apps)
RUN apt-get update && apt-get install -y \
    ca-certificates zlib1g libstdc++6 libssl3 \
    && rm -rf /var/lib/apt/lists/*

# Copy the bot binary
COPY --from=builder /app/bot .

# 3. Copy libraries directly to /app
# We copy the actual file and create the symlink the bot expects
COPY --from=builder /usr/local/lib/libtdjson.so* ./
RUN ln -s libtdjson.so libtdjson.so.1.8.60

# Tell the bot to look in the current directory (.) for the library
ENV LD_LIBRARY_PATH=.
ENV TZ=UTC

CMD ["./bot"]
