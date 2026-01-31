FROM node:20-slim

# Install dependencies for native modules and OpenDoc CLI
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    git \
    tar \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install ripgrep - required for glob/grep tools
# Using aarch64 (ARM64) version for ARM-based Docker builds
ARG RIPGREP_VERSION=15.1.0
ARG RIPGREP_ARCH=aarch64-unknown-linux-gnu
RUN curl -fsSL "https://github.com/BurntSushi/ripgrep/releases/download/${RIPGREP_VERSION}/ripgrep-${RIPGREP_VERSION}-${RIPGREP_ARCH}.tar.gz" -o /tmp/ripgrep.tar.gz \
    && tar -xzf /tmp/ripgrep.tar.gz -C /tmp --no-same-owner \
    && mv /tmp/ripgrep-${RIPGREP_VERSION}-${RIPGREP_ARCH}/rg /usr/local/bin/rg \
    && chmod +x /usr/local/bin/rg \
    && rm -rf /tmp/ripgrep*

# Download opendoc from GitHub releases
# Using arm64 version for ARM-based Docker builds
ARG OPENDOC_VERSION=v1.0.5
ARG OPENDOC_ARCH=linux-arm64
RUN curl -fsSL "https://github.com/Gatos90/opendoc/releases/download/${OPENDOC_VERSION}/opendoc-${OPENDOC_ARCH}.tar.gz" -o /tmp/opendoc.tar.gz \
    && tar -xzf /tmp/opendoc.tar.gz -C /tmp \
    && mv /tmp/opendoc /usr/local/bin/opendoc \
    && chmod +x /usr/local/bin/opendoc \
    && rm -rf /tmp/opendoc*

# Create data directory for session persistence
RUN mkdir -p /data/opendoc

# Create working directory for docs
WORKDIR /docs

# Environment
ENV OPENDOC_DATA_DIR=/data/opendoc
ENV OPENDOC_HOST=0.0.0.0
ENV OPENDOC_PORT=4096
ENV NODE_ENV=production

# Expose API port
EXPOSE 4096

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:4096/health || exit 1

# Copy entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Start via entrypoint
ENTRYPOINT ["/entrypoint.sh"]
