"""Runtime TLS helpers for outbound HTTPS clients."""

import logging
import os
import re
from pathlib import Path

import certifi

log = logging.getLogger(__name__)

_PEM_CERT_PATTERN = re.compile(
    r"-----BEGIN CERTIFICATE-----.*?-----END CERTIFICATE-----",
    re.DOTALL,
)


def configure_runtime_ca_bundle(
    custom_ca_path: str | None,
    output_path: str | None = None,
) -> str:
    """Create a CA bundle that combines public roots with optional custom CAs."""

    base_bundle_path = Path(certifi.where())
    runtime_bundle_path = Path(
        output_path or os.environ.get("ATTACKWB_RUNTIME_CA_BUNDLE", "/tmp/attackwb-ca-bundle.crt")
    )
    runtime_bundle_path.parent.mkdir(parents=True, exist_ok=True)
    runtime_bundle_path.write_bytes(base_bundle_path.read_bytes())

    if custom_ca_path:
        _append_custom_certificates(Path(custom_ca_path), runtime_bundle_path)

    bundle_path = str(runtime_bundle_path)
    for env_var in ("SSL_CERT_FILE", "REQUESTS_CA_BUNDLE", "CURL_CA_BUNDLE", "PIP_CERT"):
        os.environ[env_var] = bundle_path

    return bundle_path


def _append_custom_certificates(source_path: Path, bundle_path: Path) -> None:
    if not source_path.exists():
        log.warning("Custom CA file %s does not exist; using default trust store only", source_path)
        return

    pem_blocks = _PEM_CERT_PATTERN.findall(source_path.read_text(encoding="utf-8", errors="ignore"))
    if not pem_blocks:
        log.warning(
            "Custom CA file %s did not contain PEM certificates; using default trust store only",
            source_path,
        )
        return

    with bundle_path.open("a", encoding="utf-8") as bundle_file:
        bundle_file.write("\n")
        bundle_file.write("\n".join(pem_blocks))
        bundle_file.write("\n")

    log.info("Appended %d custom certificate(s) from %s", len(pem_blocks), source_path)
