FROM ubuntu:24.04

# TODO: make this multi-arch once the ARM version is confirmed working.
# To update, change these three variables and rebuild.
ENV YB_CLIENT_VERSION=2025.2.1.0
ENV YB_CLIENT_BUILD=b141
ENV YB_CLIENT_ARCH=aarch64

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        git \
        ca-certificates \
        curl \
        wget && \
    rm -rf /var/lib/apt/lists/*

RUN wget -q "https://downloads.yugabyte.com/releases/${YB_CLIENT_VERSION}/yugabyte-client-${YB_CLIENT_VERSION}-${YB_CLIENT_BUILD}-linux-${YB_CLIENT_ARCH}.tar.gz" && \
    echo "$(curl -sL "https://downloads.yugabyte.com/releases/${YB_CLIENT_VERSION}/yugabyte-client-${YB_CLIENT_VERSION}-${YB_CLIENT_BUILD}-linux-${YB_CLIENT_ARCH}.tar.gz.sha") *yugabyte-client-${YB_CLIENT_VERSION}-${YB_CLIENT_BUILD}-linux-${YB_CLIENT_ARCH}.tar.gz" | shasum --check && \
    tar xfz "yugabyte-client-${YB_CLIENT_VERSION}-${YB_CLIENT_BUILD}-linux-${YB_CLIENT_ARCH}.tar.gz" -C /opt && \
    /opt/yugabyte-client-${YB_CLIENT_VERSION}/bin/post_install.sh && \
    ln -sf "/opt/yugabyte-client-${YB_CLIENT_VERSION}/bin/ysqlsh" /usr/local/bin/ysqlsh && \
    rm "yugabyte-client-${YB_CLIENT_VERSION}-${YB_CLIENT_BUILD}-linux-${YB_CLIENT_ARCH}.tar.gz"
