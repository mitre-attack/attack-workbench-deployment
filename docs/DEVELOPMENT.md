# ATT&CK Workbench Development Process

## Overview

This document outlines the development and release process for the ATT&CK Workbench ecosystem, including branch management, release channels, and deployment strategies.

## Scope

This process applies to all ATT&CK Workbench ecosystem projects:

- [ATT&CK Workbench Frontend](https://github.com/center-for-threat-informed-defense/attack-workbench-frontend)
- [ATT&CK Workbench REST API](https://github.com/center-for-threat-informed-defense/attack-workbench-rest-api)
- [ATT&CK Workbench TAXII 2.1 Server](https://github.com/mitre-attack/attack-workbench-taxii-server)
- [ATT&CK Data Model](https://github.com/mitre-attack/attack-data-model)

## Release Management

### Semantic Versioning

We strictly follow [Semantic Versioning](https://semver.org/) (MAJOR.MINOR.PATCH):

- **MAJOR**: Breaking changes
- **MINOR**: New features (backwards compatible)
- **PATCH**: Bug fixes

### Automated Releases

- **Tool**: [Semantic Release](https://semantic-release.gitbook.io/) automates version management and package publishing
- **Artifacts**:
  - Docker images published to GitHub Container Registry (ghcr.io)
  - NPM packages published to the [official npm registry](https://npmjs.com)
- **Triggers**: Releases are triggered by commits to stable branches following conventional commit format

### Semantic Release Plugins

The default semantic-release configuration includes:

1. `@semantic-release/commit-analyzer` - Analyzes commits to determine version bump
2. `@semantic-release/release-notes-generator` - Generates changelog
3. `@semantic-release/npm` - Updates package.json and publishes to registry
4. `@semantic-release/github` - Creates GitHub releases and tags
5. `@semantic-release/exec` - Executes Docker build and push commands

## Branch Strategy

### Stable Branches

These branches are guaranteed to compile, run, and be deployable via Docker:

| Branch       | Version | Purpose                                  | Deployment Target          |
|--------------|---------|------------------------------------------|----------------------------|
| `main`       | 4.0.0   | Production-ready releases                | Production, Pre-Production |
| `next`       | 4.1.0   | Upcoming minor releases                  | Pre-Production             |
| `next-major` | 5.x     | Breaking changes & experimental features | Preview                    |

### Unstable Branches (Pre-release Channels)

Each stable branch has corresponding pre-release channels for testing:

| Stable Branch | Alpha Channel      | Beta Channel      | Purpose              |
|---------------|--------------------|-------------------|----------------------|
| `main`        | `alpha`            | `beta`            | Hotfix testing       |
| `next`        | `next-alpha`       | `next-beta`       | Feature testing      |
| `next-major`  | `next-major-alpha` | `next-major-beta` | Experimental testing |

## Development Workflow

| Change Type                         | Target Branch                                         | Example                        |
|-------------------------------------|-------------------------------------------------------|--------------------------------|
| **Hotfixes**                        | `alpha` → `beta` → `main`                             | Critical bug fixes             |
| **Features** (backwards compatible) | `next-alpha` → `next-beta` → `next`                   | New endpoints, UI components   |
| **Breaking Changes**                | `next-major-alpha` → `next-major-beta` → `next-major` | API redesigns, major refactors |

### Release Flow

1. **Development**: Features developed in feature branches
2. **Pre-release Testing**: Merged to alpha channel for initial testing
3. **Beta Testing**: Promoted to beta channel for wider testing
4. **Stable Release**: Merged to stable branch, triggering automatic release
5. **Deployment**: Docker images deployed to appropriate environments

## CI/CD Pipeline

The CI/CD pipeline automatically:

1. Runs tests on all pull requests
2. Executes semantic-release on commits to stable branches
3. Builds and publishes Docker images to ghcr.io
4. Tags releases in GitHub

## Code Quality Standards

### Linting & Formatting

| Tool           | Purpose                    | When Run                           |
|----------------|----------------------------|------------------------------------|
| **ESLint**     | Code linting               | Pre-commit (auto-fix), CI pipeline |
| **Prettier**   | Code formatting            | Pre-commit (auto-fix)              |
| **Commitlint** | Conventional commit format | Commit-msg hook, CI pipeline       |

### Git Hooks (via Husky)

| Hook           | Command             | Purpose                         |
|----------------|---------------------|---------------------------------|
| **pre-commit** | `npm run format`    | Auto-fix linting and formatting |
| **pre-push**   | `npm run test`      | Ensure tests pass before push   |
| **commit-msg** | `commitlint --edit` | Validate commit message format  |

## Contributing

For detailed information on contributing to the ATT&CK Workbench, including commit message formats, development workflow, and coding standards, please see our [Contributing Guide](CONTRIBUTING.md).

## Version Management

- The `version` field in `package.json` is set to `0.0.0-semantically-released`
- Actual versions are managed entirely by semantic-release
- Never manually update version numbers

## Questions?

For questions about this process, please open an issue in the relevant repository or contact the development team.
