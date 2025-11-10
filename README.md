# ATT&CK Workbench Deployment

This repository contains deployment files for the ATT&CK Workbench, a web application for editing ATT&CK data represented in STIX.
It is composed of a frontend Single Page App (SPA), a backend REST API, and a database.
Optionally, you can deploy a "sidecar service" that makes your Workbench data available over a TAXII 2.1 API.

## Docker Setup

To quickly create and deploy a custom Workbench instance using Docker Compose use the interactive setup script in the `docker/` directory.

See [docker/README](docker/README.md) for detailed instructions.

## Kubernetes Setup

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
