FROM debian:bookworm-slim

ARG MOONLIGHT_WEB_VERSION=1.6
ARG TARGETARCH=amd64

ENV MOONLIGHT_WEB_PATH=/moonlight-web

LABEL org.opencontainers.image.source="https://github.com/therapytools/moonlight-web-stream"

RUN apt-get update \
    && apt-get install -y --no-install-recommends curl jq ca-certificates python3 \
    && rm -rf /var/lib/apt/lists/*

# Create / Go to app directory
WORKDIR ${MOONLIGHT_WEB_PATH}

# Download the release binary for the active architecture
RUN case "${TARGETARCH}" in \
        amd64) ARCHIVE="moonlight-web-x86_64-unknown-linux-gnu.tar.gz" ;; \
        *) echo "Unsupported architecture: ${TARGETARCH}" >&2; exit 1 ;; \
    esac \
    && curl -fsSL "https://github.com/MrCreativ3001/moonlight-web-stream/releases/download/v${MOONLIGHT_WEB_VERSION}/${ARCHIVE}" -o /tmp/app.tar.gz \
    && tar -xvzf /tmp/app.tar.gz --strip-components=1 -C ${MOONLIGHT_WEB_PATH}/ \
    && rm /tmp/app.tar.gz

# Create a location with config defaults
RUN mkdir ${MOONLIGHT_WEB_PATH}/defaults
COPY ./default-config.json ${MOONLIGHT_WEB_PATH}/defaults/config.json

# Create a volume with the default config.json and data.json
VOLUME ${MOONLIGHT_WEB_PATH}/server

# Expose the port (adjust if you changed the config)
EXPOSE 8080 40000-40100/udp

# Create an entrypoint
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Run the binary
ENTRYPOINT ["/entrypoint.sh"]