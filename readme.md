# GitHub "Classroom" Initializer

This is a two-step automation tool designed to initialize a classroom environment on GitHub. It invites students to an organization and sets up individual student repositories from template repositories, including milestones, deadline reminders, and feedback/grading workflows.

These scripts leverage the **GitHub CLI (`gh`)**. Make sure you have it installed and authenticated with your GitHub account. For installation details, see [GitHub CLI Installation](https://github.com/cli/cli#installation).

---

## Prerequisites & Assumptions

Before running any script, make sure that:

1. **GitHub CLI (`gh`)** is installed, authenticated, and has sufficient organization/repository scopes.
1. The target **GitHub Organization** exists and you have administrator/owner permissions.
1. The specified GitHub usernames (students and reviewers) are valid.
1. **Template Repositories** exist and are accessible.

---

## Scripts & Workflow

The classroom setup is divided into two parts:

### 1. `scripts/invite.sh` (Step 1: Invitation & Team Synchronization)

Invites students to the organization and registers them under a specific team.

> [!NOTE]
> Students must accept their organization invitations before they can be assigned repository permissions in the next step.

#### Capabilities

- Verifies if the specified GitHub Team exists within the Organization.
- Automatically creates the Team with `secret` privacy if it does not exist.
- Resolves GitHub usernames to internal user IDs.
- Sends organization invitations to students with the `direct_member` role and adds them directly to the specified team.

#### How to Configure & Use

1. Open `scripts/invite.sh` and configure the following variables:
   - `USERS`: Array of student GitHub usernames.
   - `ORG`: Name of your GitHub organization.
   - `TEAM_NAME`: The target Team name (e.g., `Batch-001`).
1. Run the script:

   ```bash
   chmod +x scripts/invite.sh
   ./scripts/invite.sh
   ```

---

### 2. `scripts/repo-create.sh` (Step 2: Repository Provisioning)

Creates private student repositories from templates and configures grading/deadline workflows.

#### Capabilities

- **Bulk Provisioning**: Generates a private repository for each student from each specified template.
- **Milestone & Issue Creation**: Converts local deadline inputs (Asia/Jakarta timezone) into ISO 8601 UTC and creates an "Assignment Deadline" milestone and reminder issue.
- **Collaborator Access**:
  - Assigns `write` access to the student.
  - Assigns `maintain` access to any specified `REVIEWERS` so they can view and review student code.
- **Feedback Pull Request**:
  - Automatically initializes a `feedback` branch.
  - Commits a `.github/FEEDBACK_HINT.md` file.
  - Creates a "Feedback" pull request (comparing default branch to `feedback`) and requests reviews from all specified `REVIEWERS`.

#### Repository Naming Convention

The generated repository name follows the pattern:

```plaintext
<REPO_NAME>-<BATCH_NAME>-<USERNAME>
```

- **`<REPO_NAME>`**: The exact basename of the template repository (preserving uppercase/lowercase letters).
- **`<BATCH_NAME>`**: The batch/class identifier.
- **`<USERNAME>`**: The student's GitHub username.

*Example:* For template `org/Term0-Assignment001`, batch `Batch-001`, and student `userA`, the repo name will be `Term0-Assignment001-Batch-001-userA`.

#### How to Configure & Use

1. Open `repo-create.sh` and configure:
   - `USERS`: Array of student GitHub usernames (same as step 1).
   - `REVIEWERS`: Array of reviewer/instructor GitHub usernames.
   - `BATCH_NAME`: The batch identifier used in repo names.
   - `TEMPLATES`: Array of template repos and deadlines formatted as `"org/repo|YYYY-MM-DD HH:MM"` (e.g., `"org/Term0-Assignment001|2026-12-31 23:59"`).
1. Run the script:

   ```bash
   chmod +x scripts/repo-create.sh
   ./scripts/repo-create.sh
   ```

---

### 3. `scripts/repo-check.sh` (Repository Existence Checking)

Checks whether each expected repository for the batch and list of users has been created.

#### How to Configure & Use

1. Open `scripts/repo-check.sh` and configure:
   - `USERS`: Array of student GitHub usernames.
   - `BATCH_NAME`: The batch identifier used in repo names.
   - `TEMPLATES`: Array of template repos formatted as `"org/repo"`.
1. Run the script:

   ```bash
   chmod +x scripts/repo-check.sh
   ./scripts/repo-check.sh
   ```

---

### 4. `scripts/repo-clone.sh` (Repository Bulk Cloning)

Clones the student repositories for the configured batch and user list into a local `cloned/output/` directory.

#### How to Configure & Use

1. Open `scripts/repo-clone.sh` and configure:
   - `USERS`: Array of student GitHub usernames.
   - `BATCH_NAME`: The batch identifier used in repo names.
   - `TEMPLATES`: Array of template repos formatted as `"org/repo"`.
1. Run the script:

   ```bash
   chmod +x scripts/repo-clone.sh
   ./scripts/repo-clone.sh
   ```

   All repositories will be cloned into `./output/<repo-name>-<batch-name>-<user>`. Existing directories will be skipped.
