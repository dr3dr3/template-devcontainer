# template-devcontainer

A reusable [Dev Container](https://containers.dev/) for Node/AWS projects, with AI-assisted
development tooling built in. Use it as the starting point for a new repo.

Everything the image downloads is version-pinned and cryptographically verified, and a weekly
CI build on both amd64 and arm64 keeps it from rotting.

---

## What's in the box

Base image: **Ubuntu 24.04 LTS** (Noble, supported until 2029-05-31).

| Tool | Version | Installed from | Verified by |
| --- | --- | --- | --- |
| Node.js + npm | 24 (Active LTS) | NodeSource apt repo | signed apt keyring |
| AWS CLI | v2, pinned | `awscli.amazonaws.com` (versioned URL) | GPG signature + key fingerprint |
| yq | pinned | GitHub releases | SHA-256 checksum |
| GitHub CLI (`gh`) | latest stable | GitHub apt repo | signed apt keyring |
| Docker CLI + Buildx + Compose | latest stable | Docker apt repo | signed apt keyring |
| Claude Code (`claude`) | latest | official native installer | Anthropic (see note below) |
| `git`, `jq`, `build-essential`, `openssh-client`, `less`, `groff`, `unzip` | distro | Ubuntu apt | — |

The exact pinned versions live as `ARG`s at the top of [Dockerfile](.devcontainer/Dockerfile) —
that block is the single place to look or edit.

> **Claude Code note.** Installed via Anthropic's native `claude.ai/install.sh` installer, which
> is the vendor-recommended method. The official `claude-code` Dev Container Feature is
> deliberately *not* used because it still installs through npm, which Anthropic has deprecated.
> Anthropic does not currently publish a checksummed or versioned artifact, so this is the one
> download in the image that cannot be pinned or verified. Trust is delegated to `claude.ai`.

You run as the non-root user **`dev`** (UID/GID 1000, passwordless `sudo`), which lines up with a
typical Linux/WSL2 host user so bind-mounted files in `/workspace` keep sane ownership.

---

## Quick start

**As a template for a new repo** — click **Use this template** on GitHub, clone your new repo, then
open it in VS Code and choose **Reopen in Container** when prompted.

**To try it directly:**

```bash
git clone https://github.com/dr3dr3/template-devcontainer.git
code template-devcontainer
# then: Ctrl+Shift+P -> "Dev Containers: Reopen in Container"
```

Requires [Docker](https://www.docker.com/products/docker-desktop/) and the
[Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers).

---

## Customise after cloning

A short checklist for turning this template into your project:

1. **Rename the container.** `name` in [devcontainer.json](.devcontainer/devcontainer.json) is
   still `DR3DR3-DEVCONTAINER-TEMPLATE`. Update the `LABEL` block at the top of the
   [Dockerfile](.devcontainer/Dockerfile) too — `org.opencontainers.image.source` still points at
   the template repo.
2. **Set your AWS region.** `remoteEnv.AWS_REGION` defaults to `ap-southeast-2`. There is a
   commented `AWS_PROFILE` next to it if you use named profiles.
3. **Trim the extensions list.** Drop what your project does not need — the AWS Toolkit and Live
   Preview in particular are not universally useful.
4. **Update the `LICENSE`** copyright holder, or replace the licence entirely.
5. **Adjust tool versions** if a project needs something specific — either edit the `ARG`s in the
   Dockerfile, or override per-project via `build.args` in `devcontainer.json`.

---

## Git identity

**Nothing is baked into the image.** The Dev Containers extension
[copies your host `~/.gitconfig` into the container](https://code.visualstudio.com/remote/advancedcontainers/sharing-git-credentials)
on startup, so commits are attributed to whoever is running the container.

To use a different identity for one repo, set it locally inside the container:

```bash
git config user.name  'Your Name'
git config user.email 'you@example.com'
```

CI asserts that the built image has no global `user.email`, so this cannot silently regress.

---

## Docker access

This is **docker-outside-of-docker**: the container ships the Docker *CLI* only, and
`devcontainer.json` bind-mounts the host's `/var/run/docker.sock`. There is no second daemon and
no `privileged: true`.

Two consequences worth knowing:

- Containers you start from inside are siblings on the **host** daemon, not children. They are not
  cleaned up when this devcontainer is removed.
- Bind-mount paths you pass to `docker run` are resolved by the **host** daemon, so
  `-v /workspace/foo:/foo` will not do what you expect. Use the host path, or a named volume.

[post-start.sh](.devcontainer/post-start.sh) runs on every container start and reconciles the
container's `docker` group with whatever GID the host socket actually has. If `docker ps` still
reports a permission error immediately after a rebuild, open a fresh terminal so the shell picks
up the new group membership.

---

## What survives a rebuild

Rebuilding the container is cheap because the expensive-to-recreate state lives in named volumes
rather than the image or the workspace:

| Volume | Mounted at | Holds |
| --- | --- | --- |
| `devcontainer-<id>-claude` | `/home/dev/.claude` | Claude Code auth + settings |
| `devcontainer-<id>-aws` | `/home/dev/.aws` | AWS credentials / SSO cache |
| `devcontainer-<id>-history` | `/commandhistory` | bash history |

Volumes are keyed by `${devcontainerId}`, so two projects created from this template do **not**
share credentials.

To reset one (this logs you out):

```bash
docker volume ls | grep devcontainer
docker volume rm <volume-name>
```

---

## Updating pinned versions

Dependabot covers the GitHub Actions and the `FROM ubuntu:24.04` base image. The tool pins are
invisible to it and need a manual bump in [Dockerfile](.devcontainer/Dockerfile):

| `ARG` | Where to check | Notes |
| --- | --- | --- |
| `NODE_MAJOR` | [nodejs.org releases](https://nodejs.org/en/about/previous-releases) | stay on **Active** LTS |
| `YQ_VERSION` | [yq releases](https://github.com/mikefarah/yq/releases) | must recompute both hashes |
| `YQ_SHA256_AMD64` / `_ARM64` | see below | |
| `AWSCLI_VERSION` | [AWS CLI v2 changelog](https://raw.githubusercontent.com/aws/aws-cli/v2/CHANGELOG.rst) | |

Recompute the yq hashes after bumping `YQ_VERSION`:

```bash
V=v4.53.3   # <- your new version
for a in amd64 arm64; do
  echo "$a $(curl -fsSL "https://github.com/mikefarah/yq/releases/download/$V/yq_linux_$a" | sha256sum | cut -d' ' -f1)"
done
```

The `aws --version`, `yq --version` and `node --version` assertions in
[the CI workflow](.github/workflows/devcontainer.yml) also reference these versions and need
updating in the same commit.

> **AWS signing key expiry.** [aws-cli-public-key.asc](.devcontainer/aws-cli-public-key.asc)
> expires **2027-07-01**. When it does, builds will fail at the `gpg --verify` step; refresh the
> key (and the fingerprint asserted in the Dockerfile) from the
> [AWS CLI install docs](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html).

---

## CI

[`.github/workflows/devcontainer.yml`](.github/workflows/devcontainer.yml) builds the container on
every push and PR, weekly on a schedule, across an **amd64 and an arm64** runner — so the
per-architecture branches for yq and the AWS CLI are actually exercised rather than assumed.

Each build asserts: every tool is present and on its pinned version, the session runs as non-root
`dev`, no git identity is baked into the image, and the Docker socket is reachable.

---

## VS Code Extensions

The following extensions are pre-installed in this devcontainer.

### GitHub Pull Requests (`github.vscode-pull-request-github`)

Manage GitHub pull requests and issues directly in VS Code.

* Open the **GitHub Pull Requests** panel in the Activity Bar to view open PRs
* Create, review, and merge pull requests without leaving the editor
* Checkout a PR branch directly from the PR list
* Leave inline review comments on diffs

### GitHub Copilot (`github.copilot`, `github.copilot-chat`)

AI-powered code completions and chat assistance.

* Completions appear inline as you type — press `Tab` to accept
* Open Copilot Chat via `Ctrl+Alt+I` to ask questions or generate code
* Use `Ctrl+I` for inline edits on a selected block of code
* Use `/explain`, `/fix`, `/tests` slash commands in the chat panel

### Claude Code (`anthropic.claude-code`)

The editor companion for the `claude` CLI that ships in this image.

* Run `claude` in the integrated terminal, or open the panel from the Activity Bar
* Selected code and open files are shared as context automatically
* Diffs are proposed in the editor for review before they are applied

### AWS Toolkit (`amazonwebservices.aws-toolkit-vscode`)

Browse and interact with AWS services from within VS Code.

* Sign in via the **AWS** panel in the Activity Bar
* Browse S3 buckets, Lambda functions, CloudFormation stacks, and more
* Open the **AWS Explorer** to navigate resources in `ap-southeast-2` (pre-configured)
* Run and debug Lambda functions locally

### Prettier (`esbenp.prettier-vscode`)

Opinionated code formatter for JS/TS, JSON, Markdown, and more.

* Set as the default formatter, with **Format on Save** already enabled
* Format the current file manually with `Shift+Alt+F`
* Add a `.prettierrc` file to the workspace root to customise rules

### ESLint (`dbaeumer.vscode-eslint`)

Lint JavaScript and TypeScript files using ESLint.

* Lint errors and warnings appear inline with squiggles
* Fix all auto-fixable issues in a file via `Ctrl+Shift+P` → **ESLint: Fix all auto-fixable Problems**
* Requires an ESLint config (`eslint.config.js` or `.eslintrc`) in the workspace

### EditorConfig (`editorconfig.editorconfig`)

Applies the rules in [.editorconfig](.editorconfig) — LF endings, trimmed trailing whitespace,
consistent indent width — so formatting stays stable across editors.

### YAML (`redhat.vscode-yaml`)

Schema-aware editing for YAML files.

* Validation and completion for GitHub Actions workflows out of the box
* Set as the default formatter for `.yml` / `.yaml`

### GitLens (`eamodio.gitlens`)

Git history and blame annotations inline in the editor.

* Inline blame on the current line, showing who last changed it and when
* **File History** and **Line History** views for tracing a change back
* Rich side-by-side comparison between branches, tags, and commits

### Docker (`ms-azuretools.vscode-docker`)

Build, manage, and deploy containerised applications.

* Open the **Docker** panel in the Activity Bar to view images, containers, and registries
* Right-click a `Dockerfile` to build an image directly
* View running container logs and open a shell inside a container from the panel
* Backed by the Docker CLI and host socket described in [Docker access](#docker-access)

### Live Preview (`ms-vscode.live-server`)

Spin up a local development server with live reload for static files.

* Right-click an HTML file and select **Show Preview**
* Or click **Go Live** in the status bar
* The browser auto-refreshes on every file save

---

## Licence

[MIT](LICENSE)
