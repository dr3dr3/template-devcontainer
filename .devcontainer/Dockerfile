FROM node:alpine

LABEL maintainer="Andre Dreyer"

# Claude Code
RUN npm install -g @anthropic-ai/claude-code

# Continuedev CLI
RUN npm i -g @continuedev/cli

# Task Master .dev (MCP)
RUN npm install -g --legacy-peer-deps task-master-ai

# Install git and configure user
RUN apk add git && git config --global user.name "André Dreyer" && git config --global user.email "github@andredreyer.com"

# Set fish as default shell
ENV SHELL=/usr/bin/fish

ENTRYPOINT ["/usr/bin/fish"]