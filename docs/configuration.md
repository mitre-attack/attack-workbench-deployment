# Configuration

## Docker Compose Environment Variables

We make heavy use of string interpolation to minimize having to modify the Docker Compose files.
Consequently, that means you must set a bunch of environment variables when using these templates.
Fortunately, we've provided a dotenv template that you can source.

Copy `template.env` to `.env` and customize the values as needed:

```bash
cp template.env .env
```

If you use `docker/setup-workbench.sh`, the script can also rewrite these path
variables to point at a dedicated host directory via `--host-mount-dir`. This
is useful in environments that require all Docker mounts to come from a
specific location such as `/Users/Shared/Docker/...`.

Available environment variables:

### Docker Image Tags

| Variable                    | Default Value | Description                   |
|-----------------------------|---------------|-------------------------------|
| `ATTACKWB_FRONTEND_VERSION` | `latest`      | Frontend Docker image tag     |
| `ATTACKWB_RESTAPI_VERSION`  | `latest`      | REST API Docker image tag     |
| `ATTACKWB_GRAFANA_VERSION`  | `latest`      | Grafana Docker image tag      |
| `ATTACKWB_TAXII_VERSION`    | `latest`      | TAXII server Docker image tag |

### Frontend

| Variable                              | Default Value                       | Description                        |
|---------------------------------------|-------------------------------------|------------------------------------|
| `ATTACKWB_FRONTEND_HTTP_PORT`         | `80`                                | Frontend HTTP port                 |
| `ATTACKWB_FRONTEND_HTTPS_PORT`        | `443`                               | Frontend HTTPS port                |
| `ATTACKWB_FRONTEND_NGINX_CONFIG_FILE` | `./configs/frontend/nginx.api.conf` | Path to nginx config file          |
| `ATTACKWB_FRONTEND_CERTS_PATH`        | `./certs`                           | Path to SSL certificates for nginx |

There are four sample nginx config files that can be used as reference:

- `nginx.conf`: Minimal nginx configuration that only routes the Workbench frontend.
- `nginx.ssl.conf`: Same as `nginx.conf` but with an SSL redirect. You need to provide your own SSL certs in the `ATTACKWB_FRONTEND_CERTS_PATH` directory.
- `nginx.api.conf` (default): Nginx configuration with an additional `/api` location block for connecting to the REST API container.
- `nginx.api.ssl.conf`: Same as `nginx.api.conf` but with an SSL redirect. You need to provide your own SSL certs in the `ATTACKWB_FRONTEND_CERTS_PATH` directory.

### REST API

| Variable                       | Default Value                                     | Description                                       |
|--------------------------------|---------------------------------------------------|---------------------------------------------------|
| `ATTACKWB_RESTAPI_HTTP_PORT`   | `3000`                                            | REST API port                                     |
| `ATTACKWB_RESTAPI_CONFIG_FILE` | `./configs/rest-api/rest-api-service-config.json` | Path to REST API JSON config file                 |
| `ATTACKWB_RESTAPI_ENV_FILE`    | `./configs/rest-api/.env`                         | Path to REST API environment variable config file |

### Grafana

| Variable                         | Default Value                         | Description                                   |
|----------------------------------|---------------------------------------|-----------------------------------------------|
| `ATTACKWB_GRAFANA_PORT`          | `3001`                                | Grafana HTTP port                             |
| `ATTACKWB_GRAFANA_ENV_FILE`      | `./configs/grafana/.env`              | Path to Grafana environment variable config   |
| `ATTACKWB_GRAFANA_PROVISIONING_PATH` | `./configs/grafana/provisioning`  | Path to Grafana provisioning directory        |

### Insights Agent

| Variable                           | Default Value                        | Description                                         |
|------------------------------------|--------------------------------------|-----------------------------------------------------|
| `ATTACKWB_INSIGHTS_AGENT_ENV_FILE` | `./configs/insights-agent/.env`      | Path to the insights agent environment config file  |
| `ATTACKWB_INSIGHTS_AGENT_SYSTEM_PROMPT_FILE` | `../../insights-agent/system-prompt.md` | Path to the mounted system prompt file      |

