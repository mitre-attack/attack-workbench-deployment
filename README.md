# ATT\&CK Workbench Deployment Guide

This repository provides a ready-to-use [Docker Compose](https://docs.docker.com/compose/) setup for deploying the [ATT\&CK Workbench](https://github.com/center-for-threat-informed-defense/attack-workbench-frontend) application and its related services.

---

## 🚀 Quick Start (Recommended)

1. **Clone the repository**:

   ```bash
   git clone https://github.com/mitre-attack/attack-workbench-deployment.git
   cd attack-workbench-deployment
   ```

2. **Configure environment variables**:

   ```bash
   cp configs/rest-api/template.env configs/rest-api/.env
   # (Optional) For TAXII support:
   cp configs/taxii/config/template.env configs/taxii/config/.env
   ```

3. **Start the Workbench application**:

   ```bash
   docker compose up -d
   ```

4. **(Optional) Start with TAXII server**:

   ```bash
   docker compose --profile with-taxii up -d
   ```

## 🧠 What Is This?

The ATT\&CK Workbench is composed of several services:

* A **Frontend UI**
* A **REST API backend**
* A **MongoDB** database
* An optional **TAXII 2.1 Server**

This repository lets you deploy all of them using Docker Compose. You can choose to:

* ✅ Use **published Docker images** (default and recommended)
* 🛠️ Or **build from source** (for development or customization)

## 🔄 Version Compatibility

The ATT&CK Workbench services are tied to specific versions of the ATT&CK Specification, maintained by the [ATT&CK Data Model](https://github.com/mitre-attack/attack-data-model). Each release of the Workbench frontend and REST API aligns with a major version of the ATT&CK Specification.

Please refer to the [COMPATIBILITY.md](./COMPATIBILITY.md) file for a complete compatibility matrix.

## 🧩 Deployment Options

### 1. **Using Published Docker Images** ✅

This is the default mode and best for most users. No need to clone or modify Workbench source code — the Compose file pulls prebuilt images directly from the GitHub Container Registry:

```yaml
services:
  rest-api:
    image: ghcr.io/center-for-threat-informed-defense/attack-workbench-rest-api:latest
```

### 2. **Building from Source** (Advanced)

If you want to customize or test unreleased changes, you can modify the `compose.yaml` to build images locally:

```yaml
services:
  rest-api:
    build: ../attack-workbench-rest-api
```

> **Note**: The provided Compose file is preconfigured for published images but can be adapted to support builds.

## ⚙️ Configuration

### REST API `.env`

Edit the `.env` file at `configs/rest-api/.env` to configure the backend.

Example:

```env
DATABASE_URL=mongodb://attack-workbench-database/attack-workspace
AUTHN_MECHANISM=anonymous
```

Optional: You can also provide a JSON config file and reference it via:

```env
JSON_CONFIG_PATH=configs/rest-api/rest-api-service-config.json
```

### TAXII Server (Optional)

The TAXII 2.1 server is an optional sidecar service to expose ATT\&CK data via the TAXII protocol.

1. Use `.env` files to configure the server:

   * `configs/taxii/config/.env` (default)
   * or use the `TAXII_ENV` variable to load `dev.env`, `prod.env`, etc.

2. Example environment config usage:

```env
TAXII_ENV=prod
```

3. If enabling HTTPS:

   * Provide PEM files:

     ```
     configs/taxii/config/private-key.pem
     configs/taxii/config/public-certificate.pem
     ```
   * OR base64-encode and set them via:

     ```env
     TAXII_SSL_PRIVATE_KEY=<base64>
     TAXII_SSL_PUBLIC_KEY=<base64>
     ```

## 🧪 Docker Compose Profiles

Use Compose profiles to include or exclude the optional TAXII service:

* With TAXII:

  ```bash
  docker compose --profile with-taxii up -d
  ```

* Without TAXII:

  ```bash
  docker compose up -d
  ```

The `with-taxii` profile is defined in [`docker-compose.yml`](./docker-compose.yml).

## 🧑‍💻 Contributing / Development

If you're working on ATT\&CK Workbench source code:

* Clone the relevant service repositories
* Modify the `compose.yaml` to build from local source (`build:` instead of `image:`)
* Use volume mounts for live reloading if needed


## 📎 Resources

* [ATT\&CK Workbench Frontend](https://github.com/center-for-threat-informed-defense/attack-workbench-frontend)
* [ATT\&CK REST API](https://github.com/center-for-threat-informed-defense/attack-workbench-rest-api)
* [ATT\&CK TAXII Server](https://github.com/mitre-attack/attack-workbench-taxii-server)
* [MongoDB Docker Image](https://hub.docker.com/_/mongo)
