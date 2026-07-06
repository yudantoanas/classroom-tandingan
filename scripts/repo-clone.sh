#!/bin/bash

# ==========================================
# GitHub Repository Mass Clone Script
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

# Create local output folder and files
echo ""
echo "Generating todo.md and review.md files..."

# Generate todo.md
{
    echo "# Todo - Grading:"
    echo ""
    for USER in "${USERS[@]}"; do
        echo "[ ] $USER"
    done
} > cloned/output/todo.md

# Generate review.md
{
    for USER in "${USERS[@]}"; do
        echo "# $USER"
        echo ""
        echo "## Review"
        echo ""
        echo "## Point Penting"
        echo ""
        echo "## What can be Improved?"
        echo ""
        echo "==="
        echo ""
    done
} > cloned/output/review.md

echo ""
echo "All tasks completed!"
echo ""
echo "=========================================="
echo "Summary"
echo "=========================================="
echo "Total  : $((CLONED_COUNT + SKIPPED_COUNT + FAILED_COUNT))"
echo "Cloned : $CLONED_COUNT"
echo "Skipped: $SKIPPED_COUNT"
echo "Failed : $FAILED_COUNT"
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
