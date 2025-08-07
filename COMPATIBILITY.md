# Compatibility

This document outlines the version compatibility between different components of the ATT&CK Workbench system and the ATT&CK Specification governed by the [ATT&CK Data Model](https://github.com/mitre-attack/attack-data-model).

## Compatibility Matrix

| Workbench Frontend Version | REST API Version | TAXII Server Version | ATT&CK Specification Version | Notes                                                                 |
|----------------------------|------------------|-----------------------|------------------------------|-----------------------------------------------------------------------|
| 3.x                      | 3.x            | 1.x                   | 3.2.0                        | All 3.x versions are pinned to ATT&CK Spec v3.2.0.                 |
| 4.x (upcoming)             | 4.x (upcoming)   | TBD                   | 3.3.0                        | Planned major release to align with ATT&CK Spec v3.3.0.              |
| 5.x (future)             | 5.x (future)   | TBD                   | 4.0.0                        | Planned major release to align with ATT&CK Spec v4.0.0.              |

> **Note:** The Workbench frontend and REST API are tightly coupled by **major version**. Minor and patch versions may diverge but remain interoperable.

## Versioning Philosophy

- **Frontend & REST API**:
  - Always share the same **major version**, aligning with a major release of the ATT&CK Specification.
  - Minor and patch versions may differ but are tested for cross-compatibility.

- **TAXII Server**:
  - Released and maintained independently.
  - Not guaranteed to match the Workbench versioning scheme, but compatible when used with the same ATT&CK Spec version.

## Specification Mapping

- **ATT&CK Specification v3.3.0**:
  - Supported by Workbench v4.x.
  - Introduces support for:
    - Detection Strategies (`x-mitre-detection-strategy`)
    - Analytics (`x-mitre-analytic`)
    - Log Sources (`x-mitre-log-source`)
  - DEPRECATES<br>*(will be removed in Workbench v4.x)*:
    - Data Sources (`x-mitre-data-sources`).
      Data Components (`x-mitre-data-sources`)
    - Relationships between Techniques and Data Components

- **ATT&CK Specification v4.0.0** *(upcoming)*:
  - Will be supported in Workbench v5.x.
  - REMOVES:
    - Data Sources (`x-mitre-data-sources`)
      Data Components (`x-mitre-data-sources`)
    - Relationships between Techniques and Data Components

## Recommendations

- Use the latest stable version of Workbench (`v3.x`) for full compatibility with the ATT&CK Specification v3.2.0 (*i.e.*, to continue using Data Sources and Data Components).
- Use the latest stable version of Workbench (`v4.x`) for full compatibility with the ATT&CK Specification v3.3.0 (*i.e.*, to use Detection Strategies, Analytics, and Log Sources, with continued support for Data Sources and Data Components).
- Use the latest stable version of Workbench (`v5.x`) for full compatibility with the ATT&CK Specification v4.0.0 (*i.e.*, to exclusively use Detection Strategies, Analytics, and Log Sources).
- Avoid mixing major versions of the frontend and REST API.
- [Confirm that your ATT&CK dataset aligns with the ATT&CK Specification version expected by your Workbench version.](https://github.com/mitre-attack/attack-data-model/blob/main/docs/COMPATIBILITY.md)

## Contributing to Compatibility

To propose compatibility updates or report mismatches:
- [Open an issue](https://github.com/mitre-attack/attack-workbench-deployment/issues)
- Or reach out to the maintainers via [attack@mitre.org](mailto:attack@mitre.org)

---

© 2020–2025 The MITRE Corporation.  
This project makes use of ATT&CK®.  
[ATT&CK Terms of Use](https://attack.mitre.org/resources/terms-of-use/)
