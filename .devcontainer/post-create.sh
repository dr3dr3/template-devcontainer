#!/usr/bin/env bash
#
# Runs once, the first time the container is created (devcontainer.json ->
# postCreateCommand), as the remote user.
#
# Docker creates named volumes root-owned, so the mount points declared in
# devcontainer.json need handing back to the dev user before anything can
# write to them.
set -euo pipefail

USER_NAME="$(id -un)"
USER_GROUP="$(id -gn)"

for dir in "${HOME}/.claude" "${HOME}/.aws" /commandhistory; do
    if [ -d "$dir" ] && [ ! -w "$dir" ]; then
        sudo chown -R "${USER_NAME}:${USER_GROUP}" "$dir"
    fi
done

# Persist bash history to the /commandhistory volume so it survives rebuilds.
# `history -a` flushes after every command rather than only on clean exit.
if [ -d /commandhistory ] && ! grep -q 'commandhistory/.bash_history' "${HOME}/.bashrc" 2>/dev/null; then
    cat >> "${HOME}/.bashrc" <<'EOF'

# --- devcontainer: persistent shell history -------------------------------
export HISTFILE=/commandhistory/.bash_history
export HISTSIZE=10000
export HISTFILESIZE=20000
export HISTCONTROL=ignoreboth
shopt -s histappend
# Flush after every command so history survives a container stop, not just a
# clean shell exit. Deliberately not exported, and guarded, so nested shells
# don't keep prepending another copy of `history -a`.
case "${PROMPT_COMMAND:-}" in
    *"history -a"*) ;;
    *) PROMPT_COMMAND="history -a${PROMPT_COMMAND:+; ${PROMPT_COMMAND}}" ;;
esac
# --------------------------------------------------------------------------
EOF
fi

echo "post-create: done"
