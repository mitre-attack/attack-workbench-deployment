# Docker Compose Setup

Use the interactive setup script `setup-workbench.sh` to quickly create and deploy a custom Workbench instance:

```bash
# Clone and run setup script
git clone https://github.com/mitre-attack/attack-workbench-deployment.git
cd attack-workbench-deployment/docker/
./setup-workbench.sh
```

After running the script, deploy with:

```bash
cd ../instances/your-instance-name

# Deploy with published images
docker compose up -d

# Build a developer-mode stack without active file watching
docker compose up -d --build

# Build, run, and watch source changes in developer mode
docker compose up --watch --build

# Or start watching after the developer-mode stack is already running
docker compose watch
```

Access Workbench at <http://localhost>

Developer mode requires Docker Compose 2.22.0 or newer for Compose Watch and sibling component repositories next to this deployment repository:

- `attack-workbench-frontend`
- `attack-workbench-rest-api`
- `attack-workbench-taxii-server` when TAXII is enabled

In developer mode, Compose Watch syncs component source into named Docker volumes mounted at the application source paths. This avoids writing watched files directly into image layers, which is important on Docker Desktop environments that use Enhanced Container Isolation/rootless runtimes. The frontend runs Angular's dev server, the REST API runs its development watcher, and TAXII runs Nest's watch mode. Dependency manifest and build configuration changes such as `package.json`, `package-lock.json`, or Angular TypeScript config files rebuild the affected service image.

Full variable descriptions and examples are available in [docs/configuration](docs/configuration.md).

For source builds or TAXII setup, see [docs/deployment](docs/deployment.md).

For information on how to backup or restore the mongo database, see [docs/database-backups](docs/database-backups.md).
