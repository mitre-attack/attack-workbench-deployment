"""Grafana HTTP API client for dashboard CRUD."""

import json
import logging
import time

import requests

log = logging.getLogger(__name__)


class GrafanaClient:
    """Thin wrapper around the Grafana HTTP API for dashboard management."""

    def __init__(
        self,
        base_url: str,
        api_key: str | None = None,
        admin_user: str | None = None,
        admin_password: str | None = None,
    ):
        self.base_url = base_url.rstrip("/")
        self.session = requests.Session()
        if api_key:
            self.session.headers["Authorization"] = f"Bearer {api_key}"
        elif admin_user and admin_password:
            self.session.auth = (admin_user, admin_password)

    # ------------------------------------------------------------------
    # Health
    # ------------------------------------------------------------------

    def wait_until_ready(self, timeout: int = 120, interval: int = 5) -> None:
        """Block until Grafana responds to health checks."""
        deadline = time.time() + timeout
        while time.time() < deadline:
            try:
                r = self.session.get(f"{self.base_url}/api/health", timeout=5)
                if r.ok:
                    log.info("Grafana is ready")
                    return
            except requests.ConnectionError:
                pass
            log.info("Waiting for Grafana …")
            time.sleep(interval)
        raise TimeoutError(f"Grafana not ready after {timeout}s")

    # ------------------------------------------------------------------
    # Datasources
    # ------------------------------------------------------------------

    def list_datasources(self) -> list[dict]:
        r = self.session.get(f"{self.base_url}/api/datasources")
        r.raise_for_status()
        return r.json()

    def get_datasource_by_name(self, name: str) -> dict | None:
        for ds in self.list_datasources():
            if ds["name"] == name:
                return ds
        return None

    # ------------------------------------------------------------------
    # Folders
    # ------------------------------------------------------------------

    def ensure_folder(self, title: str, uid: str | None = None) -> dict:
        """Return existing folder or create a new one."""
        r = self.session.get(f"{self.base_url}/api/folders")
        r.raise_for_status()
        for f in r.json():
            if f["title"] == title:
                return f
        payload = {"title": title}
        if uid:
            payload["uid"] = uid
        r = self.session.post(f"{self.base_url}/api/folders", json=payload)
        r.raise_for_status()
        return r.json()

    # ------------------------------------------------------------------
    # Dashboards
    # ------------------------------------------------------------------

    def search_dashboards(self, query: str = "", folder_id: int | None = None) -> list[dict]:
        params: dict = {"query": query}
        if folder_id is not None:
            params["folderIds"] = folder_id
        r = self.session.get(f"{self.base_url}/api/search", params=params)
        r.raise_for_status()
        return r.json()

    def get_dashboard(self, uid: str) -> dict | None:
        r = self.session.get(f"{self.base_url}/api/dashboards/uid/{uid}")
        if r.status_code == 404:
            return None
        r.raise_for_status()
        return r.json()

    def upsert_dashboard(self, dashboard_json: dict, folder_uid: str | None = None) -> dict:
        """Create or update a dashboard.

        ``dashboard_json`` is the *inner* dashboard model (with panels, title, etc.).
        The wrapper envelope (folderUid, overwrite) is added here.
        """
        payload: dict = {
            "dashboard": dashboard_json,
            "overwrite": True,
        }
        if folder_uid:
            payload["folderUid"] = folder_uid
        r = self.session.post(f"{self.base_url}/api/dashboards/db", json=payload)
        r.raise_for_status()
        result = r.json()
        log.info("Upserted dashboard %s → %s", dashboard_json.get("title"), result.get("url"))
        return result

    def delete_dashboard(self, uid: str) -> bool:
        r = self.session.delete(f"{self.base_url}/api/dashboards/uid/{uid}")
        return r.ok
