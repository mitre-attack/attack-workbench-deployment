# TAXII resources

`config/` gets volume-mounted (read-only) to `/app/config/` on the TAXII server at runtime. It is intended to store the following:
- dotenv configuration files, e.g., `dev.env`, `prod.env`
- SSL/TLS certificate files
  - `config/private-key.pem` should contain the private key
  - `config/public-certificate.pem` should contain the public key