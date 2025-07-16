#!/usr/bin/env bash

# Written by Chatgpt
# 70% problem for sure..


# shellcheck disable=SC1090

# Bash3 Boilerplate Setup
set -o errexit
set -o nounset
set -o pipefail
IFS=$'\n\t'

# Constants
readonly SCRIPT_NAME=$(basename "$0")
readonly SCRIPT_VERSION="1.0"
readonly SCRIPT_AUTHOR="Charles N Wyble"
readonly SCRIPT_DESC="TSYS Secrets Manager - Fetch secrets using the Bitwarden CLI"

# Configuration
readonly BW_SERVER_URL="https://pwvault.turnsys.com"  # Updated Bitwarden server URL

# Logging and Debugging
readonly LOG_FILE="/tmp/${SCRIPT_NAME}.log"
readonly TIMESTAMP=$(date '+%m-%d-%Y %H:%M:%S')
info() { echo "[INFO] [$TIMESTAMP] $*" | tee -a "$LOG_FILE"; }
error() { echo "[ERROR] [$TIMESTAMP] $*" >&2 | tee -a "$LOG_FILE"; }

# Default Exit Codes
readonly ERR_BW_NOT_INSTALLED=10
readonly ERR_BW_SERVER_CONFIG=20
readonly ERR_SESSION_INVALID=30
readonly ERR_SECRET_NOT_FOUND=40

# Cleanup function to unset session environment variable
cleanup() {
    info "Cleaning up and unsetting session environment variable."
    unset BW_SESSION
}

# Function: Setup Bitwarden server configuration
setup_bitwarden_server() {
    info "Configuring Bitwarden server to $BW_SERVER_URL..."
    # Set the server URL for Bitwarden CLI
    if ! bw config --quiet server "$BW_SERVER_URL"; then
        error "Failed to configure Bitwarden server."
        exit $ERR_BW_SERVER_CONFIG
    fi
    info "Bitwarden server configured successfully."
}

# Function: Fetch or initialize Bitwarden session
fetch_bw_session() {
    local session_token

    # Check if Bitwarden CLI is installed
    if ! command -v bw &>/dev/null; then
        error "Bitwarden CLI (bw) is not installed or not in PATH. Please install it and try again."
        exit $ERR_BW_NOT_INSTALLED
    fi

    # Check for existing session environment variable and reuse if valid
    if [[ -n "${BW_SESSION:-}" ]] && bw unlock --check --session "$BW_SESSION" >/dev/null 2>&1; then
        info "Using existing Bitwarden session token."
        return
    fi

    # Unlock the Bitwarden vault and obtain a new session token
    info "Unlocking Bitwarden vault..."

    bw login --apikey $BW_CLIENTID $BW_CLIENTSECRET

    session_token=$(bw unlock --passwordenv TSYS_BW_PASSWORD_REACHABLECEO --raw)
    if [[ -z "$session_token" ]]; then
        error "Failed to unlock Bitwarden vault. Ensure you're logged in using 'bw login'."
        exit $ERR_SESSION_INVALID
    fi

    export BW_SESSION="$session_token"
    info "Session initialized successfully."
}

# Function: Fetch a secret by name
fetch_secret() {
    local secret_name="$1"
    local secret_value

    info "Fetching secret '$secret_name' from Bitwarden..."
    if ! secret_value=$(bw get password "$secret_name" --session "$BW_SESSION"); then
        error "Failed to retrieve the secret '$secret_name'. Ensure the secret exists in the vault."
        exit $ERR_SECRET_NOT_FOUND
    fi

    if [[ -z "$secret_value" ]]; then
        error "Secret '$secret_name' is empty or not found. Check the vault for proper configuration."
        exit $ERR_SECRET_NOT_FOUND
    fi

}

# Function: Display usage instructions
usage() {
    cat <<EOF
$SCRIPT_DESC

Usage:
  $SCRIPT_NAME <secret_name>

Options:
  -h, --help    Display this help message.

Example:
  $SCRIPT_NAME tsys_api_key
EOF
}

# Main function
main() {

    bw logout || true

    source D:/tsys/secrets/bitwarden/data/apikey-bitwarden-reachableceo

    local secret_name="$1"

    # Setup Bitwarden server and session management
    setup_bitwarden_server
    fetch_bw_session

    # Fetch the specified secret
    secret_value=$(fetch_secret "$secret_name")
    info "Secret '$secret_name' fetched successfully."

    echo "Secret value is: $secret_value"

}

# Trap signals (Ctrl+C, kill, etc.) to ensure cleanup happens
trap cleanup EXIT INT TERM

# Argument parsing
if [[ $# -lt 1 ]] || [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
    usage
    exit 0
fi

main "$1"
