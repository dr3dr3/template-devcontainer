#!/usr/bin/env bash
#
# Runs every time the container starts (devcontainer.json -> postStartCommand),
# as the remote user.
#
# devcontainer.json bind-mounts the host's Docker socket. Its group ownership is
# whatever the host assigned, which almost never matches the container's `docker`
# group, so `docker ps` fails with a permission error. This realigns them.
#
# Preference order, least invasive first:
#   1. socket is already writable        -> do nothing
#   2. socket GID is free                -> re-point the container `docker` group at it
#   3. socket GID belongs to another group -> add the user to that group
#   4. socket is root-owned (Docker Desktop / WSL2) -> chgrp it to `docker`
#
# Only case 4 mutates the socket, and on Docker Desktop / WSL2 that socket lives
# inside the Docker VM, not on your actual host.
set -euo pipefail

SOCKET=/var/run/docker.sock

if [ ! -S "$SOCKET" ]; then
    echo "post-start: no Docker socket at ${SOCKET}; skipping (docker CLI will not work)"
    exit 0
fi

if [ -w "$SOCKET" ]; then
    echo "post-start: Docker socket already accessible"
    exit 0
fi

SOCKET_GID="$(stat -c '%g' "$SOCKET")"
DOCKER_GID="$(getent group docker | cut -d: -f3 || true)"

if [ "$SOCKET_GID" = "${DOCKER_GID:-}" ]; then
    # Group is already right; the shell just has not picked up membership yet.
    echo "post-start: docker group already matches socket GID ${SOCKET_GID}; open a new terminal"
    exit 0
fi

if [ "$SOCKET_GID" = "0" ]; then
    sudo chgrp docker "$SOCKET"
    sudo chmod g+rw "$SOCKET"
    echo "post-start: socket was root-owned; regrouped to 'docker'"
    exit 0
fi

OWNING_GROUP="$(getent group "$SOCKET_GID" | cut -d: -f1 || true)"

if [ -n "$OWNING_GROUP" ] && [ "$OWNING_GROUP" != "docker" ]; then
    sudo usermod -aG "$OWNING_GROUP" "$(id -un)"
    echo "post-start: added $(id -un) to existing group '${OWNING_GROUP}' (GID ${SOCKET_GID})"
else
    sudo groupmod -g "$SOCKET_GID" docker
    echo "post-start: re-pointed 'docker' group at socket GID ${SOCKET_GID}"
fi

echo "post-start: open a new terminal if 'docker ps' still reports a permission error"
