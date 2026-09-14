# Classroom Tandingan: GitHub Classroom Automation CLI

This is an open-source automation tool designed to manage classroom and cohort environments on GitHub. Built directly on top of the **GitHub CLI (`gh`)**, it streamlines the entire assignment lifecycle: inviting students to an organization, provisioning private student repositories from template repositories, setting deadlines, milestones, reviewer access, generating automated feedback pull requests, validating setup, and bulk cloning repositories with grading checklists.

For installation details of the required GitHub CLI, see [GitHub CLI Installation](https://github.com/cli/cli#installation).

> [!TIP]
> Looking for a complete, step-by-step walkthrough of the cohort lifecycle? See the [End-to-End Guide](docs/end-to-end-guide.md) with Mermaid workflow diagrams, sequence charts, and troubleshooting tips.

---

## Prerequisites & Assumptions

Before running any script, make sure that:

1. **GitHub CLI (`gh`)** is installed, authenticated, and has sufficient organization and repository scopes (`admin:org`, `repo`, `workflow`).
2. The target **GitHub Organization** exists and you have administrator or owner permissions.
3. The specified GitHub usernames (students and reviewers) are valid GitHub accounts.
4. **Template Repositories** exist, are marked as template repositories on GitHub, and are accessible.

---

## Repository Structure

```
├── .agents/
│   └── skills/               # Installed agent skills (caveman, grill-me)
├── docs/
│   └── end-to-end-guide.md   # Complete cohort lifecycle guide & walkthrough
├── scripts/
│   ├── invite.sh             # Step 1: Org invitations & team assignment
│   ├── repo-create.sh        # Step 2: Bulk student repo provisioning & feedback PR setup
│   ├── repo-check.sh         # Step 3: Validation of created student repositories
│   └── repo-clone.sh         # Step 4: Bulk clone to local cloned/output directory & checklist gen
├── .env.example              # Reference template for configuration variables
├── skills-lock.json          # Installed agent skills manifest and checksums
├── AGENTS.md                 # Agent instructions and repository guardrails
└── README.md                 # Project user guide and CLI documentation
```

---

## Setup & Configuration

Configurations can be modularized by **Cohort**, **Class**, or **Assignment Set**.

### Modular Configuration Files

You can create environment files matching your cohort naming convention:

* `.env.<COHORT_NAME>` (e.g. `.env.cohort-2026`, `.env.class-alpha`)
* `.env.<COHORT_NAME>-Set-<NUMBER>` (e.g. `.env.cohort-2026-Set-1`, `.env.cohort-2026-Set-2`)

> [!NOTE]
> A fallback `.env` file at the root will be loaded if no arguments are passed. All `.env*` preset files are gitignored to prevent exposing student usernames.

### Configuration Variables Reference

* **`ORG`**: The target GitHub organization name (e.g. `"octo-academy"`).
* **`BATCH_NAME`**: The batch or class identifier used in repo names (e.g. `"cohort-2026"`).
* **`TEAM_NAME`**: The target GitHub Team name inside the organization to add students to.
* **`USERS`**: Array of student GitHub usernames.
* **`REVIEWERS`**: Array of reviewer/instructor GitHub usernames.
* **`TEMPLATES`**: Array of template repositories and optional deadlines formatted as `"organization/repository|YYYY-MM-DD HH:MM"` (e.g. `"octo-academy/assignment-1|2026-10-15 23:59"`).

---

## Running Scripts (CLI Arguments)

All scripts support passing **Cohort Name** and optional **Set Number** as command-line arguments:

```bash
# Syntax: ./scripts/<script-name>.sh [COHORT_NAME] [SET_NUMBER]

# Examples:
./scripts/repo-create.sh cohort-2026 2    # Loads .env.cohort-2026-Set-2
./scripts/repo-create.sh class-alpha 1    # Loads .env.class-alpha-Set-1
./scripts/repo-create.sh cohort-2026      # Loads .env.cohort-2026-Set-1 or .env.cohort-2026
./scripts/repo-create.sh                  # Loads root .env fallback
```

---

## Scripts & Workflow

### 1. `scripts/invite.sh` (Step 1: Invitation & Team Synchronization)

Invites students to the organization and registers them under a specific team.

> [!NOTE]
> Students must accept their organization invitations before repository collaborator permissions can be bound cleanly in the next step.

#### Required Config Variables

* `ORG`
* `TEAM_NAME`
* `USERS`

#### Capabilities

* Verifies if the specified GitHub Team exists within the Organization.
* Automatically creates the Team with `secret` privacy if it does not exist.
* Sends organization invitations to students with the `direct_member` role and adds them directly to the specified team.

#### How to Use

```bash
chmod +x scripts/invite.sh
./scripts/invite.sh cohort-2026 1
```

---

### 2. `scripts/repo-create.sh` (Step 2: Repository Provisioning)

Creates private student repositories from templates and configures grading/deadline workflows.

#### Required Config Variables

* `USERS`
* `REVIEWERS`
* `BATCH_NAME`
* `TEMPLATES` (uses both repository name and the deadline specified after the `|`)

#### Capabilities

* **Bulk Provisioning**: Generates a private repository for each student from each specified template.
* **Milestone & Issue Creation**: Converts local deadline inputs into ISO 8601 UTC and creates an "Assignment Deadline" milestone and reminder issue.
* **Collaborator Access**:
  * Assigns `write` access to the student.
  * Assigns `maintain` access to any specified `REVIEWERS` so they can view and review student code.
* **Feedback Pull Request**:
  * Automatically initializes a `feedback` branch.
  * Commits a `.github/FEEDBACK_HINT.md` file.
  * Creates a "Feedback" pull request (comparing default branch to `feedback`) and requests reviews from all specified `REVIEWERS`.

#### Repository Naming Convention

The generated repository name follows the pattern:

```plaintext
<REPO_NAME>-<BATCH_NAME>-<USERNAME>
```

*Example:* For template `octo-academy/assignment-1`, batch `cohort-2026`, and student `studentA`, the repo name will be `assignment-1-cohort-2026-studentA`.

#### How to Use

```bash
chmod +x scripts/repo-create.sh
./scripts/repo-create.sh cohort-2026 1
```

---

### 3. `scripts/repo-check.sh` (Step 3: Repository Existence Checking)

Checks whether each expected repository for the batch and list of users has been created.

#### Required Config Variables

* `USERS`
* `BATCH_NAME`
* `TEMPLATES` (ignores the deadline portion automatically)

#### How to Use

```bash
chmod +x scripts/repo-check.sh
./scripts/repo-check.sh cohort-2026 1
```

---

### 4. `scripts/repo-clone.sh` (Step 4: Repository Bulk Cloning)

Clones the student repositories for the configured batch and user list into a local `cloned/output/` directory.

#### Required Config Variables

* `USERS`
* `BATCH_NAME`
* `TEMPLATES` (ignores the deadline portion automatically)

#### Capabilities

* **Bulk Cloning**: Clones all student repositories to `cloned/output/<repo-name>-<batch-name>-<user>`.
* **Grading Templates Generation**: Automatically creates:
  * `cloned/output/todo.md`: A checklist of all student usernames to track grading progress.
  * `cloned/output/review.md`: A structured markdown file with review prompts (Review, Key Highlights, and What can be Improved?) for each student username.

#### How to Use

```bash
chmod +x scripts/repo-clone.sh
./scripts/repo-clone.sh cohort-2026 1
```

All repositories will be cloned into `./cloned/output/<repo-name>-<batch-name>-<user>`. Existing directories will be skipped.

---

## AI Coding Agent Guidelines & Skills

This repository integrates guidelines and skills for AI coding agents (Claude Code, Antigravity, Cursor, Codex).

* **Agent Instructions & Guardrails**: Detailed operating rules, safety constraints, credential protection, and script modification standards are specified in [AGENTS.md](AGENTS.md).
* **Agent Skills (`.agents/skills/`)**: Skills installed and tracked in `skills-lock.json`:
  * **`caveman`**: Ultra-compressed communication mode preserving token budgets while maintaining technical substance.
  * **`grill-me`**: Relentless interactive interview protocol used by default to pressure-test plans and clarify ambiguity before execution.

> [!IMPORTANT]
> AI agents working in this repository must obtain explicit user confirmation before running live GitHub mutation scripts (`scripts/invite.sh`, `scripts/repo-create.sh`).
