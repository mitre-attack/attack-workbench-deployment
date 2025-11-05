# PKI Certificates for Zero-Trust Environments

## Overview

In certain deployment environments (particularly those with SSL inspection or deep packet inspection proxies such as **ZScaler**)
the ATT&CK Workbench may need to trust custom Certificate Authorities (CA) in order to retrieve data from external services like remote collection indexes or STIX bundles.

This guide explains how to add your own PKI certificate to the Workbench deployment.

## Step-by-Step Instructions

### 1. Place Your Certificate

Copy your `.pem` or `.crt` file into the `certs/` directory of this repository:

````sh
attack-workbench-deployment/certs/foobar.pem
````

### 2. Edit `compose.certs.yaml`

Update the environment variables to point to your certificate:

```yaml
# compose.certs.yaml (excerpt)

services:
  rest-api:
    volumes:
      - ./certs:/usr/src/app/certs
    environment:
      - NODE_EXTRA_CA_CERTS=./certs/<your-cert-filename.pem>
````

If you're using environment variables in your shell, you can use:

```yaml
volumes:
  - .${HOST_CERTS_PATH}:/usr/src/app/certs
environment:
  - NODE_EXTRA_CA_CERTS=./certs/${CERTS_FILENAME}
```

### 3. Run Docker Compose with Custom Cert Support

To start the stack with the additional certificate configuration:

```bash
docker compose -f compose.yaml -f compose.certs.yaml up -d
```

This will mount your certificate into the container and configure the Node.js environment (`NODE_EXTRA_CA_CERTS`) to trust it.

## Notes

* This method **only applies to the REST API container**. If your frontend or TAXII services also need custom CA bundles, additional changes will be required.
* This solution is recommended when:

  * You're behind a corporate firewall performing SSL inspection.
  * Remote resources (e.g., Collection Indexes) are served with certificates signed by an internal CA.

## Example Directory Structure

```sh
attack-workbench-deployment/
├── compose.yaml
├── compose.certs.yaml
├── certs/
│   └── zscaler-ca.pem
```

## Need Help?

Please [open an issue](https://github.com/mitre-attack/attack-workbench-deployment/issues) or contact [attack@mitre.org](mailto:attack@mitre.org) if you run into problems.
