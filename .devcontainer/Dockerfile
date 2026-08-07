# Use Ubuntu Noble (24.04 LTS) for a lower CVE surface area than Debian Bookworm.
# Supported until 2029-05-31.
FROM ubuntu:24.04

LABEL org.opencontainers.image.title="dr3dr3 devcontainer template" \
      org.opencontainers.image.source="https://github.com/dr3dr3/template-devcontainer" \
      maintainer="André Dreyer"

# Avoid prompts from apt during build only (ARG scopes it to build time, not the running container)
ARG DEBIAN_FRONTEND=noninteractive

# ---------------------------------------------------------------------------
# Version pins
#
# Everything this image downloads is pinned here so that a build is
# reproducible and bumping a tool is a one-line edit.
#
# To update:
#   NODE_MAJOR      https://nodejs.org/en/about/previous-releases (stay on Active LTS)
#   YQ_VERSION      https://github.com/mikefarah/yq/releases
#                   then recompute both hashes:
#                     curl -fsSL .../yq_linux_amd64 | sha256sum
#                     curl -fsSL .../yq_linux_arm64 | sha256sum
#   AWSCLI_VERSION  https://raw.githubusercontent.com/aws/aws-cli/v2/CHANGELOG.rst
# ---------------------------------------------------------------------------
ARG NODE_MAJOR=24
ARG YQ_VERSION=v4.53.3
ARG YQ_SHA256_AMD64=fa52a4e758c63d38299163fbdd1edfb4c4963247918bf9c1c5d31d84789eded4
ARG YQ_SHA256_ARM64=578648e463a11c1b6db6010cbf41eafed6bee79466fcffa1bb446672cf7945ea
ARG AWSCLI_VERSION=2.36.18

# Non-root user (devcontainer best practice). USER_UID/USER_GID default to 1000
# to line up with the typical Linux/WSL2 host user, so bind-mounted files in
# /workspace are owned correctly.
ARG USERNAME=dev
ARG USER_UID=1000
ARG USER_GID=$USER_UID

# Install base dependencies in a single layer.
# apt-get upgrade ensures any base image CVEs are patched at build time.
RUN apt-get update && apt-get upgrade -y && apt-get install -y --no-install-recommends \
    # Essential build tools
    build-essential \
    # Networking and download tools
    curl \
    ca-certificates \
    gnupg \
    # Version control (openssh-client is required for git over SSH remotes)
    git \
    openssh-client \
    # Useful utilities
    unzip \
    less \
    sudo \
    jq \
    # Required for AWS CLI v2
    groff \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js via the official NodeSource apt repository.
# Using the keyring/sources.list approach avoids piping a remote script directly into bash,
# which removes the supply-chain risk of the setup_XX.x installer method.
RUN mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
       | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_${NODE_MAJOR}.x nodistro main" \
       > /etc/apt/sources.list.d/nodesource.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*

# yq — YAML/JSON/TOML processor (useful for AI-assisted workflows and scripting).
# Not in the Ubuntu repos; installed from GitHub releases (mikefarah/yq) and
# verified against the SHA-256 pinned above before it is made executable.
RUN ARCH="$(dpkg --print-architecture)" \
    && case "$ARCH" in \
         amd64) YQ_SHA256="${YQ_SHA256_AMD64}" ;; \
         arm64) YQ_SHA256="${YQ_SHA256_ARM64}" ;; \
         *) echo "Unsupported arch: $ARCH" >&2; exit 1 ;; \
       esac \
    && curl -fsSL "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_${ARCH}" \
       -o /usr/local/bin/yq \
    && echo "${YQ_SHA256}  /usr/local/bin/yq" | sha256sum -c - \
    && chmod +x /usr/local/bin/yq

