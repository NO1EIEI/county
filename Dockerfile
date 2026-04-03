# Stage 1: Build the native Zig binary
FROM ubuntu:24.04 AS builder

# Install build dependencies
RUN apt-get update && apt-get install -y \
    curl \
    xz-utils \
    && rm -rf /var/lib/apt/lists/*

# Download and install Zig 0.15.2
RUN curl -fL https://ziglang.org/download/0.15.2/zig-linux-x86_64-0.15.2.tar.xz -o zig.tar.xz && \
    mkdir -p /opt/zig && \
    tar -xf zig.tar.xz -C /opt/zig --strip-components=1 && \
    rm zig.tar.xz
ENV PATH="/opt/zig:${PATH}"

WORKDIR /app

# Copy project files
COPY . .

# Build for release. Optimize for small size to save RAM during build on free tier.
RUN zig build -Doptimize=ReleaseSmall --summary none

# Stage 2: Create a minimal runtime image
FROM ubuntu:24.04

WORKDIR /app

# Copy only the compiled executable
# The name of the binary is 'zig' as defined in build.zig (.name = "zig")
COPY --from=builder /app/zig-out/bin/zig /app/server

# Expose the default port (3000)
# Render will use the PORT environment variable, but we expose 3000 as a default.
EXPOSE 3000

# Start up the native web server!
CMD ["/app/server"]
