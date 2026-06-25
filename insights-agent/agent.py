"""LLM agent that generates Grafana dashboards from database insights.

Uses OpenAI-compatible chat completions with tool calling.  The agent receives
a structured database summary, reasons about what dashboards would be useful,
and creates them via Grafana API tool calls.
"""

import json
import logging
from pathlib import Path
from urllib.parse import parse_qs, urlsplit, urlunsplit

import httpx
from openai import AzureOpenAI, OpenAI

from grafana import GrafanaClient

log = logging.getLogger(__name__)

# ── Tool definitions (OpenAI function-calling format) ────────────────────────

TOOLS = [
    {
        "type": "function",
        "function": {
            "name": "upsert_dashboard",
            "description": (
                "Create or update a Grafana dashboard.  Provide the full Grafana "
                "dashboard JSON model (panels, title, uid, etc.).  The dashboard "
                "will be placed in the 'ATT&CK Insights' folder."
            ),
            "parameters": {
                "type": "object",
                "properties": {
                    "dashboard": {
                        "type": "object",
                        "description": "Complete Grafana dashboard JSON model.",
                    }
                },
                "required": ["dashboard"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "list_datasources",
            "description": "List all Grafana datasources.  Returns an array of datasource objects.",
            "parameters": {"type": "object", "properties": {}},
        },
    },
]


def _execute_tool_call(grafana: GrafanaClient, folder_uid: str, name: str, arguments: dict) -> str:
    """Execute a tool call and return the JSON result string."""
    if name == "upsert_dashboard":
        result = grafana.upsert_dashboard(arguments["dashboard"], folder_uid=folder_uid)
        return json.dumps(result)
    if name == "list_datasources":
        result = grafana.list_datasources()
        return json.dumps(result)
    return json.dumps({"error": f"Unknown tool: {name}"})


def _load_system_prompt(system_prompt_path: str | None) -> str:
    prompt_path = Path(system_prompt_path) if system_prompt_path else Path(__file__).with_name("system-prompt.md")
    prompt = prompt_path.read_text(encoding="utf-8").strip()
    if not prompt:
        raise ValueError(f"System prompt file is empty: {prompt_path}")
    log.info("Loaded system prompt from %s", prompt_path)
    return prompt


def _looks_like_azure_url(base_url: str) -> bool:
    split_url = urlsplit(base_url)
    query = parse_qs(split_url.query)
    path = split_url.path.rstrip("/")
    return "api-version" in query or "/openai/deployments/" in path or path.endswith("/openai")


def _build_azure_client_config(
    llm_base_url: str,
    llm_model: str,
    llm_api_version: str | None,
    llm_azure_deployment: str | None,
) -> tuple[str, str, str]:
    split_url = urlsplit(llm_base_url)
    path = split_url.path.rstrip("/")
    query = parse_qs(split_url.query)

    deployment = llm_azure_deployment
    endpoint_path = path
    if "/openai/deployments/" in path:
        endpoint_path, deployment_path = path.split("/openai/deployments/", 1)
        deployment_from_url = deployment_path.split("/", 1)[0]
        deployment = deployment or deployment_from_url
    elif path.endswith("/openai"):
        endpoint_path = path[: -len("/openai")]

    api_version = llm_api_version or next(iter(query.get("api-version", [])), None)
    if not api_version:
        raise ValueError(
            "Azure/OpenAI-compatible endpoints require LLM_API_VERSION or api-version in LLM_BASE_URL"
        )

    deployment = deployment or llm_model
    endpoint = urlunsplit((split_url.scheme, split_url.netloc, endpoint_path, "", ""))
    return endpoint, api_version, deployment


def _build_llm_client(
    llm_base_url: str,
    llm_api_key: str,
    llm_model: str,
    llm_api_type: str,
    llm_api_version: str | None,
    llm_azure_deployment: str | None,
    ca_bundle_path: str,
) -> tuple[OpenAI | AzureOpenAI, httpx.Client, str]:
    http_client = httpx.Client(verify=ca_bundle_path)
    api_type = llm_api_type.lower()
    use_azure = api_type == "azure" or (api_type == "auto" and _looks_like_azure_url(llm_base_url))

    if use_azure:
        endpoint, api_version, deployment = _build_azure_client_config(
            llm_base_url=llm_base_url,
            llm_model=llm_model,
            llm_api_version=llm_api_version,
            llm_azure_deployment=llm_azure_deployment,
        )
        log.info(
            "Using Azure-compatible chat completions endpoint: endpoint=%s deployment=%s api_version=%s",
            endpoint,
            deployment,
            api_version,
        )
        client = AzureOpenAI(
            api_key=llm_api_key,
            api_version=api_version,
            azure_endpoint=endpoint,
            http_client=http_client,
        )
        return client, http_client, deployment

    log.info("Using OpenAI-compatible chat completions endpoint: base_url=%s model=%s", llm_base_url, llm_model)
    client = OpenAI(base_url=llm_base_url, api_key=llm_api_key, http_client=http_client)
    return client, http_client, llm_model


def run(
    llm_base_url: str,
    llm_api_key: str,
    llm_model: str,
    llm_api_type: str,
    llm_api_version: str | None,
    llm_azure_deployment: str | None,
    system_prompt_path: str | None,
    grafana: GrafanaClient,
    db_summary: dict,
    ca_bundle_path: str,
) -> str:
    """Run the agent loop: prompt LLM → handle tool calls → return summary."""

    client, http_client, request_model = _build_llm_client(
        llm_base_url=llm_base_url,
        llm_api_key=llm_api_key,
        llm_model=llm_model,
        llm_api_type=llm_api_type,
        llm_api_version=llm_api_version,
        llm_azure_deployment=llm_azure_deployment,
        ca_bundle_path=ca_bundle_path,
    )

    try:
        system_prompt = _load_system_prompt(system_prompt_path)

        # Ensure the target folder exists
        folder = grafana.ensure_folder("ATT&CK Insights", uid="attack-insights")
        folder_uid = folder["uid"]

        # Build the user message with the crawl data
        user_message = (
            "Here is the structured summary of the ATT&CK Workbench database.  "
            "Analyse it and create Grafana dashboards that would be most useful "
            "to ATT&CK content authors.\n\n"
            f"```json\n{json.dumps(db_summary, indent=2, default=str)}\n```"
        )

        messages = [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_message},
        ]

        # Agent loop — keep going until the LLM stops making tool calls
        max_iterations = 20
        for i in range(max_iterations):
            log.info("Agent iteration %d/%d", i + 1, max_iterations)

            response = client.chat.completions.create(
                model=request_model,
                messages=messages,
                tools=TOOLS,
                tool_choice="auto",
            )

            choice = response.choices[0]
            assistant_msg = choice.message

            # Append assistant message to history
            messages.append(assistant_msg.model_dump(exclude_none=True))

            # If no tool calls, the agent is done
            if not assistant_msg.tool_calls:
                log.info("Agent finished with text response")
                return assistant_msg.content or "(no summary)"

            # Process each tool call
            for tc in assistant_msg.tool_calls:
                fn_name = tc.function.name
                fn_args = json.loads(tc.function.arguments)
                log.info("Tool call: %s", fn_name)

                try:
                    result = _execute_tool_call(grafana, folder_uid, fn_name, fn_args)
                except Exception as e:
                    log.error("Tool call %s failed: %s", fn_name, e)
                    result = json.dumps({"error": str(e)})

                messages.append(
                    {
                        "role": "tool",
                        "tool_call_id": tc.id,
                        "content": result,
                    }
                )

        return "Agent reached maximum iterations without finishing."
    finally:
        http_client.close()
