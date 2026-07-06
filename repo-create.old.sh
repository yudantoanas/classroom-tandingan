#!/bin/bash

# ==========================================
# GitHub Repository Provisioning Script
# ==========================================
# Please configure the variables below before running the script.

# Array of GitHub usernames
# Separate with spaces
USERS=(
    "userA" 
    "userB" 
    "userC" 
    "userD"
)

# Reviewers (Format: ("user1" "user2"))
REVIEWERS=(
    "reviewer1" 
    "reviewer2"
)

# Team Name for grouping everyone (e.g., "Batch-001")
TEAM_NAME="Batch-Dummy"

# Template repositories and their respective deadlines
# Format: "organization/repository|YYYY-MM-DD HH:MM"
TEMPLATES=(
    "orgName/templateRepo1|2026-12-31 23:59"
    "orgName/templateRepo2|2026-12-31 23:59"
)

# ==========================================

# Extract Organization from first template (assuming all in same org)
ORG=$(echo "${TEMPLATES[0]}" | cut -d'/' -f1)

echo "=========================================="
echo "Synchronizing Team Memberships: $TEAM_NAME"
echo "=========================================="

# Ensure team exists and get its ID
TEAM_ID=$(gh api "orgs/$ORG/teams/$TEAM_NAME" -q '.id' 2>/dev/null || true)
if ! [[ "$TEAM_ID" =~ ^[0-9]+$ ]]; then
    echo "Team $TEAM_NAME does not exist. Creating it..."
    TEAM_ID=$(gh api -X POST "orgs/$ORG/teams" -f name="$TEAM_NAME" -f privacy="closed" -q '.id')
fi

# 0. Invite Students and Reviewers to the Org & Team
ALL_MEMBERS=($(echo "${USERS[@]}" "${REVIEWERS[@]}" | tr ' ' '\n' | sort -u))

for MEMBER in "${ALL_MEMBERS[@]}"; do
    echo "Inviting $MEMBER to organization and team..."
    USER_ID=$(gh api "users/$MEMBER" -q '.id' 2>/dev/null)
    if [ -n "$USER_ID" ]; then
        # The -F flag is used to send integers/arrays instead of strings
        gh api -X POST "orgs/$ORG/invitations" \
            -F invitee_id="$USER_ID" \
            -f role="direct_member" \
            -F "team_ids[]=$TEAM_ID" --silent || echo "Notice: $MEMBER is likely already in the organization or invitation is pending."
    else
        echo "Error: Could not find GitHub user ID for $MEMBER"
    fi
done

echo "=========================================="
echo "Starting Bulk Repository Provisioning"
echo "Users: ${USERS[*]}"
echo "Reviewers: ${REVIEWERS[*]}"
echo "=========================================="

