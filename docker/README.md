# Docker Compose Setup

Use the interactive setup script `setup-workbench.sh` to quickly create and deploy a custom Workbench instance:

```bash
# Clone and run setup script
git clone https://github.com/mitre-attack/attack-workbench-deployment.git
cd attack-workbench-deployment
./docker/setup-workbench.sh
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
