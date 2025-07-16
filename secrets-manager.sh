#!/usr/bin/env bash

# TSYS Secrets Manager - Complete Bitwarden CLI management script
# Handles installation, configuration, authentication, and secret retrieval

set -o errexit
set -o nounset
set -o pipefail
IFS=$'\n\t'

readonly SCRIPT_NAME=$(basename "$0")
readonly SCRIPT_VERSION="2.0"
readonly SCRIPT_DESC="TSYS Secrets Manager - Complete Bitwarden CLI solution"

readonly DEFAULT_CONFIG_FILE="./bitwarden-config.conf"
readonly LOG_FILE="/tmp/${SCRIPT_NAME}.log"
readonly TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

info() { echo "[INFO] [$TIMESTAMP] $*" | tee -a "$LOG_FILE"; }
warn() { echo "[WARN] [$TIMESTAMP] $*" | tee -a "$LOG_FILE"; }
error() { echo "[ERROR] [$TIMESTAMP] $*" >&2 | tee -a "$LOG_FILE"; }

readonly ERR_CONFIG_NOT_FOUND=10
readonly ERR_BW_NOT_INSTALLED=20
readonly ERR_BW_INSTALL_FAILED=30
readonly ERR_BW_SERVER_CONFIG=40
readonly ERR_SESSION_INVALID=50
readonly ERR_SECRET_NOT_FOUND=60
readonly ERR_LOGIN_FAILED=70

cleanup() {
    info "Cleaning up session data..."
    unset BW_SESSION 2>/dev/null || true
}

install_bitwarden_cli() {
    info "Checking if Bitwarden CLI is installed..."
    
    if command -v bw &>/dev/null; then
        local version=$(bw --version)
        info "Bitwarden CLI already installed: $version"
        return 0
    fi
    
    info "Installing Bitwarden CLI..."
    
    if command -v npm &>/dev/null; then
        info "Installing via npm..."
        if sudo npm install -g @bitwarden/cli; then
            info "Bitwarden CLI installed successfully via npm"
            return 0
        fi
    fi
    
    info "Installing via direct download..."
    local bw_url="https://github.com/bitwarden/clients/releases/latest/download/bw-linux-1.22.1.zip"
    local temp_dir=$(mktemp -d)
    
    if command -v wget &>/dev/null; then
        wget -O "$temp_dir/bw.zip" "$bw_url"
    elif command -v curl &>/dev/null; then
        curl -L -o "$temp_dir/bw.zip" "$bw_url"
    else
        error "Neither wget nor curl available for download"
        exit $ERR_BW_INSTALL_FAILED
    fi
    
    if command -v unzip &>/dev/null; then
        unzip "$temp_dir/bw.zip" -d "$temp_dir"
        sudo mv "$temp_dir/bw" /usr/local/bin/
        sudo chmod +x /usr/local/bin/bw
        rm -rf "$temp_dir"
        info "Bitwarden CLI installed successfully via direct download"
    else
        error "unzip not available to extract Bitwarden CLI"
        exit $ERR_BW_INSTALL_FAILED
    fi
}

load_config() {
    local config_file="${1:-$DEFAULT_CONFIG_FILE}"
    
    if [[ ! -f "$config_file" ]]; then
        error "Configuration file not found: $config_file"
        error "Please create a configuration file or use --config option"
        exit $ERR_CONFIG_NOT_FOUND
    fi
    
    info "Loading configuration from: $config_file"
    source "$config_file"
    
    if [[ -z "${BW_SERVER_URL:-}" ]]; then
        error "BW_SERVER_URL not defined in config file"
        exit $ERR_CONFIG_NOT_FOUND
    fi
    
    if [[ -z "${BW_CLIENTID:-}" ]] || [[ -z "${BW_CLIENTSECRET:-}" ]]; then
        error "BW_CLIENTID and BW_CLIENTSECRET must be defined in config file"
        exit $ERR_CONFIG_NOT_FOUND
    fi
    
    if [[ -z "${BW_PASSWORD:-}" ]]; then
        error "BW_PASSWORD must be defined in config file"
        exit $ERR_CONFIG_NOT_FOUND
    fi
}