for ITEM in "${TEMPLATES[@]}"; do
    # Extract Template Repo and Deadline from ITEM (strip trailing commas if any)
    TEMPLATE_REPO=$(echo "$ITEM" | cut -d'|' -f1 | sed 's/,$//')
    DEADLINE=$(echo "$ITEM" | cut -d'|' -f2 | sed 's/,$//')

    # Extract Organization and Base Repo Name from TEMPLATE_REPO
    ORG=$(echo "$TEMPLATE_REPO" | cut -d'/' -f1)
    REPO_BASENAME=$(echo "$TEMPLATE_REPO" | cut -d'/' -f2)

    # Clean up REPO_BASENAME by removing "template" (case-insensitive, including camelCase prefix)
    CLEAN_REPO_NAME=$(echo "$REPO_BASENAME" | sed -E 's/(^|[-_])[Tt]emplate([-_]|$)/\1/g; s/^[Tt]emplate([A-Z])/\1/; s/^[-_]//; s/[-_]$//')

    # Convert deadline to ISO 8601 UTC format for GitHub API with Asia/Jakarta timezone (UTC+07)
    EPOCH=$(TZ="Asia/Jakarta" date -jf "%Y-%m-%d %H:%M:%S" "${DEADLINE}:00" +"%s" 2>/dev/null || TZ="Asia/Jakarta" date -d "$DEADLINE" +"%s")
    DEADLINE_ISO=$(date -u -r "$EPOCH" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u -d "@$EPOCH" +"%Y-%m-%dT%H:%M:%SZ")

    echo "##########################################"
    echo "TEMPLATE: $TEMPLATE_REPO"
    echo "DEADLINE: $DEADLINE"
    echo "##########################################"

    for USER in "${USERS[@]}"; do
        NEW_REPO="${ORG}/${TEAM_NAME}-${CLEAN_REPO_NAME}-${USER}"
        echo "------------------------------------------"
        echo "Processing user '$USER' for repo '$CLEAN_REPO_NAME'"
        echo "Creating repository: $NEW_REPO"
        
        # 1. Create Repository from Template
        gh repo create "$NEW_REPO" --template "$TEMPLATE_REPO" --private
        
        if [ $? -ne 0 ]; then
            echo "Error creating repository $NEW_REPO. Skipping to next user."
            continue
        fi
        
        # Wait for the repository to be fully initialized and retrieve the default branch
        echo "Waiting for repository initialization..."
        DEFAULT_BRANCH=""
        for i in {1..10}; do
            DEFAULT_BRANCH=$(gh repo view "$NEW_REPO" --json defaultBranchRef -q .defaultBranchRef.name 2>/dev/null || true)
            if [ -n "$DEFAULT_BRANCH" ] && [ "$DEFAULT_BRANCH" != "null" ]; then
                break
            fi
            sleep 2
        done
        
        if [ -z "$DEFAULT_BRANCH" ] || [ "$DEFAULT_BRANCH" == "null" ]; then
            echo "Error: Repository $NEW_REPO failed to initialize. Skipping to next user."
            continue
        fi
        
        # 2. Assign Write Access to User
        echo "Assigning 'write' access to $USER..."
        gh api -X PUT "repos/$NEW_REPO/collaborators/$USER" -f permission=push --silent
        
        # 2b. Assign Access to Reviewers
        # This ensures reviewers can see all student repos
        for REV in "${REVIEWERS[@]}"; do
            echo "Assigning 'maintain' access to reviewer: $REV..."
            gh api -X PUT "repos/$NEW_REPO/collaborators/$REV" -f permission=maintain --silent
        done
        
        # 3. Update Repository Description with Deadline
        echo "Updating repository description..."
        gh repo edit "$NEW_REPO" --description "Assignment Repository for $USER. Deadline: $DEADLINE"
        
        # 4. Create a Milestone with the Deadline
        echo "Creating milestone 'Assignment Deadline'..."
        MILESTONE_NUMBER=$(gh api -X POST "repos/$NEW_REPO/milestones" \
            -f title="Assignment Deadline" \
            -f due_on="$DEADLINE_ISO" \
            -q '.number')
        
        # Wait a moment for the milestone to be indexed
        sleep 2
        
        if [ -n "$MILESTONE_NUMBER" ] && [ "$MILESTONE_NUMBER" != "null" ]; then
            # 5. Create an Issue associated with the Milestone
            echo "Creating issue linked to milestone..."
            gh issue create \
                --repo "$NEW_REPO" \
                --title "Assignment Deadline" \
                --body "Hi @$USER, please be reminded that the deadline for this assignment is **$DEADLINE**." \
                --milestone "Assignment Deadline"
        else
            echo "Failed to create milestone for $NEW_REPO. Skipping issue creation."
        fi
        
        # 6. Create Feedback Pull Request
        echo "Creating Feedback Pull Request..."
        
        SHA=""
        for i in {1..10}; do
            SHA=$(gh api "repos/$NEW_REPO/git/ref/heads/$DEFAULT_BRANCH" -q '.object.sha' 2>/dev/null || true)
            if [ -n "$SHA" ] && [ "$SHA" != "null" ]; then
                break
            fi
            sleep 2
        done

        if [ -z "$SHA" ] || [ "$SHA" == "null" ]; then
            echo "Error: Could not retrieve SHA for branch $DEFAULT_BRANCH. Skipping Feedback PR."
            continue
        fi
        
        # Create a branch named feedback
        gh api -X POST "repos/$NEW_REPO/git/refs" -f ref="refs/heads/feedback" -f sha="$SHA" --silent
        
        # Create a file named FEEDBACK_HINT.md in the default branch
        gh api -X PUT "repos/$NEW_REPO/contents/.github/FEEDBACK_HINT.md" \
            -f message="Setup feedback PR" \
            -f content="$(echo -n "This Pull Request is created for feedback purposes." | base64 | tr -d '\r\n')" \
            -f branch="$DEFAULT_BRANCH" --silent
        
        # Create a pull request named feedback
        # Base branch is feedback, head is default branch
        PR_NUMBER=$(gh api -X POST "repos/$NEW_REPO/pulls" \
            -f title="Feedback" \
            -f body="Hi @$USER, this Pull Request is created for your feedback and grading. Please do not close this PR." \
            -f head="$DEFAULT_BRANCH" \
            -f base="feedback" \
            -q '.number' 2>/dev/null || true)
        
        # Request reviews from reviewers
        if [ -n "$PR_NUMBER" ] && [ "$PR_NUMBER" != "null" ]; then
            echo "Pull Request created successfully: #$PR_NUMBER"
            if [ ${#REVIEWERS[@]} -gt 0 ]; then
                echo "Requesting reviews from: ${REVIEWERS[*]}"
                REVIEWER_ARGS=()
                for REV in "${REVIEWERS[@]}"; do
                    REVIEWER_ARGS+=(-F "reviewers[]=$REV")
                done

                # gh api to request reviews from reviewers
                gh api -X POST "repos/$NEW_REPO/pulls/$PR_NUMBER/requested_reviewers" "${REVIEWER_ARGS[@]}" --silent || echo "Notice: Failed to request reviews."
            fi
        else
            echo "Failed to create Feedback Pull Request for $NEW_REPO."
        fi
        
        echo "Successfully provisioned for $USER"
        echo "------------------------------------------"
    done
done

echo "All tasks completed!"
