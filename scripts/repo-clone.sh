#!/bin/bash

# ==========================================
# GitHub Repository Mass Clone Script
# ==========================================

# Locate and source .env file
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_CONF="${1:-}"
SET_ARG="${2:-}"

# Normalize set argument if passed as $2 (e.g. "1" -> "Set-1", "set-2" -> "Set-2", "Set-2" -> "Set-2")
SET_SUFFIX=""
if [ -n "$SET_ARG" ]; then
    SET_NUM=$(echo "$SET_ARG" | grep -o '[0-9]\+')
    if [ -n "$SET_NUM" ]; then
        SET_SUFFIX="Set-$SET_NUM"
    else
        SET_SUFFIX="$SET_ARG"
    fi
fi

ENV_PATH=""
if [ -n "$TARGET_CONF" ]; then
    # Try with set suffix if provided: e.g. P0-HCK + Set-1 -> .env.P0-HCK-Set-1
    if [ -n "$SET_SUFFIX" ]; then
        CANDIDATES=(
            "$TARGET_CONF-$SET_SUFFIX"
            "$SCRIPT_DIR/../$TARGET_CONF-$SET_SUFFIX"
            "$SCRIPT_DIR/../.env.$TARGET_CONF-$SET_SUFFIX"
            "./.env.$TARGET_CONF-$SET_SUFFIX"
        )
        for cand in "${CANDIDATES[@]}"; do
            if [ -f "$cand" ]; then
                ENV_PATH="$cand"
                break
            fi
        done
    fi

    # Try direct name if no set or set candidate not found
    if [ -z "$ENV_PATH" ]; then
        CANDIDATES=(
            "$TARGET_CONF"
            "$SCRIPT_DIR/../$TARGET_CONF"
            "$SCRIPT_DIR/../.env.$TARGET_CONF"
            "./.env.$TARGET_CONF"
            "$SCRIPT_DIR/../.env.$TARGET_CONF-Set-1"
            "./.env.$TARGET_CONF-Set-1"
        )
        for cand in "${CANDIDATES[@]}"; do
            if [ -f "$cand" ]; then
                ENV_PATH="$cand"
                break
            fi
        done
    fi

    if [ -n "$ENV_PATH" ]; then
        source "$ENV_PATH"
    else
        echo "Error: Config file not found for '$TARGET_CONF' ${SET_SUFFIX:+with $SET_SUFFIX}."
        exit 1
    fi
elif [ -f "$SCRIPT_DIR/../.env" ]; then
    source "$SCRIPT_DIR/../.env"
elif [ -f "./.env" ]; then
    source "./.env"
else
    echo "Error: .env file not found."
    exit 1
fi

# Validate configuration
if [ -z "$BATCH_NAME" ]; then
    echo "Error: BATCH_NAME is not set in config."
    exit 1
fi

if [ ${#USERS[@]} -eq 0 ]; then
    echo "Error: USERS is empty or not set in config."
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
