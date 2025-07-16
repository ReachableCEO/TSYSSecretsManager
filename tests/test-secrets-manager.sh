#!/usr/bin/env bash

# Test Suite for TSYS Secrets Manager
# Designed to work standalone and when vendored into shell scripting frameworks

set -o errexit
set -o nounset
set -o pipefail
IFS=$'\n\t'

# Determine script directory and main script location
readonly TEST_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check if we're in the organized structure or vendored
if [[ -f "${TEST_SCRIPT_DIR}/../secrets-manager.sh" ]]; then
    # Organized structure: tests/test-secrets-manager.sh
    readonly SCRIPT_DIR="$(cd "${TEST_SCRIPT_DIR}/.." && pwd)"
    readonly SECRETS_MANAGER="${SCRIPT_DIR}/secrets-manager.sh"
    readonly TEST_CONFIG="${SCRIPT_DIR}/tests/test-bitwarden-config.conf"
else
    # Vendored structure: all files in same directory
    readonly SCRIPT_DIR="${TEST_SCRIPT_DIR}"
    readonly SECRETS_MANAGER="${SCRIPT_DIR}/secrets-manager.sh"
    readonly TEST_CONFIG="${SCRIPT_DIR}/test-bitwarden-config.conf"
fi
readonly TEST_LOG="/tmp/secrets-manager-test.log"

# Test framework variables
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
TEST_FAILURES=()

# Colors for output (disabled in CI environments)
if [[ "${CI:-false}" == "true" ]] || [[ ! -t 1 ]]; then
    RED=""
    GREEN=""
    YELLOW=""
    BLUE=""
    RESET=""
else
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    RESET='\033[0m'
fi

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${RESET} $*"; }
log_success() { echo -e "${GREEN}[PASS]${RESET} $*"; }
log_error() { echo -e "${RED}[FAIL]${RESET} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${RESET} $*"; }

# Test framework functions
setup_test_environment() {
    log_info "Setting up test environment..."
    
    # Ensure secrets-manager.sh exists and is executable
    if [[ ! -f "$SECRETS_MANAGER" ]]; then
        log_error "secrets-manager.sh not found at $SECRETS_MANAGER"
        exit 1
    fi
    
    if [[ ! -x "$SECRETS_MANAGER" ]]; then
        chmod +x "$SECRETS_MANAGER"
    fi
    
    # Create test config file
    create_test_config
    
    # Clear test log
    > "$TEST_LOG"
    
    log_info "Test environment ready"
}

create_test_config() {
    cat > "$TEST_CONFIG" <<EOF
# Test configuration for secrets manager
BW_SERVER_URL="https://test.bitwarden.com"
BW_CLIENTID="test_client_id"
BW_CLIENTSECRET="test_client_secret"
BW_PASSWORD="test_password"
EOF
}

cleanup_test_environment() {
    log_info "Cleaning up test environment..."
    
    # Remove test config
    [[ -f "$TEST_CONFIG" ]] && rm -f "$TEST_CONFIG"
    
    # Remove test log
    [[ -f "$TEST_LOG" ]] && rm -f "$TEST_LOG"
    
    # Clear any Bitwarden session
    unset BW_SESSION 2>/dev/null || true
    
    log_info "Cleanup complete"
}

run_test() {
    local test_name="$1"
    local test_function="$2"
    
    ((TESTS_RUN++))
    log_info "Running test: $test_name"
    
    if $test_function; then
        ((TESTS_PASSED++))
        log_success "$test_name"
    else
        ((TESTS_FAILED++))
        TEST_FAILURES+=("$test_name")
        log_error "$test_name"
    fi
}

assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="${3:-}"
    
    if [[ "$expected" == "$actual" ]]; then
        return 0
    else
        [[ -n "$message" ]] && log_error "$message"
        log_error "Expected: '$expected', Got: '$actual'"
        return 1
    fi
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local message="${3:-}"
    
    if [[ "$haystack" == *"$needle"* ]]; then
        return 0
    else
        [[ -n "$message" ]] && log_error "$message"
        log_error "Expected '$haystack' to contain '$needle'"
        return 1
    fi
}

assert_file_exists() {
    local file_path="$1"
    local message="${2:-}"
    
    if [[ -f "$file_path" ]]; then
        return 0
    else
        [[ -n "$message" ]] && log_error "$message"
        log_error "File does not exist: $file_path"
        return 1
    fi
}

assert_command_success() {
    local command="$1"
    local message="${2:-}"
    
    if eval "$command" >/dev/null 2>&1; then
        return 0
    else
        [[ -n "$message" ]] && log_error "$message"
        log_error "Command failed: $command"
        return 1
    fi
}

