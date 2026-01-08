# AGENTS.md

This file provides guidance to agents when working with code in this repository.

## Project Overview

Rebase Bot is a Python-based automation tool that synchronizes downstream GitHub repositories with their upstream sources using `git rebase`. It creates GitHub pull requests with the rebased changes. The tool is designed for maintaining downstream forks (especially for OpenShift/Kubernetes ecosystem projects) that need to stay synchronized with their upstream counterparts.

## Core Concepts

The bot operates with three git repositories:

- **source**: Upstream repository to rebase onto (can be any git repository)
- **dest**: Downstream GitHub repository where the PR will be created
- **rebase**: Intermediate GitHub repository where changes are pushed before PR creation

The rebase branch is created by rebasing `dest/branch` onto `source/branch`, then pushed to `rebase/branch`, and finally a PR is created from `rebase` to `dest`.

## Architecture

### Core Modules

**`rebasebot/bot.py`** - Main orchestration logic
- Contains the `run()` function that drives the entire rebase workflow
- Handles git operations: cloning, rebasing, conflict detection, PR creation/updates
- Implements the "UPSTREAM tag policy" for filtering commits based on commit message tags
- Includes ART (Automated Release Tooling) PR detection and cherry-picking
- Manages the `rebase/manual` label to pause automatic operations

**`rebasebot/cli.py`** - Command-line interface and argument parsing
- Entry point via `main()` function
- Parses complex arguments including GitHub branch specifications (`org/repo:branch`)
- Handles two authentication modes: user token and GitHub App credentials
- Coordinates lifecycle hook setup and execution
- Implements dynamic source reference selection via `--source-ref-hook`

**`rebasebot/github.py`** - GitHub API interactions
- `GithubAppProvider`: Manages GitHub authentication (user token or app credentials)
- `GitHubBranch`: Dataclass for repository/branch specifications
- Handles GitHub App installation tokens for both PR creation (app) and pushing (cloner)

**`rebasebot/lifecycle_hooks.py`** - Extensibility mechanism
- Defines five lifecycle hook points:
  - `PRE_REBASE`: After workspace setup, before rebase
  - `PRE_CARRY_COMMIT`: Before carrying each commit during rebase
  - `POST_REBASE`: After rebase completion
  - `PRE_PUSH_REBASE_BRANCH`: Before pushing to remote
  - `PRE_CREATE_PR`: Before creating pull request
- Scripts can be sourced from: local filesystem, git repository (local or remote), or builtin hooks
- Builtin hooks are in `rebasebot/builtin-hooks/` and referenced via `_BUILTIN_/` prefix
- Hook scripts receive environment variables: `REBASEBOT_SOURCE`, `REBASEBOT_DEST`, `REBASEBOT_REBASE`, `REBASEBOT_WORKING_DIR`, `REBASEBOT_GIT_USERNAME`, `REBASEBOT_GIT_EMAIL`

## Development Commands

### Setup
```bash
# Install dependencies
make deps

# Create virtual environment
make venv
source env/bin/activate

# Install rebasebot locally
make install
```

### Testing
```bash
make unittests
```

### Linting
```bash
make lint
```

## Important Technical Details

### Authentication Modes

**User Token Mode**: Single `--github-user-token` parameter pointing to a file with GitHub personal access token

**App Mode**: Requires two GitHub Apps:
- **app**: For PR operations in dest repository (Contents: Read, Metadata: Read-only, Pull requests: Read & Write)
- **cloner**: For pushing to rebase repository (Contents: Read & Write, Metadata: Read-only, Workflows: Read & Write)
- Requires `--github-app-id`, `--github-app-key`, `--github-cloner-id`, `--github-cloner-key`

### Hook Script Sources

- **Local**: Absolute or relative paths
- **Repository-stored**: `git:gitRef:repo/path/to/script` (gitRef can be branch, tag, or commit hash)
- **Remote repository**: `git:https://github.com/org/repo/branch:path/to/script`
- **Builtin**: `_BUILTIN_/script.sh` (from `rebasebot/builtin-hooks/`)

### Always Run Hooks

By default, hooks only run when a rebase is needed. The `--always-run-hooks` flag forces hook execution even when no rebase is required, useful for dependency updates or code generation that should happen regardless of upstream changes.

## Common Workflows

### Adding a New Lifecycle Hook
1. Create the hook script in `rebasebot/builtin-hooks/` if it's generic enough to be builtin
2. Make it executable (`chmod +x`)
3. Access environment variables like `REBASEBOT_WORKING_DIR` for repository access
4. Exit with code 0 for success, non-zero for failure (which aborts the rebase)
5. Use stdout/stderr for logging (stderr is captured on failure)

### Modifying Core Rebase Logic
The main rebase workflow in `bot.py` follows this sequence:
1. `_needs_rebase()`: Check if rebase is necessary
2. Clone/fetch all three repositories
3. Execute `PRE_REBASE` hooks
4. Perform git rebase with `PRE_CARRY_COMMIT` hooks per commit
5. Execute `POST_REBASE` hooks
6. Execute `PRE_PUSH_REBASE_BRANCH` hooks
7. Push to rebase repository
8. Execute `PRE_CREATE_PR` hooks
9. Create or update PR in dest repository

### Understanding Commit Filtering
The bot filters commits based on:
- `--exclude-commits`: Explicit SHA prefix exclusion list
- `--tag-policy`: UPSTREAM tag handling (none/soft/strict)
- `--bot-emails`: Bot email detection for commit squashing
- ART PR detection for automatic cherry-picking
