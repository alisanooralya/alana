FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

ARG FLUTTER_VERSION=stable
ARG FLUTTER_HOME=/opt/flutter

# Dependency yang dibutuhkan Flutter + Android toolchain dasar
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get install -y --no-install-recommends \
        curl \
        git \
        unzip \
        xz-utils \
        zip \
        libglu1-mesa \
        openjdk-17-jdk-headless \
        ca-certificates \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Clone Flutter SDK (channel stable)
RUN git clone https://github.com/flutter/flutter.git -b ${FLUTTER_VERSION} ${FLUTTER_HOME} \
    && chown -R vscode:vscode ${FLUTTER_HOME}

ENV PATH="${FLUTTER_HOME}/bin:${FLUTTER_HOME}/bin/cache/dart-sdk/bin:${PATH}"

USER vscode

# Pre-cache & jalankan sekali biar layer image sudah "warm"
RUN flutter config --no-analytics \
    && flutter precache \
    && flutter doctor -v

USER root
