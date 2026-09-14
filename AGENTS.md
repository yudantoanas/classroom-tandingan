# AGENTS.md

Operating guidelines and project specifications for AI coding agents working in this repository.

---

## 1. Project Overview

This repository is an automation suite for initializing and managing GitHub Classroom-style cohorts (for bootcamps, universities, and training programs).

The tooling automates:
- Inviting students to GitHub organizations and assigning teams (`scripts/invite.sh`).
- Provisioning private repositories from template repositories, setting deadlines, milestones, reviewer access, and creating feedback PRs (`scripts/repo-create.sh`).
- Validating provisioned repositories (`scripts/repo-check.sh`).
- Bulk cloning repositories and generating grading rubrics and tracking checklists (`scripts/repo-clone.sh`).

---

## 2. Mandatory Agent Skills & Behavioral Rules

AI agents interacting with this repository must adhere to the following rules:

1. **Caveman Style (Ultra Intensity)**:
   - For all conversational responses in chat, use `caveman` ultra intensity: ultra-compressed, concise, technical substance preserved, all filler/articles dropped, single facts per sentence, no invented prose abbreviations.
   - Code, documentation files, commit messages, and PR descriptions must remain in standard professional English.

2. **Grilling Workflow (`grill-me` by Default)**:
   - Use the `grill-me` protocol by default when scoping changes, designing architecture, or handling ambiguous requests.
   - Map decision trees in rounds, present frontier questions with recommended answers, and await explicit user confirmation before executing significant changes.

---

## 3. Safety & Execution Guardrails

Running scripts in this repository mutates live GitHub organization states, creates repositories, and sends invitations to external users.

- **Strict Approval for Live Mutations**:
  - **NEVER** run `scripts/invite.sh` or `scripts/repo-create.sh` autonomously.
  - Always verify target organizations, user lists, and batch configurations with the user before execution.
  - Require explicit user confirmation before running any command that sends invitations or provisions repositories.
- **Dry-Run & Inspection First**:
  - Verify environment files (`.env.*`) and test argument resolution before running live scripts.
  - Use `gh auth status` to confirm active account and scope permissions prior to proposing actions.
- **Read-Only Scripts**:
  - `scripts/repo-check.sh` and `scripts/repo-clone.sh` are read-only / local-cloning operations, but arguments must still be verified against current cohort presets.

---

## 4. Environment & Secrets Management

- **No Secrets in Version Control**:
  - Never commit `.env` or any `.env.*` files. Ensure they remain ignored by `.gitignore`.
  - Never log, print, or expose GitHub tokens, personal access tokens (PATs), or private user emails in agent responses or commit logs.
- **Preserve Configuration Presets**:
  - Do not overwrite existing preset files (`.env.<COHORT_NAME>`, etc.) unless specifically instructed by the user.
  - Fallback `.env` at the root must follow the structure documented in `.env.example`.

---

## 5. Repository Structure

```
├── .agents/
│   └── skills/               # Installed agent skills (caveman, grill-me)
├── docs/
│   ├── end-to-end-guide.md   # Complete cohort lifecycle guide & walkthrough
│   └── hacktiv8-guide.md     # Internal cohort operational guide (gitignored)
├── scripts/
│   ├── invite.sh             # Step 1: Org invitations & team assignment
│   ├── repo-create.sh        # Step 2: Bulk student repo provisioning & feedback PR setup
│   ├── repo-check.sh         # Validation of created student repositories
│   └── repo-clone.sh         # Bulk clone to local cloned/output directory & checklist gen
├── .env.example              # Reference template for configuration variables
├── skills-lock.json          # Installed agent skills manifest and checksums
├── README.md                 # Project user guide and CLI documentation
└── AGENTS.md                 # Agent instructions and repository guardrails
```

---

## 6. Script Conventions & Standards

When creating or modifying scripts in `scripts/`:

- **CLI Argument Convention**:
  - All scripts must maintain standard invocation syntax:
    ```bash
    ./scripts/<script-name>.sh [COHORT_NAME] [SET_NUMBER]
    ```
  - Always maintain fallback resolution to root `.env` when arguments are omitted.
- **Shell Standards**:
  - Scripts must run in standard Bash environments (`#!/bin/bash`).
  - Enforce strict error handling where appropriate (`set -euo pipefail` or explicit exit codes).
  - Comply with `shellcheck` linting rules. Avoid unquoted variables, unsafe word splitting, and hardcoded temporary paths.
- **GitHub CLI (`gh`) Integration**:
  - Use official `gh api` and `gh repo` subcommands.
  - Format GraphQL and REST payloads carefully with `jq` or built-in `--jq` flags.
