# Use Ubuntu Noble (24.04 LTS) for a lower CVE surface area than Debian Bookworm
FROM ubuntu:24.04

LABEL maintainer="André Dreyer"

# Avoid prompts from apt
ENV DEBIAN_FRONTEND=noninteractive

# Install base dependencies and Node.js 22 via NodeSource in a single layer
# apt-get upgrade ensures any base image CVEs are patched at build time.
# npm package CVEs (tar, minimatch, glob) are addressed by the npm install -g npm@latest step below.
RUN apt-get update && apt-get upgrade -y && apt-get install -y \
    # Essential build tools
    build-essential \
    # Networking and download tools
    curl \
    wget \
    ca-certificates \
    gnupg \
    # Version control
    git \
    # Useful utilities
    unzip \
    less \
    man-db \
    sudo \
    # Required for AWS CLI v2
    groff \
    && rm -rf /var/lib/apt/lists/* \
    # Install Node.js 22 via NodeSource
    && curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# Update npm to the latest version
RUN npm install -g npm@latest

# yq — YAML/JSON/TOML processor (useful for AI-assisted workflows and scripting)
# Not in Debian repos; install from GitHub releases (mikefarah/yq)
RUN curl -fsSL "https://github.com/mikefarah/yq/releases/latest/download/yq_linux_$(dpkg --print-architecture)" \
    -o /usr/local/bin/yq \
    && chmod +x /usr/local/bin/yq

# Install AWS CLI v2
# AWS CLI v2 is distributed as a pre-built binary package
RUN ARCH=$(dpkg --print-architecture) \
    && if [ "$ARCH" = "amd64" ]; then AWS_URL="https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip"; \
       elif [ "$ARCH" = "arm64" ]; then AWS_URL="https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip"; \
       else echo "Unsupported arch: $ARCH" && exit 1; fi \
    && curl -fsSL "$AWS_URL" -o "awscliv2.zip" \
    && unzip awscliv2.zip \
    && ./aws/install \
    && rm -rf awscliv2.zip aws

# GitHub CLI (gh) — PR/issue management and AI-assisted workflows
RUN mkdir -p -m 755 /etc/apt/keyrings \
    && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
    && chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
    && mkdir -p -m 755 /etc/apt/sources.list.d \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    > /etc/apt/sources.list.d/github-cli.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends gh \
    && rm -rf /var/lib/apt/lists/*

# Verify installations
RUN echo "Verifying installations..." \
    && node --version \
    && npm --version \
    && aws --version \
    && gh --version
    
# Create a non-root user for development (following devcontainer best practices)
ARG USERNAME=dev
ARG USER_UID=1000
ARG USER_GID=$USER_UID

RUN userdel -r node 2>/dev/null || true \
    && groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME -s /bin/bash \
    && echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME

# Switch to non-root user
USER $USERNAME
WORKDIR /home/$USERNAME

# Configure git user
RUN git config --global user.name "André Dreyer" && \
    git config --global user.email "github@andredreyer.com"

# Install Claude Code CLI using native installer (recommended method)
# Note: npm installation is deprecated. Native installer auto-updates in background.
RUN curl -fsSL https://claude.ai/install.sh | bash

# Add ~/.local/bin to PATH so the `claude` binary is accessible
ENV PATH="/home/$USERNAME/.local/bin:$PATH"

# Default command
CMD ["/bin/bash"]