setup_bitwarden_server() {
    info "Configuring Bitwarden server to $BW_SERVER_URL..."
    
    if ! bw config server "$BW_SERVER_URL" >/dev/null 2>&1; then
        error "Failed to configure Bitwarden server"
        exit $ERR_BW_SERVER_CONFIG
    fi
    
    info "Bitwarden server configured successfully"
}

login_and_unlock() {
    info "Logging out any existing session..."
    bw logout >/dev/null 2>&1 || true
    
    info "Logging in with API key..."
    if ! bw login --apikey "$BW_CLIENTID" "$BW_CLIENTSECRET" >/dev/null 2>&1; then
        error "Failed to login with API key"
        exit $ERR_LOGIN_FAILED
    fi
    
    info "Unlocking vault..."
    local session_token
    session_token=$(echo "$BW_PASSWORD" | bw unlock --raw 2>/dev/null)
    
    if [[ -z "$session_token" ]]; then
        error "Failed to unlock vault with provided password"
        exit $ERR_SESSION_INVALID
    fi
    
    export BW_SESSION="$session_token"
    info "Vault unlocked successfully"
}

fetch_secret() {
    local secret_name="$1"
    local secret_value
    
    info "Fetching secret: $secret_name"
    
    if ! secret_value=$(bw get password "$secret_name" --session "$BW_SESSION" 2>/dev/null); then
        error "Failed to retrieve secret: $secret_name"
        exit $ERR_SECRET_NOT_FOUND
    fi
    
    if [[ -z "$secret_value" ]]; then
        error "Secret '$secret_name' is empty or not found"
        exit $ERR_SECRET_NOT_FOUND
    fi
    
    echo "$secret_value"
}

list_secrets() {
    info "Listing all available items..."
    bw list items --session "$BW_SESSION" | jq -r '.[] | .name' 2>/dev/null || {
        bw list items --session "$BW_SESSION" | grep '"name"' | cut -d'"' -f4
    }
}

usage() {
    cat <<EOF
$SCRIPT_DESC

Usage:
    $SCRIPT_NAME [OPTIONS] COMMAND [ARGS]

Commands:
    install                 Install Bitwarden CLI
    get <secret_name>       Retrieve a specific secret
    list                    List all available secrets
    test                    Test configuration and connectivity

Options:
    -c, --config FILE       Use specific config file (default: $DEFAULT_CONFIG_FILE)
    -h, --help             Show this help message
    -v, --version          Show version information

Examples:
    $SCRIPT_NAME install
    $SCRIPT_NAME get APIKEY-pushover
    $SCRIPT_NAME list
    $SCRIPT_NAME --config /path/to/config.conf get my-secret

Environment Variables (can be set in config file):
    BW_SERVER_URL          Bitwarden server URL
    BW_CLIENTID           API client ID
    BW_CLIENTSECRET       API client secret
    BW_PASSWORD           Master password
EOF
}

main() {
    local config_file="$DEFAULT_CONFIG_FILE"
    local command=""
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -c|--config)
                config_file="$2"
                shift 2
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            -v|--version)
                echo "$SCRIPT_NAME version $SCRIPT_VERSION"
                exit 0
                ;;
            install)
                command="install"
                shift
                ;;
            get)
                command="get"
                secret_name="$2"
                shift 2
                ;;
            list)
                command="list"
                shift
                ;;
            test)
                command="test"
                shift
                ;;
            *)
                error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
    
    case "$command" in
        install)
            install_bitwarden_cli
            ;;
        get)
            if [[ -z "${secret_name:-}" ]]; then
                error "Secret name required for 'get' command"
                usage
                exit 1
            fi
            load_config "$config_file"
            install_bitwarden_cli
            setup_bitwarden_server
            login_and_unlock
            fetch_secret "$secret_name"
            ;;
        list)
            load_config "$config_file"
            install_bitwarden_cli
            setup_bitwarden_server
            login_and_unlock
            list_secrets
            ;;
        test)
            load_config "$config_file"
            install_bitwarden_cli
            setup_bitwarden_server
            login_and_unlock
            info "Configuration test successful!"
            ;;
        *)
            error "No command specified"
            usage
            exit 1
            ;;
    esac
}

trap cleanup EXIT INT TERM

main "$@"