# ATT&CK Workbench Deployment

This repository contains Docker Compose templates and helper files to assist with the initialization of the ATT&CK Workbench.

## Getting Started

1. Clone this repository:
   ```
   git clone https://github.com/your-repo/attack-workbench-deployment.git
   cd attack-workbench-deployment
   ```

2. Create the required configuration files:
   - `configs/rest-api/.env`: Define environment variables for the REST API service.
   - `configs/taxii/config/.env`: Define environment variables for the TAXII server service (if included).

   Configuration templates are provided for the REST API and TAXII 2.1 servers:
   ```bash
   cp configs/rest-api/template.env configs/rest-api/.env
   cp configs/taxii/config/template.env configs/taxii/config/.env
   ```

3. Start the Docker Compose services:
   - To include the TAXII server, run:
     ```
     docker-compose --profile with-taxii up -d
     ```
   - To exclude the TAXII server, run:
     ```
     docker-compose up -d
     ```

## Configuration

### ATT&CK Workbench REST API

The REST API service is configured using environment variables defined in the `configs/rest-api/.env` file. Here's an example:

```
# configs/rest-api/.env
DATABASE_URL=mongodb://attack-workbench-database/attack-workspace
AUTHN_MECHANISM=anonymous
```

Additionally, an optional JSON configuration file can be used by setting the `JSON_CONFIG_PATH` environment variable to point to `configs/rest-api/rest-api-service-config.json`.

### ATT&CK Workbench TAXII 2.1 Server

The ATT&CK Workbench TAXII 2.1 API is an optional extension of the ATT&CK Workbench. It is defined in the `taxii` service of the included [Docker Compose template](./docker-compose.yml).

The TAXII server requires at least one `.env` configuration file at runtime. This file will be volume-mounted to the container. On the Docker host, place the `.env` file in `configs/taxii/config/`.

The `TAXII_ENV` environment variable determines the name of the `.env` file that the TAXII application will load. For example:
- `TAXII_ENV=dev` will load `configs/taxii/config/dev.env`
- `TAXII_ENV=prod` will load `configs/taxii/config/prod.env`
- If `TAXII_ENV` is not set, it will load `configs/taxii/config/.env`

A `.env` [template](./configs/taxii/config/template.env) is included to help you get started.

Additionally, if the TAXII server is configured to use HTTPS, you'll need to provide the following files:
- `configs/taxii/config/private-key.pem`
- `configs/taxii/config/public-certificate.pem`

Alternatively, you can base64 encode the `pem` files and set them via `TAXII_SSL_PRIVATE_KEY` and `TAXII_SSL_PUBLIC_KEY` in your `.env` file.

## Using Docker Compose Profiles

This repository includes a Docker Compose profile to optionally include or exclude the TAXII server service.

- To include the TAXII server, use the `with-taxii` profile:
  ```
  docker-compose --profile with-taxii up -d
  ```

- To exclude the TAXII server, run Docker Compose without any profile:
  ```
  docker-compose up -d
  ```

The `with-taxii` profile is defined in the `docker-compose.yml` file and includes the `taxii` service.