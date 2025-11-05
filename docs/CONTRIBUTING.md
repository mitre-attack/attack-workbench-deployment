# ATT&CK Workbench Contributing Guide

This guide provides detailed information for contributing to the ATT&CK Workbench ecosystem.

## Commit Message Format

Use [Conventional Commits](https://www.conventionalcommits.org/) format:

### Structure

```text
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

### Types

Changes relevant to the API or UI:

- `feat` Commits that add, adjust or remove a new feature to the API or UI
- `fix` Commits that fix an API or UI bug of a preceded `feat` commit

Code quality and maintenance:

- `refactor` Commits that rewrite or restructure code without altering API or UI behavior
- `perf` Commits are special type of `refactor` commits that specifically improve performance
- `style` Commits that address code style (e.g., white-space, formatting, missing semi-colons) and do not affect application behavior
- `test` Commits that add missing tests or correct existing ones

Documentation and infrastructure:

- `docs` Commits that exclusively affect documentation
- `build` Commits that affect build-related components such as build tools, dependencies, project version, CI/CD pipelines
- `ops` Commits that affect operational components like infrastructure, deployment, backup, recovery procedures
- `chore` Miscellaneous commits e.g. modifying `.gitignore`

### Scopes

The `scope` provides additional contextual information.

- The scope is an **optional** part
- Allowed scopes vary and are typically defined by the specific project
- **Do not** use issue identifiers as scopes

### Breaking Changes Indicator

- A commit that introduce breaking changes **must** be indicated by an `!` before the `:` in the subject line e.g. `feat(api)!: remove status endpoint`
- Breaking changes **should** be described in the [commit footer section](#footer), if the [commit description](#description) isn't sufficiently informative

### Description

The `description` contains a concise description of the change.

- The description is a **mandatory** part
- Use the imperative, present tense: "change" not "changed" nor "changes"
  - Think of `This commit will...` or `This commit should...`
- **Do not** capitalize the first letter
- **Do not** end the description with a period (`.`)

### Body

The `body` should include the motivation for the change and contrast this with previous behavior.

- The body is an **optional** part
- Use the imperative, present tense: "change" not "changed" nor "changes"

### Footer

The `footer` should contain issue references and informations about **Breaking Changes**

- The footer is an **optional** part, except if the commit introduce breaking changes
- *Optionally* reference issue identifiers (e.g., `Closes #123`, `Fixes JIRA-456`)
- **Breaking Changes** **must** start with the word `BREAKING CHANGE:`
  - For a single line description just add a space after `BREAKING CHANGE:`
  - For a multi line description add two new lines after `BREAKING CHANGE:`

### Version Impact

| Type | Version Impact | Example |
|------|---------------|---------|
| `feat:` | Minor bump | `feat: add new attack technique` |
| `fix:` | Patch bump | `fix: correct typo in technique description` |
| `feat!:` or `BREAKING CHANGE:` | Major bump | `feat!: rename primary data structure` |
| `docs:`, `chore:`, `test:` | No release | `docs: update API documentation` |

### Examples

Basic feature addition:

```text
feat: add email notifications on new direct messages
```

Feature with scope:

```text
feat(shopping cart): add the amazing button
```

Breaking change with footer:

```text
feat!: remove ticket list endpoint

refers to JIRA-1337

BREAKING CHANGE: ticket endpoints no longer supports list all entities.
```

Bug fixes:

```text
fix(shopping-cart): prevent order an empty shopping cart
```

```text
fix(api): fix wrong calculation of request body checksum
```

Bug fix with body:

```text
fix: add missing parameter to service call

The error occurred due to <reasons>.
```

Performance improvement:

```text
perf: decrease memory footprint for determine unique visitors by using HyperLogLog
```

Build and infrastructure:

```text
build: update dependencies
```

```text
build(release): bump version to 1.0.0
```

Code restructuring:

```text
refactor: implement fibonacci number calculation as recursion
```

Style changes:

```text
style: remove empty line
```

## Development Workflow

1. Fork the repository
2. Create feature branch from appropriate base branch
3. Make changes following code standards
4. Commit with conventional commit messages
5. Push (tests will run automatically)
6. Open PR to appropriate target branch
7. Address review feedback
8. Merge triggers automatic release (if applicable)

## Target Branch Selection

- **Hotfixes**: Target `main` directly
- **Features**: Target `next` for backwards-compatible changes
- **Breaking changes**: Target `next-major`
- **Maintenance**: Target version branch (e.g., `2.x`)

## Versioning Rules

**If** your next release contains commit with...

- **Breaking Changes** increment the **major version**
- **API relevant changes** (`feat` or `fix`) increment the **minor version**

**Else** increment the **patch version**

## Code Quality Standards

### Pre-commit Requirements

All contributions must pass automated checks:

- ESLint for code quality
- Prettier for formatting
- Tests must pass
- Commit messages must follow conventional format

### Git Hooks

The repository uses Husky to enforce quality standards:

- **pre-commit**: Automatically fixes linting and formatting issues
- **pre-push**: Ensures all tests pass before pushing
- **commit-msg**: Validates commit message format

## Questions?

For questions about this contributing process, please open an issue in the relevant repository or contact the development team.
