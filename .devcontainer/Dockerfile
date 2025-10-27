FROM node:alpine

LABEL maintainer="Andre Dreyer"

RUN apk add --no-cache fish starship stow git github-cli gum font-fira-code-nerd

RUN npm install -g @anthropic-ai/claude-code

ENV SHELL=/usr/bin/fish

ENTRYPOINT ["/usr/bin/fish"]
