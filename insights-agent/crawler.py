"""MongoDB schema crawler for ATT&CK Workbench databases.

Introspects the database, gathers collection stats, samples documents, and
computes domain-specific summaries that give an LLM enough context to design
useful Grafana dashboards.
"""

import logging
from collections import Counter

from pymongo import MongoClient
from pymongo.database import Database
from pymongo.uri_parser import parse_uri

log = logging.getLogger(__name__)

# STIX type → human-friendly label (for prompt readability)
STIX_TYPE_LABELS = {
    "attack-pattern": "Technique",
    "intrusion-set": "Group",
    "malware": "Software (Malware)",
    "tool": "Software (Tool)",
    "course-of-action": "Mitigation",
    "campaign": "Campaign",
    "x-mitre-tactic": "Tactic",
    "x-mitre-data-source": "Data Source",
    "x-mitre-data-component": "Data Component",
    "x-mitre-matrix": "Matrix",
    "x-mitre-collection": "Collection Bundle",
    "x-mitre-asset": "Asset",
    "x-mitre-analytic": "Analytic",
    "x-mitre-detection-strategy": "Detection Strategy",
    "note": "Note",
    "marking-definition": "Marking Definition",
    "identity": "Identity",
    "relationship": "Relationship",
}

ATTACK_DOMAINS = ["enterprise-attack", "mobile-attack", "ics-attack"]
WORKFLOW_STATES = ["work-in-progress", "awaiting-review", "reviewed", "static", "draft"]


def connect(uri: str, db_name: str = "attack-workspace") -> Database:
    client = MongoClient(uri)
    db = client[db_name]
    # Quick connectivity check
    db.command("ping")
    log.info("Connected to MongoDB: %s / %s", uri, db_name)
    return db


def get_database_name(database_url: str, default_name: str = "attack-workspace") -> str:
    """Return the database name embedded in a MongoDB URL, if any."""
    parsed = parse_uri(database_url)
    return parsed.get("database") or default_name


def _latest_versions_pipeline(match: dict | None = None) -> list[dict]:
    """Standard pipeline: group by stix.id, take latest stix.modified."""
    pipeline: list[dict] = []
    if match:
        pipeline.append({"$match": match})
    pipeline += [
        {"$sort": {"stix.modified": -1}},
        {"$group": {"_id": "$stix.id", "doc": {"$first": "$$ROOT"}}},
        {"$replaceRoot": {"newRoot": "$doc"}},
    ]
    return pipeline


