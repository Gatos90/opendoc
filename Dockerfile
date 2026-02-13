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

# Install GitHub CLI (gh) — for creating PRs via AI
ARG GH_VERSION=2.86.0
RUN case "${TARGETARCH}" in \
      arm64) GH_ARCH="linux_arm64" ;; \
      amd64) GH_ARCH="linux_amd64" ;; \
      *) echo "Unsupported architecture: ${TARGETARCH}" && exit 1 ;; \
    esac \
    && curl -fsSL "https://github.com/cli/cli/releases/download/v${GH_VERSION}/gh_${GH_VERSION}_${GH_ARCH}.tar.gz" -o /tmp/gh.tar.gz \
    && tar -xzf /tmp/gh.tar.gz -C /tmp --no-same-owner \
    && mv /tmp/gh_${GH_VERSION}_${GH_ARCH}/bin/gh /usr/local/bin/gh \
    && chmod +x /usr/local/bin/gh \
    && rm -rf /tmp/gh*

# Install GitLab CLI (glab) — for creating MRs via AI
ARG GLAB_VERSION=1.84.0
RUN case "${TARGETARCH}" in \
      arm64) GLAB_ARCH="linux_arm64" ;; \
      amd64) GLAB_ARCH="linux_amd64" ;; \
      *) echo "Unsupported architecture: ${TARGETARCH}" && exit 1 ;; \
    esac \
    && curl -fsSL "https://gitlab.com/gitlab-org/cli/-/releases/v${GLAB_VERSION}/downloads/glab_${GLAB_VERSION}_${GLAB_ARCH}.tar.gz" -o /tmp/glab.tar.gz \
    && tar -xzf /tmp/glab.tar.gz -C /tmp --no-same-owner \
    && mv /tmp/bin/glab /usr/local/bin/glab \
    && chmod +x /usr/local/bin/glab \
    && rm -rf /tmp/glab* /tmp/bin

# Copy pre-built opendoc binary (built locally via bun run build)
# Auto-detect architecture via TARGETARCH
ARG OPENDOC_VERSION=v1.0.9
COPY packages/opendoc/dist/opendoc-linux-arm64/bin/opendoc /tmp/opendoc-arm64
COPY packages/opendoc/dist/opendoc-linux-x64/bin/opendoc /tmp/opendoc-amd64
RUN case "${TARGETARCH}" in \
      arm64) mv /tmp/opendoc-arm64 /usr/local/bin/opendoc ;; \
      amd64) mv /tmp/opendoc-amd64 /usr/local/bin/opendoc ;; \
      *) echo "Unsupported architecture: ${TARGETARCH}" && exit 1 ;; \
    esac \
    && chmod +x /usr/local/bin/opendoc \
    && rm -f /tmp/opendoc-*

# Optional: Install Chromium system deps + browser CLI for AI web browsing
# --build-arg WITH_BROWSER=true    → agent-browser   (gatso/opendoc:<ver>-browser)
# --build-arg WITH_PLAYWRIGHT=true → playwright-cli   (gatso/opendoc:<ver>-playwright)
ARG WITH_BROWSER=false
ARG WITH_PLAYWRIGHT=false
RUN if [ "$WITH_BROWSER" = "true" ] || [ "$WITH_PLAYWRIGHT" = "true" ]; then \
    apt-get update && apt-get install -y --no-install-recommends \
      libnss3 libnspr4 libatk1.0-0 libatk-bridge2.0-0 libcups2 \
      libdrm2 libxkbcommon0 libxcomposite1 libxdamage1 libxfixes3 \
      libxrandr2 libgbm1 libpango-1.0-0 libcairo2 libasound2 \
      libx11-xcb1 libxcb1 libxext6 libx11-6 fonts-liberation \
    && rm -rf /var/lib/apt/lists/*; \
  fi

RUN if [ "$WITH_BROWSER" = "true" ]; then \
    npm install -g agent-browser@latest \
    && agent-browser install \
    && rm -rf /root/.npm /tmp/*; \
  fi

# Create data directory for session persistence
RUN mkdir -p /data/opendoc

# Create working directory for docs (must be before playwright-cli install so config lands here)
WORKDIR /docs

RUN if [ "$WITH_PLAYWRIGHT" = "true" ]; then \
    npm install -g @playwright/cli@latest \
    && playwright-cli install \
    && rm -rf /root/.npm /tmp/*; \
  fi

# Environment
ENV OPENDOC_DATA_DIR=/data/opendoc
ENV OPENDOC_HOST=0.0.0.0
ENV OPENDOC_PORT=4096
ENV NODE_ENV=production

# Expose API port
EXPOSE 4096

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:4096/global/health || exit 1

# Copy entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Start via entrypoint
ENTRYPOINT ["/entrypoint.sh"]
