# Deployment Options

## Docker Compose

The ATT&CK Workbench can be deployed using Docker Compose with two different configurations:

The easiest way to generate a deployment-ready instance is with
`docker/setup-workbench.sh`, which can also enable optional services such as
TAXII, Grafana, and the insights agent:

```bash
./docker/setup-workbench.sh --instance-name my-workbench --insights
```

If your environment requires mounted files to live under a dedicated host
directory, generate the instance with:

```bash
./docker/setup-workbench.sh --instance-name my-workbench --insights \
  --host-mount-dir /Users/Shared/Docker/my-workbench
```

### 1. Using Pre-built Images (Recommended)

Use the generated `compose.yaml` to pull pre-built images from GitHub Container Registry (GHCR). Select optional services during setup; the generated file includes those choices:

```bash
# Deploy with pre-built images
docker compose up -d

# Stop the deployment
docker compose down
```

### 2. Building from Source

Use the setup script's developer mode to build from sibling source checkouts.
See [local development](local-development.md) for the required Compose version,
repository layout, startup commands, and reload behavior.

### Data Persistence

MongoDB data is persisted in the `workspace-data` named Docker volume.
Thus, the `mongodb` service can be deleted and re-deployed without losing access to the database.
The database volume will be remounted to the `mongodb` service upon deployment.
