# GitHub "Classroom" Initializer

This is an automation tool designed to initialize a classroom environment on GitHub. It invites students to an organization and sets up individual student repositories from template repositories, including milestones, deadline reminders, and feedback/grading workflows.

These scripts leverage the **GitHub CLI (`gh`)**. Make sure you have it installed and authenticated with your GitHub account. For installation details, see [GitHub CLI Installation](https://github.com/cli/cli#installation).

---

## Prerequisites & Assumptions

Before running any script, make sure that:

1. **GitHub CLI (`gh`)** is installed, authenticated, and has sufficient organization/repository scopes.
1. The target **GitHub Organization** exists and you have administrator/owner permissions.
1. The specified GitHub usernames (students and reviewers) are valid.
1. **Template Repositories** exist and are accessible.

---

## Setup & Configuration

All configurations are centralized in a single `.env` file at the root. You do not need to edit individual scripts.

1. **Copy the example configuration file:**

   ```bash
   cp .env.example .env
   ```

1. **Open `.env` and fill in your values.**

### Configuration Variables Reference

* **`ORG`**: The target GitHub organization name (e.g. `"FTDS-Assignment-Bay-2"`).
* **`BATCH_NAME`**: The batch/class identifier used in repo names (e.g. `"FTDS-043-HCK"`).
* **`TEAM_NAME`**: The target GitHub Team name inside the organization to add students to.
* **`USERS`**: Array of student GitHub usernames.
* **`REVIEWERS`**: Array of reviewer/instructor GitHub usernames.
* **`TEMPLATES`**: Array of template repositories and optional deadlines formatted as `"organization/repository|YYYY-MM-DD HH:MM"` (e.g. `"org/P0-GitHub-Starter|2026-12-31 23:59"`).

---

## Scripts & Workflow

### 1. `scripts/invite.sh` (Step 1: Invitation & Team Synchronization)

Invites students to the organization and registers them under a specific team.

> [!NOTE]
> Students must accept their organization invitations before they can be assigned repository permissions in the next step.

#### Required `.env` Variables

* `ORG`
* `TEAM_NAME`
* `USERS`

#### Capabilities

* Verifies if the specified GitHub Team exists within the Organization.
* Automatically creates the Team with `secret` privacy if it does not exist.
* Resolves GitHub usernames to internal user IDs.
* Sends organization invitations to students with the `direct_member` role and adds them directly to the specified team.

#### How to Use

Run the script:

```bash
chmod +x scripts/invite.sh
./scripts/invite.sh
```

---

### 2. `scripts/repo-create.sh` (Step 2: Repository Provisioning)

Creates private student repositories from templates and configures grading/deadline workflows.

#### Required `.env` Variables

* `USERS`
* `REVIEWERS`
* `BATCH_NAME`
* `TEMPLATES` (uses both repository name and the deadline specified after the `|`)

#### Capabilities

* **Bulk Provisioning**: Generates a private repository for each student from each specified template.

* **Milestone & Issue Creation**: Converts local deadline inputs (Asia/Jakarta timezone) into ISO 8601 UTC and creates an "Assignment Deadline" milestone and reminder issue.
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

*Example:* For template `org/P0-GitHub-Starter`, batch `FTDS-043-HCK`, and student `userA`, the repo name will be `P0-GitHub-Starter-FTDS-043-HCK-userA`.

#### How to Use

Run the script:

```bash
chmod +x scripts/repo-create.sh
./scripts/repo-create.sh
```

---

### 3. `scripts/repo-check.sh` (Repository Existence Checking)

Checks whether each expected repository for the batch and list of users has been created.

#### Required `.env` Variables

* `USERS`
* `BATCH_NAME`
* `TEMPLATES` (ignores the deadline portion automatically)

#### How to Use

Run the script:

```bash
chmod +x scripts/repo-check.sh
./scripts/repo-check.sh
```

---

### 4. `scripts/repo-clone.sh` (Repository Bulk Cloning)

Clones the student repositories for the configured batch and user list into a local `cloned/output/` directory.

#### Required `.env` Variables

* `USERS`
* `BATCH_NAME`
* `TEMPLATES` (ignores the deadline portion automatically)

#### Capabilities
* **Bulk Cloning**: Clones all student repositories to `cloned/output/<repo-name>-<batch-name>-<user>`.
* **Grading Templates Generation**: Automatically creates:
  * `cloned/output/todo.md`: A checklist of all student usernames to track grading progress.
  * `cloned/output/review.md`: A structured markdown file with review prompts (Review, Point Penting, and What can be Improved?) for each student username.

#### How to Use

Run the script:

```bash
chmod +x scripts/repo-clone.sh
./scripts/repo-clone.sh
```

All repositories will be cloned into `./cloned/output/<repo-name>-<batch-name>-<user>`. Existing directories will be skipped.
