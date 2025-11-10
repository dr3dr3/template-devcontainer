FROM node:alpine

LABEL maintainer="Andre Dreyer"

# Foundation packages
RUN apk add --no-cache fish starship stow git github-cli gum font-fira-code-nerd

# Claude Code
RUN npm install -g @anthropic-ai/claude-code

# Task Master .dev (MCP)
RUN npm install -g task-master-ai

ENV SHELL=/usr/bin/fish

ENTRYPOINT ["/usr/bin/fish"]
