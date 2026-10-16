# Docker Compose Setup

Use the interactive setup script to create a Workbench instance:

```bash
git clone https://github.com/mitre-attack/attack-workbench-deployment.git
cd attack-workbench-deployment/docker/
./setup-workbench.sh
```

After setup, start the instance:

```bash
cd ../instances/your-instance-name
docker compose up -d
```

Open <http://localhost>, or the HTTP port selected during setup.

For live development, select developer mode during setup, then run
`docker compose up --watch --build`. See [local development](../docs/local-development.md)
for prerequisites, reload behavior, and switching branches.

- [Configuration](../docs/configuration.md): ports, mounted files, and service settings.
- [Deployment](../docs/deployment.md): deployment choices and optional services.
- [Database backups](../docs/database-backups.md): backup and restore procedures.
