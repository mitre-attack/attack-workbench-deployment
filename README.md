# ATT&CK Workbench Deployment

This repository contains deployment files for the ATT&CK Workbench, a web application for editing ATT&CK data represented in STIX.
It is composed of a frontend Single Page App (SPA), a backend REST API, and a database.
Optionally, you can deploy a "sidecar service" that makes your Workbench data available over a TAXII 2.1 API.

## Quick Start

### Deploy with Docker Compose

```bash
# Clone this repository
git clone https://github.com/mitre-attack/attack-workbench-deployment.git
cd attack-workbench-deployment

# Copy docker compose template (git-ignored)
mkdir -p instances/my-workbench
cp -r docker/example-setup/* instances/my-workbench/

# Configure environment
cd instances/my-workbench
mv template.env .env
mv configs/rest-api/template.env configs/rest-api/.env

# edit the following files as needed
#   <git-repo>instances/my-workbench/.env
#   configs/rest-api/.env
#   configs/rest-api/rest-api-service-config.json

# Deploy
docker compose up -d

# (Optional) Deploy with TAXII server
docker compose --profile with-taxii up -d
```

Access Workbench at <http://localhost>

Full variable descriptions and examples are available in [docs/configuration](docs/configuration.md).

For source builds or TAXII setup, see [docs/deployment](docs/deployment.md).

For information on how to backup or restore the mongo database, see [docs/database-backups](docs/database-backups.md).

## Kubernetes

For production deployments, Kubernetes manifests with Kustomize are available in the `k8s/` directory.

See [k8s/README](k8s/README.md) for detailed instructions.

## Troubleshooting & Support

- View logs: `docker compose logs -f`
- Check running containers: `docker compose ps`

More tips in [docs/troubleshooting](docs/troubleshooting.md).

For questions or issues, visit the [GitHub issues page](https://github.com/mitre-attack/attack-workbench-deployment/issues).

## Contributing & License

- Contribution guide: [contribution guide](./docs/CONTRIBUTING.md)
- Developer guide: [developer guide](./docs/DEVELOPMENT.md)
- License: [Apache License 2.0](./LICENSE)