# AWS CLI v2 — distributed as a pre-built binary package.
# Pinned to an explicit version (the unversioned URL is a moving target) and the
# PGP signature is verified against the committed AWS CLI Team public key before
# anything is executed.
#
# The fingerprint is re-asserted against the imported key so that swapping the
# committed .asc for a different key fails the build rather than silently
# validating attacker-signed artifacts.
#
# Key: FB5D B77F D5C1 18B8 0511  ADA8 A631 0ACC 4672 475C  <aws-cli@amazon.com>
# NOTE: this key expires 2027-07-01. When it does, refresh
# .devcontainer/aws-cli-public-key.asc from
# https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html
COPY aws-cli-public-key.asc /tmp/aws-cli-public-key.asc
RUN ARCH="$(dpkg --print-architecture)" \
    && case "$ARCH" in \
         amd64) AWS_ARCH="x86_64" ;; \
         arm64) AWS_ARCH="aarch64" ;; \
         *) echo "Unsupported arch: $ARCH" >&2; exit 1 ;; \
       esac \
    && AWS_URL="https://awscli.amazonaws.com/awscli-exe-linux-${AWS_ARCH}-${AWSCLI_VERSION}.zip" \
    && curl -fsSL "$AWS_URL" -o awscliv2.zip \
    && curl -fsSL "${AWS_URL}.sig" -o awscliv2.sig \
    && export GNUPGHOME="$(mktemp -d)" \
    && gpg --batch --import /tmp/aws-cli-public-key.asc \
    && gpg --batch --with-colons --fingerprint aws-cli@amazon.com \
       | awk -F: '/^fpr:/{print $10; exit}' \
       | grep -qx "FB5DB77FD5C118B80511ADA8A6310ACC4672475C" \
    && gpg --batch --verify awscliv2.sig awscliv2.zip \
    && unzip -q awscliv2.zip \
    && ./aws/install \
    && rm -rf awscliv2.zip awscliv2.sig aws /tmp/aws-cli-public-key.asc \
    && { gpgconf --kill all || true; } \
    && rm -rf "$GNUPGHOME"

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

# Docker CLI only — no daemon (docker-outside-of-docker).
# devcontainer.json bind-mounts the host's /var/run/docker.sock, so `docker` here
# drives the *host* daemon. Deliberately does not install docker-ce, which would
# require a privileged container and a second daemon.
RUN mkdir -p -m 755 /etc/apt/keyrings \
    && curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
       | gpg --dearmor -o /etc/apt/keyrings/docker.gpg \
    && chmod go+r /etc/apt/keyrings/docker.gpg \
    && . /etc/os-release \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu ${VERSION_CODENAME} stable" \
    > /etc/apt/sources.list.d/docker.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
       docker-ce-cli \
       docker-buildx-plugin \
       docker-compose-plugin \
    && rm -rf /var/lib/apt/lists/*

# Create the non-root user.
# Ubuntu 24.04 ships a default 'ubuntu' user already holding UID/GID 1000, so it
# is removed first to free them up.
#
# The 'docker' group is created here as a placeholder; .devcontainer/post-start.sh
# re-points it at the GID of the mounted host socket at container start.
RUN userdel -r ubuntu 2>/dev/null || true \
    && groupdel ubuntu 2>/dev/null || true \
    && groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME -s /bin/bash \
    && groupadd -f docker \
    && usermod -aG docker $USERNAME \
    && echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME

# Switch to non-root user
USER $USERNAME
WORKDIR /home/$USERNAME

# Install Claude Code CLI using the official Anthropic native installer.
# This is the vendor-recommended install method: https://docs.claude.com/en/docs/claude-code/setup
# Note: npm installation is deprecated by Anthropic (which is also why the official
# claude-code devcontainer Feature is not used here — it still installs via npm).
# Risk acknowledged: supply-chain trust is delegated to Anthropic's claude.ai domain.
# No checksummed or versioned alternative is currently provided by Anthropic.
RUN curl -fsSL https://claude.ai/install.sh | bash

# Add ~/.local/bin to PATH so the `claude` binary is accessible
ENV PATH="/home/${USERNAME}/.local/bin:$PATH"

# Fail the build if anything above did not land.
RUN echo "Verifying installations..." \
    && git --version \
    && node --version \
    && npm --version \
    && yq --version \
    && aws --version \
    && gh --version \
    && docker --version \
    && docker compose version \
    && claude --version

# Default command
CMD ["/bin/bash"]
