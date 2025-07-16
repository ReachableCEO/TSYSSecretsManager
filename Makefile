# TSYS Secrets Manager - Makefile
# Provides convenient commands for testing, linting, and CI/CD

.PHONY: help test test-ci lint install clean check-deps vendor-test all

# Default target
all: check-deps lint test

help: ## Show this help message
	@echo "TSYS Secrets Manager - Available Commands:"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'

test: ## Run all tests
	@echo "Running test suite..."
	./tests/test-secrets-manager.sh run

test-ci: ## Run tests in CI mode (no colors, verbose output)
	@echo "Running test suite in CI mode..."
	./tests/test-secrets-manager.sh --ci run

test-setup: ## Setup test environment only
	./tests/test-secrets-manager.sh setup

test-cleanup: ## Cleanup test environment
	./tests/test-secrets-manager.sh cleanup

test-list: ## List available test functions
	./tests/test-secrets-manager.sh list

lint: ## Run shell script linting with shellcheck
	@echo "Running shellcheck..."
	@if command -v shellcheck >/dev/null 2>&1; then \
		shellcheck -x secrets-manager.sh tests/test-secrets-manager.sh bin/*.sh; \
		echo "✓ Shellcheck passed"; \
	else \
		echo "⚠ Shellcheck not found, skipping lint check"; \
		echo "  Install with: apt install shellcheck"; \
	fi

install: ## Install dependencies and setup environment
	@echo "Installing dependencies..."
	@if command -v apt >/dev/null 2>&1; then \
		sudo apt update && sudo apt install -y shellcheck; \
	elif command -v dnf >/dev/null 2>&1; then \
		sudo dnf install -y ShellCheck; \
	elif command -v yum >/dev/null 2>&1; then \
		sudo yum install -y ShellCheck; \
	else \
		echo "⚠ Package manager not detected, please install shellcheck manually"; \
	fi
	@echo "Making scripts executable..."
	chmod +x secrets-manager.sh tests/test-secrets-manager.sh bin/*.sh

check-deps: ## Check for required dependencies
	@echo "Checking dependencies..."
	@echo -n "bash: "; command -v bash >/dev/null 2>&1 && echo "✓" || echo "✗ Required"
	@echo -n "shellcheck: "; command -v shellcheck >/dev/null 2>&1 && echo "✓" || echo "⚠ Optional (for linting)"
	@echo -n "git: "; command -v git >/dev/null 2>&1 && echo "✓" || echo "⚠ Optional (for version control)"
	@echo -n "make: "; command -v make >/dev/null 2>&1 && echo "✓" || echo "⚠ Optional (you're using it now)"

vendor-test: ## Test script as if vendored into another project
	@echo "Testing vendor integration..."
	@mkdir -p /tmp/vendor-test
	@cp secrets-manager.sh config/bitwarden-config.conf.sample /tmp/vendor-test/
	@cp tests/test-secrets-manager.sh /tmp/vendor-test/
	@cd /tmp/vendor-test && chmod +x test-secrets-manager.sh && ./test-secrets-manager.sh --ci run
	@rm -rf /tmp/vendor-test
	@echo "✓ Vendor integration test passed"

clean: ## Clean up temporary files and logs
	@echo "Cleaning up..."
	@rm -f /tmp/secrets-manager*.log
	@rm -f tests/test-bitwarden-config.conf
	@rm -rf /tmp/vendor-test
	@echo "✓ Cleanup complete"

validate-config: ## Validate sample configuration file
	@echo "Validating configuration files..."
	@if [ -f config/bitwarden-config.conf.sample ]; then \
		echo "✓ Sample config exists"; \
		grep -q "BW_SERVER_URL" config/bitwarden-config.conf.sample && echo "✓ Server URL configured" || echo "✗ Missing server URL"; \
		grep -q "BW_CLIENTID" config/bitwarden-config.conf.sample && echo "✓ Client ID configured" || echo "✗ Missing client ID"; \
		grep -q "BW_CLIENTSECRET" config/bitwarden-config.conf.sample && echo "✓ Client secret configured" || echo "✗ Missing client secret"; \
		grep -q "BW_PASSWORD" config/bitwarden-config.conf.sample && echo "✓ Password configured" || echo "✗ Missing password"; \
	else \
		echo "✗ Sample config not found"; \
	fi

security-check: ## Run basic security checks
	@echo "Running security checks..."
	@echo "Checking for hardcoded secrets..."
	@if grep -r -i "password\|secret\|key" --include="*.sh" --exclude="*test*" . | grep -v "BW_" | grep -v "your_.*_here" | grep -v "test_" >/dev/null; then \
		echo "⚠ Potential hardcoded secrets found:"; \
		grep -r -i "password\|secret\|key" --include="*.sh" --exclude="*test*" . | grep -v "BW_" | grep -v "your_.*_here" | grep -v "test_"; \
	else \
		echo "✓ No hardcoded secrets detected"; \
	fi
	@echo "Checking file permissions..."
	@find . -name "*.sh" -not -perm 755 -exec echo "⚠ Script not executable: {}" \; || echo "✓ Script permissions OK"

ci: check-deps lint test-ci security-check ## Run full CI pipeline
	@echo "✓ CI pipeline completed successfully"

docs: ## Generate documentation
	@echo "Generating documentation..."
	@echo "Available commands:" > COMMANDS.md
	@echo "" >> COMMANDS.md
	@./secrets-manager.sh --help >> COMMANDS.md
	@echo "" >> COMMANDS.md
	@echo "Test commands:" >> COMMANDS.md
	@echo "" >> COMMANDS.md
	@./test-secrets-manager.sh --help >> COMMANDS.md
	@echo "✓ Documentation generated in COMMANDS.md"

# Development helpers
dev-setup: install ## Setup development environment
	@echo "Setting up development environment..."
	@cp config/bitwarden-config.conf.sample bitwarden-config.conf.dev
	@echo "✓ Development environment ready"
	@echo "  Edit bitwarden-config.conf.dev with your development credentials"

dev-test: ## Run tests with development config
	@if [ -f bitwarden-config.conf.dev ]; then \
		cp bitwarden-config.conf.dev bitwarden-config.conf; \
		$(MAKE) test; \
		rm -f bitwarden-config.conf; \
	else \
		echo "⚠ No development config found. Run 'make dev-setup' first."; \
	fi

# Version management
version: ## Show current version
	@./secrets-manager.sh --version

release-check: ## Check if ready for release
	@echo "Checking release readiness..."
	@$(MAKE) ci
	@echo "✓ All checks passed - ready for release"