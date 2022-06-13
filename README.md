# ATT&CK Workbench Deployment

This repository contains Docker templates and helper files to assist with the initialization of the ATT&CK Workbench.

## TAXII 2.1 Server

This section pertains to `docker-compose.taxii.yml`.

This Docker Compose template adds two containers in addition to what is already included in `docker-compose.yml`:
- [taxii-server](https://github.com/mitre-attack/attack-workbench-taxii-server)
- taxii-server-cache (_optional_)

The _taxii-server-cache_ container is an optional add-on that allows the TAXII server to use an instance of `memcached` as opposed to 
an in-memory cache. If you prefer to use the in-memory cache, just delete or comment-out the appropriate lines in 
the template.

The TAXII server requires at least one `dotenv` configuration file at runtime. This file will be volume-mounted to the 
container. On the Docker host, place the dotenv file in `resources/taxii/config/` and ensure that `TAXII_ENV` can be read 
by the Docker Compose template, as this environment variable will determine the name of the `dotenv` that the TAXII 
application will search for. For example:
- setting `TAXII_ENV=dev` would force the server to attempt to load `resources/taxii/config/dev.env`
- setting `TAXII_ENV=prod` would force the server to attempt to load `resources/taxii/config/prod.env`
- **not** setting `TAXII_ENV` would force the server to attempt to load `resources/taxii/config/.env`

A dotenv [template](./resources/taxii/config/template.env) is included to help you started.

Additionally, if the TAXII server is configured to enable HTTPS, then two `pem` files are required:
- `resources/taxii/config/private-key.pem`
- `resources/taxii/config/public-certificate.pem`

Alternatively, if you prefer to use environment variables over static `pem` files, you can base64 encode the `pem` files 
and set them via `TAXII_SSL_PRIVATE_KEY` and `TAXII_SSL_PUBLIC_KEY` in your dotenv file. 

### Getting Started
To start the Docker Compose:

1. Set `TAXII_ENV` on the host where Docker Compose is running.
```shell
export TAXII_ENV=dev
```

2. Execute the docker-compose command, taking care to specify the correct template using the `-f` flag, and taking care 
to specify the appropriate dotenv file using the `--env-file` flag.
```shell
docker-compose -f docker-compose.taxii.yml --env-file resources/taxii/config/${TAXII_ENV}.env up
```

To stop the Docker Compose:
```shell
docker-compose -f docker-compose.taxii.yml --env-file resources/taxii/config/${TAXII_ENV}.env down
```