### REST API Custom SSL certs (Optional)

These will be used to set `NODE_EXTRA_CA_CERTS` in the REST API container and
to mount a custom CA file for the optional Grafana and insights-agent services.
See `compose.certs.yaml` for the REST API reference overlay.

| Variable          | Default Value      | Description                   |
|-------------------|--------------------|-------------------------------|
| `HOST_CERTS_PATH` | `./certs`          | Path to custom cert directory |
| `CERTS_FILENAME`  | `custom-certs.pem` | Filename of custom cert       |

### Database

| Variable                  | Default Value       | Description              |
|---------------------------|---------------------|--------------------------|
| `ATTACKWB_DB_PORT`        | `27017`             | MongoDB port             |
| `ATTACKWB_DB_BACKUP_PATH` | `./database-backup` | MongoDB backup directory |

### TAXII Server

| Variable                    | Default Value            | Description                                                                                                     |
|-----------------------------|--------------------------|-----------------------------------------------------------------------------------------------------------------|
| `ATTACKWB_TAXII_HTTP_PORT`  | `5002`                   | TAXII server port                                                                                               |
| `ATTACKWB_TAXII_CONFIG_DIR` | `./configs/taxii/config` | DIrectory to find TAXII config file in                                                                          |
| `ATTACKWB_TAXII_ENV`        | `dev`                    | Specifies the name of the dotenv file to load (e.g., A value of `dev` tells the TAXII server to load `dev.env`) |

## Service-Specific Configuration

Each service has its own configuration directory:

### Frontend

**Config files**: [configs/frontend/](../docker/example-setup/configs/frontend/)

The frontend container is an Nginx instance which serves the frontend SPA and reverse proxies requests to the backend REST API.
We provide a basic `nginx.conf` template in the aforementioned directory that should get you started.
Refer to the [frontend documentation](https://github.com/mitre-attack/attack-workbench-frontend)
for further details on customizing the Workbench frontend.

### REST API

**Config files**: [configs/rest-api/](../docker/example-setup/configs/rest-api/)

The backend REST API loads runtime configurations from environment variables, as well as from a JSON configuration file.
Templates are provided in the aforementioned directory.
Refer to the [REST API usage documentation](https://github.com/mitre-attack/attack-workbench-rest-api/blob/main/USAGE.md#configuration)
for further details on customizing the backend.

**Important**: For production deployments, set the following environment variables in your `.env` file to ensure persistent secrets across server restarts:

- `SESSION_SECRET` - Secret used to sign session cookies
- `MONGOSTORE_CRYPTO_SECRET` - Secret used to encrypt session data in MongoDB

Generate secure secrets using: `node -e "console.log(require('crypto').randomBytes(48).toString('base64'))"`

### Grafana

**Config files**: [configs/grafana/](../docker/example-setup/configs/grafana/)

The Grafana container loads runtime configuration from its own dotenv file.
The provisioning directory is mounted read-only so you can add datasources and
dashboard providers without modifying the compose template.

### Insights Agent

**Config files**: [configs/insights-agent/](../docker/example-setup/configs/insights-agent/)

The insights agent loads all runtime configuration from a dedicated dotenv file.
Set `MONGODB_DATABASE_URL` to the same connection string used by the REST API
and configure the LLM settings there.

The system prompt is loaded from a separate mounted file referenced by
`ATTACKWB_INSIGHTS_AGENT_SYSTEM_PROMPT_FILE`, so prompt changes do not require
rebuilding the insights-agent image.

### TAXII Server

**Config files**: [configs/taxii/config/](../docker/example-setup/configs/taxii/config/)

The TAXII server loads all runtime configuration parameters from a dotenv file.
The specific filename of the dotenv file is specified by the `ATTACKWB_TAXII_ENV` environment variable.
For example, a value of `dev` tells the TAXII server to load `dev.env`.
