# GitHub Organization Transfer Guide

The ATT&CK Workbench frontend and REST API repositories are moving from the
`center-for-threat-informed-defense` GitHub organization to the `mitre-attack`
GitHub organization.

This guide is for users of the ATT&CK Workbench repositories or prebuilt Docker
images. If you have local Git clones, forks, scripts, documentation, Docker
Compose files, or other deployment files that reference the old organization,
update them after the transfer.

## Confirmed Changes

- The new GitHub organization is `mitre-attack`.
- The repository names are unchanged:
  - `attack-workbench-frontend`
  - `attack-workbench-rest-api`
- New GitHub Container Registry images will use the `mitre-attack` namespace.
- The new GHCR images might not be available immediately after the repository
  transfer. They will become available after the GitHub Actions publishing
  workflows have completed.

## Repository URLs

Old repository URLs:

```text
https://github.com/center-for-threat-informed-defense/attack-workbench-frontend
https://github.com/center-for-threat-informed-defense/attack-workbench-rest-api
```

New repository URLs:

```text
https://github.com/mitre-attack/attack-workbench-frontend
https://github.com/mitre-attack/attack-workbench-rest-api
```

GitHub redirects transferred repositories, including `git clone`, `git fetch`,
and `git push`, but you should update local clones so your configuration uses
the new canonical repository location.

To update local clones, run the command for the repository you are using:

```bash
# Frontend, SSH
git remote set-url origin git@github.com:mitre-attack/attack-workbench-frontend.git

# Frontend, HTTPS
git remote set-url origin https://github.com/mitre-attack/attack-workbench-frontend.git

# REST API, SSH
git remote set-url origin git@github.com:mitre-attack/attack-workbench-rest-api.git

# REST API, HTTPS
git remote set-url origin https://github.com/mitre-attack/attack-workbench-rest-api.git

# Confirm the configured remote
git remote -v
```

If you maintain a fork, update your `upstream` remote too:

```bash
# Frontend fork
git remote set-url upstream https://github.com/mitre-attack/attack-workbench-frontend.git

# REST API fork
git remote set-url upstream https://github.com/mitre-attack/attack-workbench-rest-api.git
```

## Container Image Paths

Old GHCR image paths:

```text
ghcr.io/center-for-threat-informed-defense/attack-workbench-frontend
ghcr.io/center-for-threat-informed-defense/attack-workbench-rest-api
```

New GHCR image paths:

```text
ghcr.io/mitre-attack/attack-workbench-frontend
ghcr.io/mitre-attack/attack-workbench-rest-api
```

If you deploy ATT&CK Workbench with prebuilt images, update your Docker or
Docker Compose configuration to use the new image paths.

```yaml
services:
  frontend:
    image: ghcr.io/mitre-attack/attack-workbench-frontend:latest

  rest-api:
    image: ghcr.io/mitre-attack/attack-workbench-rest-api:latest
```

If you pin image versions by tag, keep the tag and update only the namespace:

```text
ghcr.io/mitre-attack/attack-workbench-frontend:vX.Y.Z
ghcr.io/mitre-attack/attack-workbench-rest-api:vX.Y.Z
```

After changing image paths, pull the new images and restart your Docker Compose
deployment:

```bash
docker compose pull
docker compose up -d
```

If the new images are not available yet, wait for the repository's GitHub
Actions release and publishing workflows to finish, then pull again.

## Files To Check

Search only for ATT&CK Workbench repository and image references, especially if
you also use other projects from the Center for Threat-Informed Defense
organization that are not moving.

```bash
grep -R "center-for-threat-informed-defense/attack-workbench-frontend" .
grep -R "center-for-threat-informed-defense/attack-workbench-rest-api" .
grep -R "ghcr.io/center-for-threat-informed-defense/attack-workbench" .
```

Common places to update:

- local Git remotes
- fork `upstream` remotes
- README files and setup notes
- Docker Compose files
- shell scripts
- deployment documentation
- internal wiki pages
- bookmarks

## Deployment Guidance

For current Workbench deployment examples, use the actively maintained
[mitre-attack/attack-workbench-deployment](https://github.com/mitre-attack/attack-workbench-deployment)
repository. That repository is being updated to account for the GitHub
organization transfer.
