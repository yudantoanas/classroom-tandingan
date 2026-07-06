#!/bin/bash

# ==========================================
# GitHub Repository Existence Check Script
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

echo "=========================================="
echo "Starting Repository Existence Check"
echo "Users: ${USERS[*]}"
echo "Batch: ${BATCH_NAME}"
echo "=========================================="

CREATED_COUNT=0
NOT_CREATED_COUNT=0
CREATED_LIST=()
NOT_CREATED_LIST=()

for ITEM in "${TEMPLATES[@]}"; do
    # Extract Template Repo from ITEM (strip trailing commas if any)
    TEMPLATE_REPO=$(echo "$ITEM" | cut -d'|' -f1 | sed 's/,$//')

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
