#!/bin/bash

# ==========================================
# GitHub Repository Existence Check Script
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
    # Try with set suffix if provided: e.g. cohort-a + Set-1 -> .env.cohort-a-Set-1
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
