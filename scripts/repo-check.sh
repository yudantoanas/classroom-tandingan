#!/bin/bash

# ==========================================
# GitHub Repository Existence Check Script
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

# Batch Name for creating the repo (e.g., "Batch-001")
BATCH_NAME="Batch-Dummy"

# Template repositories
# Format: "organization/repository"
TEMPLATES=(
    "orgName/templateRepo1"
    "orgName/templateRepo2"
)

# ==========================================

echo "=========================================="
echo "Starting Repository Existence Check"
echo "Users: ${USERS[*]}"
echo "Batch: ${BATCH_NAME}"
echo "=========================================="

CREATED_COUNT=0
NOT_CREATED_COUNT=0
CREATED_LIST=()
NOT_CREATED_LIST=()

for TEMPLATE_REPO in "${TEMPLATES[@]}"; do
    # Strip trailing commas if any
    TEMPLATE_REPO=$(echo "$TEMPLATE_REPO" | sed 's/,$//')

    # Extract Organization and Base Repo Name from TEMPLATE_REPO
    ORG=$(echo "$TEMPLATE_REPO" | cut -d'/' -f1)
    REPO_BASENAME=$(echo "$TEMPLATE_REPO" | cut -d'/' -f2)

    echo "##########################################"
    echo "TEMPLATE: $TEMPLATE_REPO"
    echo "##########################################"

    for USER in "${USERS[@]}"; do
        NEW_REPO="${ORG}/${REPO_BASENAME}-${BATCH_NAME}-${USER}"
        
        # Check if the repository exists using gh repo view
        if gh repo view "$NEW_REPO" &>/dev/null; then
            echo "[CREATED]     $NEW_REPO"
            CREATED_LIST+=("$NEW_REPO")
            ((CREATED_COUNT++))
        else
            echo "[NOT CREATED] $NEW_REPO"
            NOT_CREATED_LIST+=("$NEW_REPO")
            ((NOT_CREATED_COUNT++))
        fi
    done
done

echo ""
echo "=========================================="
echo "Summary"
echo "=========================================="
echo "Total Repositories Checked: $((CREATED_COUNT + NOT_CREATED_COUNT))"
echo "Created: $CREATED_COUNT"
echo "Not Created: $NOT_CREATED_COUNT"
echo "------------------------------------------"

if [ ${#CREATED_LIST[@]} -gt 0 ]; then
    echo "Created Repositories:"
    for REPO in "${CREATED_LIST[@]}"; do
        echo "  - $REPO"
    done
fi

if [ ${#NOT_CREATED_LIST[@]} -gt 0 ]; then
    echo "Not Created Repositories:"
    for REPO in "${NOT_CREATED_LIST[@]}"; do
        echo "  - $REPO"
    done
fi
echo "=========================================="
