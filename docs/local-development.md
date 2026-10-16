# Local development with Docker Compose

Use this workflow when editing the frontend, REST API, or TAXII server in local
checkouts. For published images, follow the [Docker quickstart](../docker/README.md).

## Start a development instance

Use Docker Compose **2.32.0 or newer** (`docker compose version`). The
[`restart` Watch action](https://docs.docker.com/reference/compose-file/develop/#action)
sets this minimum version.

Keep the component repositories beside the deployment repository:

```text
working-directory/
├── attack-workbench-deployment/
├── attack-workbench-frontend/
├── attack-workbench-rest-api/
└── attack-workbench-taxii-server/    # when TAXII is enabled
```

From the deployment repository:

```bash
./docker/setup-workbench.sh --dev-mode --instance-name my-workbench
cd instances/my-workbench
docker compose up --watch --build
```

Add `--taxii-server` to the setup command to include TAXII. Setup generates
`compose.override.yaml`, which Compose loads automatically. The sibling checkouts
must be accessible to Docker on the host running its daemon.

Open the configured frontend HTTP port. The frontend proxies `/api` to
`http://rest-api:3000` inside the Compose network, so changing the API's published
host port does not require changing the browser configuration. Local development
uses HTTP without certificates. For access from another computer, use the
Docker host's address; see the frontend's
[API routing and remote access guidance](https://github.com/mitre-attack/attack-workbench-frontend/blob/next/docs/admin/configuration.md#api-routing)
for development-server hostname settings.

## What reloads

| Change | Result while Watch is running |
| --- | --- |
| Frontend components, templates, styles, or build-mode settings | Angular detects the mounted source through polling and rebuilds. |
| Frontend `src/assets` files | Compose restarts Angular, including when an asset is added or deleted. |
| Add, edit, or remove frontend `configs/frontend/config.json` | Compose restarts Angular and regenerates public configuration; an absent default file uses environment settings and defaults. |
| REST API `app` or `bin` files, including OpenAPI YAML | Compose restarts Node to load the current source. |
| REST API JSON configuration | Compose restarts the API. Enable loading the file as described in [service configuration](configuration.md#rest-api-configuration-files). |
| TAXII `src` files | Compose restarts the container, compiles TypeScript, and starts the server and collector under PM2. |
| Watched dependency manifests or build configuration | Compose rebuilds the affected image and recreates the container. |

The generated override defines the exact watched paths. After changing an
unwatched build input, run `docker compose up -d --build` for the affected service.
For frontend and API environment-file changes, recreate the affected container
as described in [service configuration](configuration.md#service-specific-configuration).
