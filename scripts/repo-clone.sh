#!/bin/bash

# ==========================================
# GitHub Repository Mass Clone Script
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

# Batch Name (e.g., "Batch-001")
BATCH_NAME="Batch-Dummy"

# Template repositories
# Format: "organization/repository"
TEMPLATES=(
    "orgName/templateRepo1"
    "orgName/templateRepo2"
)

# ==========================================

echo "=========================================="
echo "Starting Bulk Repository Cloning"
echo "Users: ${USERS[*]}"
echo "Batch: ${BATCH_NAME}"
echo "=========================================="

# Create the output directory if it doesn't exist
mkdir -p cloned/output

CLONED_COUNT=0
SKIPPED_COUNT=0
FAILED_COUNT=0
CLONED_LIST=()
SKIPPED_LIST=()
FAILED_LIST=()

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
        TARGET_DIR="cloned/output/${REPO_BASENAME}-${BATCH_NAME}-${USER}"
        
        echo "------------------------------------------"
        if [ -d "$TARGET_DIR" ]; then
            echo "[SKIPPED]     $NEW_REPO (Directory already exists)"
            SKIPPED_LIST+=("$NEW_REPO")
            ((SKIPPED_COUNT++))
        else
            echo "[CLONING]     $NEW_REPO -> $TARGET_DIR"
            if gh repo clone "$NEW_REPO" "$TARGET_DIR" &>/dev/null; then
                echo "[SUCCESS]     Cloned successfully"
                CLONED_LIST+=("$NEW_REPO")
                ((CLONED_COUNT++))
            else
                echo "[FAILED]      Clone failed"
                FAILED_LIST+=("$NEW_REPO")
                ((FAILED_COUNT++))
            fi
        fi
    done
done

echo ""
echo "=========================================="
echo "Summary"
echo "=========================================="
echo "Total Repositories Processed: $((CLONED_COUNT + SKIPPED_COUNT + FAILED_COUNT))"
echo "Cloned: $CLONED_COUNT"
echo "Skipped: $SKIPPED_COUNT"
echo "Failed: $FAILED_COUNT"
echo "------------------------------------------"

if [ ${#CLONED_LIST[@]} -gt 0 ]; then
    echo "Cloned Repositories:"
    for REPO in "${CLONED_LIST[@]}"; do
        echo "  - $REPO"
    done
fi

if [ ${#SKIPPED_LIST[@]} -gt 0 ]; then
    echo "Skipped Repositories (Already Existed):"
    for REPO in "${SKIPPED_LIST[@]}"; do
        echo "  - $REPO"
    done
fi

if [ ${#FAILED_LIST[@]} -gt 0 ]; then
    echo "Failed to Clone Repositories:"
    for REPO in "${FAILED_LIST[@]}"; do
        echo "  - $REPO"
    done
fi
echo "=========================================="
