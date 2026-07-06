#!/bin/bash

# ==========================================
# GitHub Repository Provisioning Script
# ==========================================

# Locate and source .env file
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/../.env" ]; then
    source "$SCRIPT_DIR/../.env"
elif [ -f "./.env" ]; then
    source "./.env"
else
    echo "Error: .env file not found."
    exit 1
fi

# Extract Organization from first template (assuming all in same org)
if [ ${#TEMPLATES[@]} -eq 0 ]; then
    echo "Error: TEMPLATES is empty or not set in .env."
    exit 1
fi
ORG=$(echo "${TEMPLATES[0]}" | cut -d'/' -f1)


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

    # Convert deadline to ISO 8601 UTC format for GitHub API with Asia/Jakarta timezone (UTC+07)
    EPOCH=$(TZ="Asia/Jakarta" date -jf "%Y-%m-%d %H:%M:%S" "${DEADLINE}:00" +"%s" 2>/dev/null || TZ="Asia/Jakarta" date -d "$DEADLINE" +"%s")
    DEADLINE_ISO=$(date -u -r "$EPOCH" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u -d "@$EPOCH" +"%Y-%m-%dT%H:%M:%SZ")

    echo "##########################################"
    echo "TEMPLATE: $TEMPLATE_REPO"
    echo "DEADLINE: $DEADLINE"
    echo "##########################################"

    for USER in "${USERS[@]}"; do
        NEW_REPO="${ORG}/${REPO_BASENAME}-${BATCH_NAME}-${USER}"
        echo "------------------------------------------"
        echo "Processing user '$USER' for repo '$REPO_BASENAME'"
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
