# Deployment Options

## Docker Compose

The ATT&CK Workbench can be deployed using Docker Compose with two different configurations:

### 1. Using Pre-built Images (Recommended)

Use `compose.yaml` to pull pre-built images directly from GitHub Container Registry (GHCR):

```bash
# Deploy with pre-built images
docker compose up -d

# Deploy with TAXII server
docker compose --profile with-taxii up -d

# Stop the deployment
docker compose down
```

### 2. Building from Source

Use `compose.dev.yaml` in combination with `compose.yaml` to build images from source code:

```bash
# Build and deploy from source
docker compose -f compose.yaml -f compose.dev.yaml up -d --build

# Build and deploy with TAXII server
docker compose -f compose.yaml -f compose.dev.yaml --profile with-taxii up -d --build

# Stop the deployment
docker compose -f compose.yaml -f compose.dev.yaml down
```

**Note**: When building from source, you need the following three source repositories to be available as sibling directories to this deployment repository:

- [attack-workbench-frontend](https://github.com/center-for-threat-informed-defense/attack-workbench-frontend/)
- [attack-workbench-rest-api](https://github.com/center-for-threat-informed-defense/attack-workbench-rest-api/)
- [attack-workbench-taxii-server](https://github.com/mitre-attack/attack-workbench-taxii-server)

The directory structure should look like this:

```bash
.
├── attack-workbench-deployment
├── attack-workbench-frontend
├── attack-workbench-rest-api
└── attack-workbench-taxii-server (optional)
```

### Data Persistence

MongoDB data is persisted in the `workspace-data` named Docker volume.
Thus, the `database` service can be deleted and re-deployed without losing access to the database.
The database volume will be remounted to the `database` service upon deployment.
