# ATT&CK Workbench Deployment

This repository contains deployment files for the ATT&CK Workbench, a web application for editing ATT&CK data represented in STIX.
It is composed of a frontend Single Page App (SPA), a backend REST API, and a database.
Optionally, you can deploy a "sidecar service" that makes your Workbench data available over a TAXII 2.1 API.

## Quick Start

### Automated Setup (Recommended)

Use the interactive setup script to quickly create and deploy a custom Workbench instance:

```bash
# Clone and run setup script
git clone https://github.com/mitre-attack/attack-workbench-deployment.git
cd attack-workbench-deployment
./setup-workbench.sh
```

**NOTE**: Running this part doesn't work yet...

Or run directly without cloning:

```bash
curl -fsSL https://raw.githubusercontent.com/mitre-attack/attack-workbench-deployment/main/setup-workbench.sh | bash
```

After running the script, deploy with:

```bash
cd instances/your-instance-name
docker compose up -d
```

For developer mode deployments, use:

```bash
cd instances/your-instance-name
docker compose up -d --build
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