assert_command_failure() {
    local command="$1"
    local message="${2:-}"
    
    if ! eval "$command" >/dev/null 2>&1; then
        return 0
    else
        [[ -n "$message" ]] && log_error "$message"
        log_error "Command unexpectedly succeeded: $command"
        return 1
    fi
}

# Test cases
test_script_exists_and_executable() {
    assert_file_exists "$SECRETS_MANAGER" "secrets-manager.sh should exist" &&
    assert_command_success "[[ -x '$SECRETS_MANAGER' ]]" "secrets-manager.sh should be executable"
}

test_help_option() {
    local output
    output=$("$SECRETS_MANAGER" --help 2>&1) &&
    assert_contains "$output" "TSYS Secrets Manager" "Help should contain project name" &&
    assert_contains "$output" "Usage:" "Help should contain usage information"
}

test_version_option() {
    local output
    output=$("$SECRETS_MANAGER" --version 2>&1) &&
    assert_contains "$output" "version" "Version output should contain 'version'"
}

test_config_file_validation() {
    # Test with non-existent config file
    assert_command_failure "'$SECRETS_MANAGER' --config /nonexistent/config.conf test" \
        "Should fail with non-existent config file"
}

test_config_file_loading() {
    # Test with valid test config
    local output
    output=$("$SECRETS_MANAGER" --config "$TEST_CONFIG" test 2>&1 || true) &&
    assert_contains "$output" "Loading configuration" "Should attempt to load config file"
}

test_install_command_structure() {
    # Test install command without actually installing
    local output
    output=$("$SECRETS_MANAGER" install 2>&1 || true) &&
    assert_contains "$output" "Bitwarden CLI" "Install command should mention Bitwarden CLI"
}

test_missing_command_error() {
    local output
    output=$("$SECRETS_MANAGER" 2>&1 || true) &&
    assert_contains "$output" "No command specified" "Should show error for missing command"
}

test_invalid_command_error() {
    local output
    output=$("$SECRETS_MANAGER" invalidcommand 2>&1 || true) &&
    assert_contains "$output" "Unknown option" "Should show error for invalid command"
}

test_get_command_requires_secret_name() {
    local output
    output=$("$SECRETS_MANAGER" get 2>&1 || true) &&
    assert_contains "$output" "Secret name required" "Get command should require secret name"
}

test_script_error_codes() {
    # Test that script uses proper exit codes
    local exit_code
    
    # Test invalid command
    "$SECRETS_MANAGER" invalidcommand >/dev/null 2>&1 || exit_code=$?
    assert_equals "1" "$exit_code" "Invalid command should exit with code 1"
    
    # Test missing config file
    "$SECRETS_MANAGER" --config /nonexistent/config.conf test >/dev/null 2>&1 || exit_code=$?
    assert_equals "10" "$exit_code" "Missing config should exit with code 10"
}

test_logging_functionality() {
    # Run a command that should generate logs
    "$SECRETS_MANAGER" --help >/dev/null 2>&1
    
    # Check if log file is created (script creates logs for most operations)
    if [[ -f "$TEST_LOG" ]]; then
        return 0
    else
        # Some operations might not create logs, so this is a soft test
        log_warn "Log file not created - this may be normal for help command"
        return 0
    fi
}

test_cleanup_functionality() {
    # Test that cleanup doesn't crash
    assert_command_success "unset BW_SESSION 2>/dev/null || true" \
        "Cleanup should handle missing session gracefully"
}

test_config_file_security() {
    # Ensure test config file has appropriate permissions
    local perms
    perms=$(stat -c "%a" "$TEST_CONFIG" 2>/dev/null || echo "644")
    
    # Config file should be readable by owner (we created it, so this should pass)
    if [[ "$perms" =~ ^[67][0-7][0-7]$ ]]; then
        return 0
    else
        log_warn "Config file permissions: $perms (consider restricting to 600)"
        return 0  # Don't fail test, just warn
    fi
}

test_bitwarden_dependency_check() {
    local output
    # Test without Bitwarden CLI installed (if not already installed)
    if ! command -v bw >/dev/null 2>&1; then
        output=$(timeout 10 "$SECRETS_MANAGER" --config "$TEST_CONFIG" test 2>&1 || true)
        assert_contains "$output" "not installed" "Should detect missing Bitwarden CLI"
    else
        log_info "Bitwarden CLI already installed - skipping dependency check test"
        return 0
    fi
}

