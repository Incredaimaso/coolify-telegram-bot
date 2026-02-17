# Stage 1: Build the Go binary
FROM golang:1.25-bookworm AS builder

WORKDIR /app

COPY go.mod go.sum ./
RUN go mod download

COPY . .

# Build the bot
RUN CGO_ENABLED=0 GOOS=linux go build -o bot main.go

# Stage 2: Runtime
FROM debian:bookworm-slim

WORKDIR /app

# Install basic runtimes needed to load C libraries
RUN apt-get update && apt-get install -y \
    ca-certificates \
    zlib1g \
    libstdc++6 \
    && rm -rf /var/lib/apt/lists/*

# Copy the bot binary
COPY --from=builder /app/bot .

# COPY THE PRE-EXISTING LIBRARIES FROM THE REPO
# Note: Adjust 'lib/' if the folder in your repo is named 'tdlib' or 'bin'
COPY --from=builder /app/libtdjson.so* ./
COPY --from=builder /app/lib/libtdjson.so* /usr/local/lib/ || true

# If the file is specifically named libtdjson.so in the repo, 
# we link it to the version the bot is crying for:
RUN ln -s /usr/local/lib/libtdjson.so /usr/local/lib/libtdjson.so.1.8.60 || true
RUN ln -s /app/libtdjson.so /app/libtdjson.so.1.8.60 || true

RUN ldconfig

# Set the path so the bot can find the .so file in the current directory
ENV LD_LIBRARY_PATH=/app:/usr/local/lib

CMD ["./bot"]
