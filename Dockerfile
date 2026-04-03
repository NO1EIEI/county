# Stage 1: Build the native Zig binary
FROM docker.io/ziglang/zig:latest AS builder

WORKDIR /app

# Copy project files
COPY . .

# Build for release. Optimize for speed
RUN zig build -Doptimize=ReleaseFast

# Stage 2: Create a minimal runtime image (Alpine or Ubuntu works)
FROM ubuntu:24.04

WORKDIR /app

# Copy only the compiled executable
COPY --from=builder /app/zig-out/bin/zig /app/server

# Expose the default port (3000)
EXPOSE 3000

# Start up the native web server!
CMD ["/app/server"]
