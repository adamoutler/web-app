---
name: joplin-webapp-builder
description: >-
  Use this skill to update the Joplin git submodule to the latest upstream release
  and execute the build workflow to compile the Joplin web app and produce the Docker container.
---

# Joplin Web App Builder Skill

This skill provides procedures for maintaining, updating, and compiling the dockerized Joplin Web Application.

## Repository Architecture

This repository (`adamoutler/web-app`) is structured to completely decouple the containerization and hosting layer from the upstream Joplin application codebase:

- **Root Directory**: Container deployment files (`Dockerfile`, `docker-compose.yml`, `coop-coep.conf`), CI/CD automation (`.github/workflows/deploy-github-pages.yml`), automation scripts (`scripts/`), and documentation.
- **`joplin/` (Submodule)**: Points to the upstream Joplin monorepo (`https://github.com/laurent22/joplin.git`), tracking the latest stable release branch (e.g. `release-3.7`).
- **`pages/`**: Staging directory for compiled web assets (generated during build, git-ignored).

---

## 1. Updating the Submodule to Latest Joplin Release

To fetch and switch the submodule to the newest official Joplin release:

### Automated Command:
```bash
./scripts/update-submodule.sh
```

### Manual Procedure:
1. Ensure the submodule is initialized:
   ```bash
   git submodule update --init --recursive joplin
   ```
2. Fetch release branches from upstream:
   ```bash
   cd joplin
   git fetch origin --depth=1 'refs/heads/release-*:refs/remotes/origin/release-*'
   ```
3. Determine the latest release branch:
   ```bash
   ALL_BRANCHES="$(git for-each-ref --format '%(refname:short)' 'refs/remotes/origin/release-*' | sed 's;origin/;;')"
   LATEST_RELEASE="release-$(echo "$ALL_BRANCHES" | grep -P '^release-[0-9]+\.[0-9]+$' | sed 's/^release-//' | sort --version-sort | tail -n1)"
   echo "Latest release: $LATEST_RELEASE"
   ```
4. Checkout the latest release:
   ```bash
   git checkout "$LATEST_RELEASE"
   cd ..
   git config -f .gitmodules submodule.joplin.branch "$LATEST_RELEASE"
   ```

---

## 2. Compiling the Web App & Building the Docker Image

The Joplin web application lives in `joplin/packages/app-mobile` and requires Yarn with Webpack.

### Automated Command:
```bash
# Build web app and stage into pages/
./scripts/build.sh

# Build web app and generate Docker image
./scripts/build.sh --docker
```

### Specific Commands Required to Build:

1. **Enable Corepack & Yarn**:
   ```bash
   corepack enable
   ```

2. **Install Monorepo Dependencies**:
   ```bash
   cd joplin
   yarn install
   ```

3. **Compile Joplin Web Client**:
   ```bash
   cd packages/app-mobile
   yarn web
   ```
   *(This executes `webpack --mode production --config ./web/webpack.config.ts` and copies assets to `./web/dist/`)*

4. **Stage Build Artifacts**:
   ```bash
   cd ../../..  # Back to repo root
   mkdir -p pages/
   cp -r joplin/packages/app-mobile/web/dist/* pages/
   ```

5. **Build Docker Image**:
   ```bash
   docker build -t ghcr.io/adamoutler/web-app:latest .
   ```

---

## 3. Running & Testing Locally

### Using Docker Run:
```bash
docker run -d --name joplin-webapp -p 8088:80 ghcr.io/adamoutler/web-app:latest
```

### Using Docker Compose:
```bash
docker compose up -d
```

### Validation:
- Verify container is running: `docker ps | grep joplin-webapp`
- Test HTTP headers for cross-origin isolation (required for WebAssembly SQLite):
  ```bash
  curl -I http://localhost:8088
  ```
  Expected headers:
  ```http
  Cross-Origin-Opener-Policy: same-origin
  Cross-Origin-Embedder-Policy: require-corp
  ```

---

## 4. GitHub Actions CI/CD Pipeline

The GitHub Actions workflow at [`.github/workflows/deploy-github-pages.yml`](.github/workflows/deploy-github-pages.yml) ensures automated builds on:
- Manual trigger (`workflow_dispatch`)
- Push to `main` branch
- Weekly cron schedule (`0 0 * * 0`)

The workflow automatically:
1. Checks out the repository and initializes submodules.
2. Queries upstream `laurent22/joplin` for the latest `release-*` branch.
3. Compiles the web client via `yarn web`.
4. Deploys to GitHub Pages.
5. Builds and publishes multi-architecture images (`linux/amd64` and `linux/arm64`) to `ghcr.io/adamoutler/web-app:latest`, tagged with both the Joplin version and release timestamp.
