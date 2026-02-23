FROM mcr.microsoft.com/devcontainers/base:ubuntu-22.04

RUN dpkg --add-architecture i386

RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get install -y --no-install-recommends \
    wine64 \
    wine32 \
    xvfb \
    && apt-get clean -y && rm -rf /var/lib/apt/lists/*