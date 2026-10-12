# Joplin Web App (Dockerized)

A self-hostable Docker container for the official [Joplin Web Client](https://github.com/laurent22/joplin).

This repository is maintained as an independent container distribution for self-hosters and local users. The upstream Joplin monorepo code is integrated as a git submodule (`joplin/`), cleanly separating container orchestration from the application source.

Container image: **`ghcr.io/adamoutler/web-app:latest`**

---

## Quick Start with Docker

### Option 1: Docker Compose (Recommended)

Create or use the included `docker-compose.yml`:

```yaml
services:
  joplin-webapp:
    image: ghcr.io/adamoutler/web-app:latest
    container_name: joplin-webapp
    restart: unless-stopped
    ports:
      - "8088:80"
```

Start the container:
```bash
docker compose up -d
```

### Option 2: Docker CLI

```bash
docker run -d --name joplin-webapp -p 8088:80 ghcr.io/adamoutler/web-app:latest
```

Once running, access the web client at `http://<your-docker-host-ip>:8088` (or via your HTTPS reverse proxy).

---

## Production Setup & Reverse Proxy

> [!IMPORTANT]
> The Joplin Web App relies on WebAssembly with SQLite workers (`SharedArrayBuffer`), which requires **Cross-Origin Isolation**. The container automatically serves the necessary `Cross-Origin-Opener-Policy: same-origin` and `Cross-Origin-Embedder-Policy: require-corp` headers. Both the Web App and your Joplin Server **must be served over HTTPS**.

### 1. Reverse Proxy for Joplin Web App

Point your reverse proxy (Nginx, Traefik, Caddy, etc.) to container port `8088`. Ensure HTTPS/TLS is configured (e.g. using Let's Encrypt).

### 2. Configure CORS Headers on Joplin Server

Because your Joplin Web App (e.g., `https://joplin-webapp.yourdomain.com`) and Joplin Server (e.g., `https://joplin-server.yourdomain.com`) run on distinct origins, you must configure CORS headers on the **Joplin Server reverse proxy**:

#### Nginx Example (Joplin Server reverse proxy):
```nginx
# Set this variable to the exact origin from which your Joplin WebApp is served:
set $my_origin 'https://joplin-webapp.yourdomain.com'; # <-- CHANGE THIS

if ($request_method = 'OPTIONS') {
    add_header 'Access-Control-Allow-Origin'  $my_origin always; 
    add_header 'Access-Control-Allow-Credentials' 'true' always; 
    add_header 'Access-Control-Allow-Methods' 'GET, POST, PUT, DELETE, PATCH, OPTIONS' always;
    add_header 'Access-Control-Allow-Headers' 'Authorization, Content-Type, Accept, Origin, X-Requested-With, X-Api-Key, X-Api-Auth, DNT, Cache-Control, If-Modified-Since, If-None-Match, Range, x-api-min-version' always; 
    add_header 'Access-Control-Max-Age' 86400 always;
    add_header 'Content-Length' 0;
    return 204;
}

proxy_hide_header Access-Control-Allow-Origin;
proxy_hide_header Access-Control-Allow-Credentials;
add_header Access-Control-Allow-Origin  $my_origin  always;
add_header Access-Control-Allow-Credentials 'true' always;
```

---

## Building from Source

This repository maintains the Joplin codebase as a git submodule in `./joplin`.

### Prerequisites
- Git
- Node.js (>= 18)
- Corepack (`corepack enable`)
- Docker

### 1. Clone with Submodules
```bash
git clone --recurse-submodules https://github.com/adamoutler/web-app.git
cd web-app
```

### 2. Update to Latest Joplin Release
Run the automated update script to discover and checkout the latest official Joplin release branch:
```bash
./scripts/update-submodule.sh
```

### 3. Build & Stage Web App
Compile the Joplin web client and stage it into `pages/`:
```bash
./scripts/build.sh
```

### 4. Build Docker Container
To build the Docker container image locally:
```bash
./scripts/build.sh --docker
# Or manually:
docker build -t ghcr.io/adamoutler/web-app:latest .
```

---

## CI/CD Automation

The GitHub Actions workflow in [`.github/workflows/deploy-github-pages.yml`](.github/workflows/deploy-github-pages.yml):
- Dynamically discovers the newest Joplin `release-*` branch.
- Compiles the web application via Webpack.
- Builds multi-architecture container images (`linux/amd64` and `linux/arm64`).
- Publishes to `ghcr.io/adamoutler/web-app:latest` and tagged version releases.
- Deploys static build artifacts to GitHub Pages.
- Runs automatically on push to `main`, weekly via cron (`0 0 * * 0`), and manually via `workflow_dispatch`.

---

## FAQ

### What is Joplin Web?
Joplin Web is the Joplin client running directly in a web browser using WebAssembly. It is local-first, storing notes and attachments locally in browser storage while synchronizing with your configured Joplin Server or sync target.

### What browsers are supported?
Modern versions of Chromium-based browsers (Chrome, Brave, Edge) and Safari are recommended. Firefox is supported but initial database initialization may take longer.
