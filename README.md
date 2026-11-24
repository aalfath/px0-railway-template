# px0 on Railway

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/new/template/px0?utm_medium=integration&utm_source=button&utm_campaign=px0)

One-click Railway template for [px0](https://github.com/px0-ai/px0) **v0.1.21** (commit `f5c7e67`), the browser review workbench and fast IDE for AI-generated code, behind Caddy basic auth.

px0 is an open-source (MIT) review workbench and fast browser IDE for AI-generated code. It opens GitHub, GitLab, Gitea/Forgejo and Bitbucket pull requests as scoped diffs, lets you search and navigate large repositories, edit files in place and keep review drafts between sessions. It is a single Go binary.

## About Hosting px0

px0 has no login of its own and its workbench can browse the server's file system, so this template puts it on a loopback port behind Caddy with HTTP basic auth. You sign in as `admin` with the password Railway generates (`PX0_PASSWORD` on the service's Variables tab). The workbench list, review drafts and cloned repositories live in `/data` on a Railway volume, so they survive redeploys. The service starts in about a minute and peaked at about 50 MB of RAM in our test while reviewing a pull request (larger repositories need more), so it runs on Railway's Free plan (0.5 GB). Telemetry and px0's self-update are switched off.

## Common Use Cases

* Review pull requests opened by coding agents (Claude Code, Codex, Cursor) in a fast browser diff view, from any device
* Read and search a large repository without installing an editor
* Keep a shared, always-on review workbench with drafts that persist between sessions

## Dependencies for px0 Hosting

* px0 v0.1.21, built from the upstream release commit
* Caddy 2.11 (basic auth and reverse proxy, in the same container)

### Deployment Dependencies

* [px0 on GitHub](https://github.com/px0-ai/px0)
* [Template source and changelog](https://github.com/aalfath/px0-railway-template)

### Implementation Details

After deploy, open the public URL, sign in as `admin` with `PX0_PASSWORD`, then paste a pull request URL (for example `https://github.com/OWNER/REPO/pull/123`) or a folder path into the workbench. Public pull requests work without a token. For private repositories, higher GitHub API limits or posting review comments, set `GITHUB_TOKEN` (a fine-grained token with Pull requests and Contents access). GitLab, Gitea and Bitbucket work the same way with `GITLAB_TOKEN` + `GITLAB_HOST`, `GITEA_TOKEN` + `GITEA_HOST` or `BITBUCKET_TOKEN` + `BITBUCKET_EMAIL`, added on the Variables tab.

Coding-agent CLIs and language servers are not installed in the image, so px0's "send to agent" buttons and LSP features stay unavailable; reviewing, searching and editing work, and posting review comments works once a token is set. Requests from other sites are rejected. Updates: the service builds from the template repo, and Railway shows "update available" when a new px0 version is pinned there; read the changelog first.

## Why Deploy px0 on Railway?

<!-- Recommended: Keep this section as shown below -->
Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying px0 on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
<!-- End recommended section -->

## Variables

| Variable | Default | What it does |
|---|---|---|
| `PX0_PASSWORD` | generated (`${{secret(24)}}`) | Password for the basic-auth login. At least 12 characters. |
| `PX0_USERNAME` | `admin` | User name for the basic-auth login. |
| `GITHUB_TOKEN` | empty (optional) | GitHub token for private repos, higher API limits and posting review comments. |
| `PORT` | `8080` | Port Caddy listens on (Railway's public domain points here). |

Optional, added by hand: `GITLAB_TOKEN`/`GITLAB_HOST`, `GITEA_TOKEN`/`GITEA_HOST`, `BITBUCKET_TOKEN`/`BITBUCKET_EMAIL`.

Health check: `GET /healthz` (no login; px0's own ping). Volume: `/data` (px0 state in `/data/.px0`, workspace in `/data/workspace`).

## How it is built

- `Dockerfile`: fetches px0 at the pinned release commit, builds the web bundle and a static Go binary, and copies them with a pinned Caddy binary onto a pinned Debian slim image. Every base image is pinned by version and digest.
- `start.sh`: refuses to start without a password, hashes it for Caddy, sizes `GOMEMLIMIT`/`GOMAXPROCS` from the service's limits, starts px0 on `127.0.0.1:7777` and Caddy on `$PORT`, and exits non-zero if either stops so Railway restarts the service.
- `Caddyfile`: basic auth, an open `/healthz`, and the Host/Origin mapping px0's same-origin check needs behind a public domain (requests from other sites are refused).

## Updates

The service builds from this repository's `main` branch. When a new px0 release is pinned here, Railway shows deployers an "update available" notice; read [CHANGELOG.md](CHANGELOG.md) before applying it. Your data on the `/data` volume is kept.
