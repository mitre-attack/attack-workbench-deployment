"""ATT&CK Workbench Insights Agent — entrypoint.

Crawls the MongoDB database, feeds a structured summary to an LLM, and creates
Grafana dashboards via tool-calling.

Configuration is via environment variables:
    MONGODB_DATABASE_URL – MongoDB URL with database name (preferred)
    MONGODB_URI          – MongoDB connection string (default: mongodb://mongodb:27017)
    MONGODB_DATABASE     – Database name            (default: attack-workspace)
    GRAFANA_URL          – Grafana base URL          (default: http://grafana:3000)
    GRAFANA_API_KEY      – Grafana service account token (optional for anonymous/admin)
    LLM_BASE_URL         – OpenAI base URL or Azure endpoint / request URL (required)
    LLM_API_KEY          – API key for the LLM       (required)
    LLM_API_TYPE         – openai | azure | auto      (default: auto)
    LLM_API_VERSION      – Azure API version override (optional)
    LLM_AZURE_DEPLOYMENT – Azure deployment override  (optional)
    LLM_MODEL            – Model identifier / Azure deployment fallback (default: gpt-4o)
    SYSTEM_PROMPT_PATH   – Optional path to the system prompt file
    RUN_INTERVAL_SECONDS – Re-run interval; 0 = run once and exit (default: 0)
"""

import logging
import os
import sys
import time

import agent
import crawler
from grafana import GrafanaClient
from tls import configure_runtime_ca_bundle

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(name)s] %(levelname)s %(message)s",
    stream=sys.stdout,
)
log = logging.getLogger("insights-agent")


def main() -> None:
    # ── Required config ──────────────────────────────────────────────────
    llm_base_url = os.environ.get("LLM_BASE_URL")
    llm_api_key = os.environ.get("LLM_API_KEY")
    if not llm_base_url or not llm_api_key:
        log.error("LLM_BASE_URL and LLM_API_KEY must be set")
        sys.exit(1)

    # ── Optional config with defaults ────────────────────────────────────
    mongodb_database_url = os.environ.get("MONGODB_DATABASE_URL")
    mongodb_uri = os.environ.get("MONGODB_URI", "mongodb://mongodb:27017")
    mongodb_database = os.environ.get("MONGODB_DATABASE", "attack-workspace")
    grafana_url = os.environ.get("GRAFANA_URL", "http://grafana:3000")
    grafana_api_key = os.environ.get("GRAFANA_API_KEY")
    grafana_admin_user = os.environ.get("GRAFANA_ADMIN_USER", "admin")
    grafana_admin_password = os.environ.get("GRAFANA_ADMIN_PASSWORD", "admin")
    llm_model = os.environ.get("LLM_MODEL", "gpt-4o")
    llm_api_type = os.environ.get("LLM_API_TYPE", "auto")
    llm_api_version = os.environ.get("LLM_API_VERSION")
    llm_azure_deployment = os.environ.get("LLM_AZURE_DEPLOYMENT")
    system_prompt_path = os.environ.get("SYSTEM_PROMPT_PATH")
    run_interval = int(os.environ.get("RUN_INTERVAL_SECONDS", "0"))
    custom_ca_path = os.environ.get("ATTACKWB_CUSTOM_CA_CERT")
    runtime_ca_bundle = configure_runtime_ca_bundle(custom_ca_path)
    if mongodb_database_url:
        mongodb_uri = mongodb_database_url
        mongodb_database = crawler.get_database_name(mongodb_database_url, default_name=mongodb_database)

    log.info("Configuration:")
    log.info("  MongoDB:  %s / %s", mongodb_uri, mongodb_database)
    log.info("  Grafana:  %s", grafana_url)
    log.info("  LLM:      %s @ %s", llm_model, llm_base_url)
    log.info("  LLM API:  %s", llm_api_type)
    if llm_api_version:
        log.info("  LLM Ver:  %s", llm_api_version)
    if llm_azure_deployment:
        log.info("  LLM Dep:  %s", llm_azure_deployment)
    if system_prompt_path:
        log.info("  Prompt:   %s", system_prompt_path)
    log.info("  Interval: %s", f"{run_interval}s" if run_interval else "once")
    log.info("  CA certs: %s", runtime_ca_bundle)

    # ── Connect to dependencies ──────────────────────────────────────────
    grafana = GrafanaClient(
        grafana_url,
        api_key=grafana_api_key,
        admin_user=grafana_admin_user,
        admin_password=grafana_admin_password,
    )
    grafana.wait_until_ready()

    db = crawler.connect(mongodb_uri, mongodb_database)

    # ── Run loop ─────────────────────────────────────────────────────────
    while True:
        log.info("Starting database crawl …")
        summary = crawler.crawl(db)
        log.info(
            "Crawl complete: %d object types, %d total latest objects",
            len(summary.get("stix_type_distribution", {})),
            summary.get("object_health", {}).get("total_latest_objects", "?"),
        )

        log.info("Running LLM agent …")
        result = agent.run(
            llm_base_url=llm_base_url,
            llm_api_key=llm_api_key,
            llm_model=llm_model,
            llm_api_type=llm_api_type,
            llm_api_version=llm_api_version,
            llm_azure_deployment=llm_azure_deployment,
            system_prompt_path=system_prompt_path,
            grafana=grafana,
            db_summary=summary,
            ca_bundle_path=runtime_ca_bundle,
        )
        log.info("Agent result:\n%s", result)

        if run_interval <= 0:
            log.info("Single run complete. Exiting.")
            break

        log.info("Sleeping %ds before next run …", run_interval)
        time.sleep(run_interval)


if __name__ == "__main__":
    main()
