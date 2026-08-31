#!/bin/bash

# ==========================================
# GitHub Organization Invitation Script
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

# Validate required configuration
if [ -z "$ORG" ]; then
    echo "Error: ORG is not set in .env."
    exit 1
fi

if [ -z "$TEAM_NAME" ]; then
    echo "Error: TEAM_NAME is not set in config."
    exit 1
fi

if [ ${#USERS[@]} -eq 0 ]; then
    echo "Error: USERS is empty or not set in config."
    exit 1
fi

echo "=========================================="
echo "Inviting Users to Organization: $ORG"
echo "Target Team: $TEAM_NAME"
echo "=========================================="

# ------------------------------------------
# Step 1: Ensure the team exists
# ------------------------------------------
echo "Checking if team '$TEAM_NAME' exists in '$ORG'..."
TEAM_SLUG=$(gh api "orgs/$ORG/teams/$TEAM_NAME" -q '.slug' 2>/dev/null || true)

if [ -n "$TEAM_SLUG" ] && [ "$TEAM_SLUG" != "null" ]; then
    echo "Team '$TEAM_NAME' already exists (Slug: $TEAM_SLUG)."
else
    echo "Team '$TEAM_NAME' does not exist. Creating it..."
    TEAM_SLUG=$(gh api -X POST "orgs/$ORG/teams" \
        -f name="$TEAM_NAME" \
        -f privacy="secret" \
        -q '.slug' 2>/dev/null || true)

    if [ -z "$TEAM_SLUG" ] || [ "$TEAM_SLUG" == "null" ]; then
        echo "Error: Failed to create team '$TEAM_NAME'. Aborting."
        exit 1
    fi
    echo "Team '$TEAM_NAME' created successfully (Slug: $TEAM_SLUG)."
fi

# ------------------------------------------
# Step 2: Add/Invite users to the team
# ------------------------------------------
for USER in "${USERS[@]}"; do
    echo "------------------------------------------"
    echo "Adding/Inviting $USER to team '$TEAM_SLUG' in '$ORG'..."

    RESPONSE=$(gh api --method PUT "orgs/$ORG/teams/$TEAM_SLUG/memberships/$USER" \
        -f role="member" 2>&1)

    if [ $? -eq 0 ]; then
        STATE=$(echo "$RESPONSE" | grep -o '"state": *"[^"]*"' | cut -d'"' -f4)
        [ -z "$STATE" ] && STATE="active"
        echo "Success: $USER membership status is '$STATE' (role: member)."
    else
        echo "Error adding $USER: $RESPONSE"
    fi
done

echo "=========================================="
echo "All invitations processed!"
echo "=========================================="
