# ATT&CK Workbench Deployment

This repository contains deployment files for the ATT&CK Workbench, a web application for editing ATT&CK data represented in STIX. It is composed of a frontend SPA, a backend REST API, and a database. Optionally, you can deploy a "sidecar service" that makes your Workbench data available over a TAXII 2.1 API.

## Deployment Options

### Docker Compose

The ATT&CK Workbench can be deployed using Docker Compose with two different configurations:

#### 1. Using Pre-built Images (Recommended)

Use `compose.yaml` to pull pre-built images directly from GitHub Container Registry (GHCR):

```bash
# Deploy with pre-built images
docker compose up -d

# Deploy with TAXII server
docker compose --profile with-taxii up -d

# Stop the deployment
docker compose down
```

#### 2. Building from Source

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
- [attack-workbench-taxii-server](https://mitre-attack/attack-workbench-taxii-server/)

The directory structure should look like this:
```bash
.
├── attack-workbench-deployment
├── attack-workbench-frontend
├── attack-workbench-rest-api
└── attack-workbench-taxii-server (optional)
```

### Kubernetes

For production deployments, Kubernetes manifests with Kustomize are available in the `k8s/` directory. See [k8s/README.md](k8s/README.md) for detailed instructions.

## Configuration

### Environment Variables

We make heavy use of string interpolation to minimize having to modify the Docker Compose manifest files (e.g., [compose.yaml](./compose.yaml)). Consequently, that means you must set a bunch of environment variables when using these templates. Fortunately, we've provided a dotenv template that you can source.

Copy `template.env` to `.env` and customize the values as needed:

```bash
cp template.env .env
```

Available environment variables:

| Variable | Default Value | Description |
|----------|---------------|-------------|
| **Docker Image Tags** | | |
| `ATTACKWB_FRONTEND_VERSION` | `latest` | Frontend Docker image tag |
| `ATTACKWB_RESTAPI_VERSION` | `latest` | REST API Docker image tag |
| `ATTACKWB_TAXII_VERSION` | `latest` | TAXII server Docker image tag |
| **HTTP Listener Ports** | | |
| `ATTACKWB_FRONTEND_HTTP_PORT` | `80` | Frontend HTTP port |
| `ATTACKWB_FRONTEND_HTTPS_PORT` | `443` | Frontend HTTPS port |
| `ATTACKWB_RESTAPI_HTTP_PORT` | `3000` | REST API port |
| `ATTACKWB_DB_PORT` | `27017` | MongoDB port |
| `ATTACKWB_TAXII_HTTP_PORT` | `5002` | TAXII server port |
| **SSL/TLS Configuration** | | |
| `ATTACKWB_FRONTEND_CERTS_PATH` | `./certs` | Path to SSL certificates |
| **TAXII Configuration** | | |
| `ATTACKWB_TAXII_ENV` | `dev` | Specifies the name of the dotenv file to load (e.g., A value of `dev` tells the TAXII server to load `dev.env`) |

### Service-Specific Configuration

Each service has its own configuration directory:

- **Frontend**: `configs/frontend/` - The frontend container is an Nginx instance which serves the frontend SPA and reverse proxies requests to the backend REST API. We provide a basic `nginx.conf` template in the aforementioned directory that should get you started. Refer to the [frontend documentation](https://github.com/center-for-threat-informed-defense/attack-workbench-frontend) for further details on customizing the SPA.
- **REST API**: `configs/rest-api/` - The backend REST API loads runtime configurations from environment variables, as well as from a JSON configuration file. Templates are provided in the aforementioned directory. Refer to the [REST API usage documentation](https://github.com/center-for-threat-informed-defense/attack-workbench-rest-api/blob/main/USAGE.md#configuration) for further details on customizing the backend.
- **TAXII Server**: `configs/taxii/config/` - The TAXII server loads all runtime configuration parameters from a dotenv file. The specific filename of the dotenv file is specified by the `ATTACKWB_TAXII_ENV` environment variable. For example, a value of `dev` tells the TAXII server to load `dev.env`.

## Quick Start

1. Clone this repository:
   ```bash
   git clone https://github.com/center-for-threat-informed-defense/attack-workbench-deployment.git
   cd attack-workbench-deployment
   ```

2. Configure environment variables (optional):
   ```bash
   cp template.env .env
   # Edit .env with your preferred settings
   ```

3. Deploy using pre-built images:
   ```bash
   docker compose up -d
   ```

4. Access the application at `http://localhost` (or your configured port)

5. To include the TAXII server:
   ```bash
   docker compose --profile with-taxii up -d
   ```

## Data Persistence

MongoDB data is persisted in the `workspace-data` named Docker volume. Thus, the `database` service can be deleted and re-deployed without losing access to the database. The database volume will be remounted to the `database` service upon deployment.

## Troubleshooting

### Check Service Status

```bash
# View running containers
docker compose ps

# Show logs for all running containers
docker compose logs

# Follow logs
docker compose logs -f

# Show logs for a specific container
docker compose logs frontend
docker compose logs rest-api  
docker compose logs database
docker compose logs taxii
```

## Contributing

Please refer to the [contribution guide](./docs/CONTRIBUTING.md) for contribution guidelines, as well as the [developer guide](./docs/DEVELOPMENT.md) for information on our release process.

## License

This project is licensed under the Apache License 2.0. See the [LICENSE](./LICENSE) file for details.

## Support

For issues and questions:
- Check the [deployment repository issues](https://github.com/center-for-threat-informed-defense/attack-workbench-deployment/issues)
- Refer to the main [ATT&CK Workbench documentation](https://github.com/center-for-threat-informed-defense/attack-workbench-frontend)