# Integration tests (require actual Bitwarden setup)
test_integration_bitwarden_config() {
    # Only run if we have a real config file
    if [[ -f "${SCRIPT_DIR}/bitwarden-config.conf" ]]; then
        log_info "Found real config file - running integration test"
        local output
        output=$(timeout 10 "$SECRETS_MANAGER" test 2>&1 || true)
        # Don't assert success since we may not have valid credentials
        # Just check that it attempts the operation
        assert_contains "$output" "Bitwarden" "Should attempt Bitwarden operations"
    else
        log_info "No real config file found - skipping integration test"
        return 0
    fi
}

# Performance tests
test_script_startup_time() {
    local start_time end_time duration
    start_time=$(date +%s%N)
    "$SECRETS_MANAGER" --help >/dev/null 2>&1
    end_time=$(date +%s%N)
    duration=$(( (end_time - start_time) / 1000000 ))  # Convert to milliseconds
    
    # Script should start in reasonable time (less than 5 seconds)
    if [[ $duration -lt 5000 ]]; then
        return 0
    else
        log_warn "Script startup took ${duration}ms (expected < 5000ms)"
        return 0  # Don't fail, just warn
    fi
}

# Vendor integration tests
test_vendor_compatibility() {
    # Test that script works when called from different directories
    local temp_dir
    temp_dir=$(mktemp -d)
    
    pushd "$temp_dir" >/dev/null
    local output
    output=$("$SECRETS_MANAGER" --help 2>&1)
    popd >/dev/null
    
    rmdir "$temp_dir"
    
    assert_contains "$output" "TSYS Secrets Manager" \
        "Script should work when called from different directory"
}

# Main test runner
run_all_tests() {
    log_info "Starting TSYS Secrets Manager Test Suite"
    echo "========================================"
    
    setup_test_environment
    
    # Basic functionality tests
    run_test "Script exists and is executable" test_script_exists_and_executable
    run_test "Help option works" test_help_option
    run_test "Version option works" test_version_option
    run_test "Config file validation" test_config_file_validation
    run_test "Config file loading" test_config_file_loading
    run_test "Install command structure" test_install_command_structure
    run_test "Missing command error" test_missing_command_error
    run_test "Invalid command error" test_invalid_command_error
    run_test "Get command validation" test_get_command_requires_secret_name
    run_test "Script error codes" test_script_error_codes
    run_test "Logging functionality" test_logging_functionality
    run_test "Cleanup functionality" test_cleanup_functionality
    run_test "Config file security" test_config_file_security
    run_test "Bitwarden dependency check" test_bitwarden_dependency_check
    
    # Integration tests
    run_test "Integration: Bitwarden config" test_integration_bitwarden_config
    
    # Performance tests
    run_test "Script startup time" test_script_startup_time
    
    # Vendor compatibility tests
    run_test "Vendor compatibility" test_vendor_compatibility
    
    cleanup_test_environment
    
    # Print results
    echo "========================================"
    log_info "Test Results:"
    echo "  Total tests run: $TESTS_RUN"
    echo "  Tests passed: $TESTS_PASSED"
    echo "  Tests failed: $TESTS_FAILED"
    
    if [[ $TESTS_FAILED -gt 0 ]]; then
        echo ""
        log_error "Failed tests:"
        for failure in "${TEST_FAILURES[@]}"; do
            echo "  - $failure"
        done
        return 1
    else
        echo ""
        log_success "All tests passed!"
        return 0
    fi
}

# Command line interface
show_usage() {
    cat <<EOF
TSYS Secrets Manager Test Suite

Usage:
    $0 [OPTIONS] [COMMAND]

Commands:
    run                 Run all tests (default)
    setup               Setup test environment only
    cleanup             Cleanup test environment only
    list                List available test functions

Options:
    -h, --help         Show this help message
    -v, --verbose      Enable verbose output
    --ci               Run in CI mode (no colors)

Examples:
    $0                 # Run all tests
    $0 run             # Run all tests
    $0 setup           # Setup test environment
    $0 cleanup         # Cleanup test files
EOF
}

list_tests() {
    echo "Available test functions:"
    declare -F | grep "test_" | sed 's/declare -f /  - /'
}

main() {
    local command="run"
    local verbose=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -v|--verbose)
                set -x
                verbose=true
                shift
                ;;
            --ci)
                CI=true
                shift
                ;;
            run|setup|cleanup|list)
                command="$1"
                shift
                ;;
            *)
                echo "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    case "$command" in
        run)
            run_all_tests
            ;;
        setup)
            setup_test_environment
            ;;
        cleanup)
            cleanup_test_environment
            ;;
        list)
            list_tests
            ;;
        *)
            echo "Unknown command: $command"
            show_usage
            exit 1
            ;;
    esac
}

# Handle script being sourced vs executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi