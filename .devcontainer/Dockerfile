FROM node:alpine

LABEL maintainer="Andre Dreyer"

# Dependencies for my dotfiles and work setup
RUN apk add --no-cache nushell fish starship stow git gum font-fira-code-nerd

# Claude Code
RUN npm install -g @anthropic-ai/claude-code

# Task Master .dev (MCP)
RUN npm install -g task-master-ai

ENV SHELL=/usr/bin/fish

ENTRYPOINT ["/usr/bin/fish"]