def crawl(db: Database) -> dict:
    """Return a structured summary of the ATT&CK Workbench database.

    The output is designed to be serialised into an LLM prompt.
    """
    summary: dict = {}

    # ------------------------------------------------------------------
    # 1. Collection-level stats
    # ------------------------------------------------------------------
    collections = db.list_collection_names()
    col_stats = {}
    for name in sorted(collections):
        count = db[name].estimated_document_count()
        col_stats[name] = count
    summary["collections"] = col_stats

    # ------------------------------------------------------------------
    # 2. STIX object type distribution (latest versions only)
    # ------------------------------------------------------------------
    attack_objects = db["attackObjects"]
    type_counts: Counter = Counter()
    for doc in attack_objects.aggregate(
        _latest_versions_pipeline() + [{"$group": {"_id": "$stix.type", "count": {"$sum": 1}}}]
    ):
        stix_type = doc["_id"]
        label = STIX_TYPE_LABELS.get(stix_type, stix_type)
        type_counts[label] = doc["count"]

    # Include relationships from their dedicated collection
    if "relationships" in collections:
        rel_pipeline = _latest_versions_pipeline() + [{"$count": "total"}]
        rel_result = list(db["relationships"].aggregate(rel_pipeline))
        if rel_result:
            type_counts["Relationship"] = rel_result[0]["total"]

    summary["stix_type_distribution"] = dict(type_counts.most_common())

    # ------------------------------------------------------------------
    # 3. Domain distribution
    # ------------------------------------------------------------------
    domain_counts: Counter = Counter()
    for doc in attack_objects.aggregate(
        _latest_versions_pipeline()
        + [
            {"$unwind": {"path": "$stix.x_mitre_domains", "preserveNullAndEmptyArrays": False}},
            {"$group": {"_id": "$stix.x_mitre_domains", "count": {"$sum": 1}}},
        ]
    ):
        domain_counts[doc["_id"]] = doc["count"]
    summary["domain_distribution"] = dict(domain_counts.most_common())

    # ------------------------------------------------------------------
    # 4. Workflow state distribution
    # ------------------------------------------------------------------
    workflow_counts: Counter = Counter()
    for doc in attack_objects.aggregate(
        _latest_versions_pipeline()
        + [{"$group": {"_id": "$workspace.workflow.state", "count": {"$sum": 1}}}]
    ):
        state = doc["_id"] or "unset"
        workflow_counts[state] = doc["count"]
    summary["workflow_state_distribution"] = dict(workflow_counts.most_common())

    # ------------------------------------------------------------------
    # 5. Relationship type distribution
    # ------------------------------------------------------------------
    if "relationships" in collections:
        rel_type_counts: Counter = Counter()
        for doc in db["relationships"].aggregate(
            _latest_versions_pipeline()
            + [{"$group": {"_id": "$stix.relationship_type", "count": {"$sum": 1}}}]
        ):
            rel_type_counts[doc["_id"]] = doc["count"]
        summary["relationship_type_distribution"] = dict(rel_type_counts.most_common())

    # ------------------------------------------------------------------
    # 6. Platform coverage (techniques only)
    # ------------------------------------------------------------------
    platform_counts: Counter = Counter()
    for doc in attack_objects.aggregate(
        _latest_versions_pipeline({"stix.type": "attack-pattern"})
        + [
            {"$unwind": {"path": "$stix.x_mitre_platforms", "preserveNullAndEmptyArrays": False}},
            {"$group": {"_id": "$stix.x_mitre_platforms", "count": {"$sum": 1}}},
        ]
    ):
        platform_counts[doc["_id"]] = doc["count"]
    summary["technique_platform_coverage"] = dict(platform_counts.most_common())

    # ------------------------------------------------------------------
    # 7. Deprecated / revoked counts
    # ------------------------------------------------------------------
    deprecated = list(
        attack_objects.aggregate(
            _latest_versions_pipeline()
            + [
                {
                    "$group": {
                        "_id": None,
                        "deprecated": {
                            "$sum": {"$cond": [{"$eq": ["$stix.x_mitre_deprecated", True]}, 1, 0]}
                        },
                        "revoked": {
                            "$sum": {"$cond": [{"$eq": ["$stix.revoked", True]}, 1, 0]}
                        },
                        "total": {"$sum": 1},
                    }
                }
            ]
        )
    )
    if deprecated:
        d = deprecated[0]
        summary["object_health"] = {
            "total_latest_objects": d["total"],
            "deprecated": d["deprecated"],
            "revoked": d["revoked"],
            "active": d["total"] - d["deprecated"] - d["revoked"],
        }

    # ------------------------------------------------------------------
    # 8. Tactic → technique counts (kill-chain mapping)
    # ------------------------------------------------------------------
    tactic_technique: Counter = Counter()
    for doc in attack_objects.aggregate(
        _latest_versions_pipeline({"stix.type": "attack-pattern"})
        + [
            {"$unwind": "$stix.kill_chain_phases"},
            {"$group": {"_id": "$stix.kill_chain_phases.phase_name", "count": {"$sum": 1}}},
        ]
    ):
        tactic_technique[doc["_id"]] = doc["count"]
    summary["techniques_per_tactic"] = dict(tactic_technique.most_common())

    # ------------------------------------------------------------------
    # 9. Validation error counts
    # ------------------------------------------------------------------
    validation_errors: Counter = Counter()
    for doc in attack_objects.aggregate(
        _latest_versions_pipeline()
        + [
            {"$match": {"workspace.validation.errors": {"$exists": True, "$ne": []}}},
            {"$unwind": "$workspace.validation.errors"},
            {"$group": {"_id": "$workspace.validation.errors.field", "count": {"$sum": 1}}},
        ]
    ):
        validation_errors[doc["_id"]] = doc["count"]
    if validation_errors:
        summary["validation_error_hotspots"] = dict(validation_errors.most_common(20))

    # ------------------------------------------------------------------
    # 10. Version depth (how many historical versions per object)
    # ------------------------------------------------------------------
    version_depth = list(
        attack_objects.aggregate(
            [
                {"$group": {"_id": "$stix.id", "versions": {"$sum": 1}}},
                {
                    "$group": {
                        "_id": None,
                        "avg_versions": {"$avg": "$versions"},
                        "max_versions": {"$max": "$versions"},
                    }
                },
            ]
        )
    )
    if version_depth:
        v = version_depth[0]
        summary["version_depth"] = {
            "avg_versions_per_object": round(v["avg_versions"], 2),
            "max_versions": v["max_versions"],
        }

    # ------------------------------------------------------------------
    # 11. Sample documents (one per major STIX type, latest version)
    # ------------------------------------------------------------------
    samples = {}
    sample_types = ["attack-pattern", "intrusion-set", "malware", "relationship"]
    for stype in sample_types:
        col = db["relationships"] if stype == "relationship" else attack_objects
        doc = col.find_one(
            {"stix.type": stype},
            sort=[("stix.modified", -1)],
            projection={
                "_id": 0,
                "stix.type": 1,
                "stix.id": 1,
                "stix.name": 1,
                "stix.description": 1,
                "stix.x_mitre_domains": 1,
                "stix.kill_chain_phases": 1,
                "stix.relationship_type": 1,
                "stix.source_ref": 1,
                "stix.target_ref": 1,
                "workspace.attack_id": 1,
                "workspace.workflow.state": 1,
            },
        )
        if doc:
            samples[stype] = doc
    summary["sample_documents"] = samples

    return summary
