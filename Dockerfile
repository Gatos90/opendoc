FROM node:20-slim

# Install dependencies for native modules and OpenDoc CLI
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    git \
    tar \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install ripgrep - required for glob/grep tools
# Auto-detect architecture via TARGETARCH (set by docker buildx)
ARG TARGETARCH
ARG RIPGREP_VERSION=15.1.0
RUN case "${TARGETARCH}" in \
      arm64) RIPGREP_ARCH="aarch64-unknown-linux-gnu" ;; \
      amd64) RIPGREP_ARCH="x86_64-unknown-linux-musl" ;; \
      *) echo "Unsupported architecture: ${TARGETARCH}" && exit 1 ;; \
    esac \
    && curl -fsSL "https://github.com/BurntSushi/ripgrep/releases/download/${RIPGREP_VERSION}/ripgrep-${RIPGREP_VERSION}-${RIPGREP_ARCH}.tar.gz" -o /tmp/ripgrep.tar.gz \
    && tar -xzf /tmp/ripgrep.tar.gz -C /tmp --no-same-owner \
    && mv /tmp/ripgrep-${RIPGREP_VERSION}-${RIPGREP_ARCH}/rg /usr/local/bin/rg \
    && chmod +x /usr/local/bin/rg \
    && rm -rf /tmp/ripgrep*

# Download opendoc from GitHub releases
# Auto-detect architecture via TARGETARCH
ARG OPENDOC_VERSION=v1.0.6
RUN case "${TARGETARCH}" in \
      arm64) OPENDOC_ARCH="linux-arm64" ;; \
      amd64) OPENDOC_ARCH="linux-x64" ;; \
      *) echo "Unsupported architecture: ${TARGETARCH}" && exit 1 ;; \
    esac \
    && curl -fsSL "https://github.com/Gatos90/opendoc/releases/download/${OPENDOC_VERSION}/opendoc-${OPENDOC_ARCH}.tar.gz" -o /tmp/opendoc.tar.gz \
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
