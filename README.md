# TSYS Secrets Manager

A comprehensive bash script solution for managing secrets at TSYS using the Bitwarden CLI. This tool provides automated installation, configuration, and secure secret retrieval from your Bitwarden vault.

## Features

- **Automated Installation**: Automatically detects and installs Bitwarden CLI via multiple methods (snap, npm, direct download)
- **Configuration Management**: Uses secure configuration files for server and authentication details
- **Multiple Commands**: Support for installation, secret retrieval, listing, and testing
- **Robust Error Handling**: Comprehensive error codes and detailed logging
- **Security-First**: Proper session management, cleanup, and credential handling
- **Cross-Platform**: Designed for Linux environments with multiple installation fallbacks

## Quick Start

1. **Clone and Setup**:
   ```bash
   git clone <repository-url>
   cd KNELSecretsManager
   chmod +x secrets-manager.sh
   ```

2. **Create Configuration**:
   ```bash
   cp config/bitwarden-config.conf.sample bitwarden-config.conf
   # Edit bitwarden-config.conf with your actual Bitwarden credentials
   ```

3. **Install Bitwarden CLI** (if not already installed):
   ```bash
   ./secrets-manager.sh install
   ```

4. **Test Your Setup**:
   ```bash
   ./secrets-manager.sh test
   ```

5. **Retrieve Secrets**:
   ```bash
   ./secrets-manager.sh get APIKEY-pushover
   ```

## Configuration

Create a `bitwarden-config.conf` file based on the provided sample in the `config/` directory:

```bash
# Bitwarden server URL
BW_SERVER_URL="https://pwvault.turnsys.com"

# API credentials (from Bitwarden account settings)
BW_CLIENTID="your_client_id_here"
BW_CLIENTSECRET="your_client_secret_here"

# Master password
BW_PASSWORD="your_master_password_here"
```

**Security Note**: The actual configuration file is automatically ignored by git to prevent credential exposure.

## Usage

### Command Reference

```bash
./secrets-manager.sh [OPTIONS] COMMAND [ARGS]
```

#### Commands

- **`install`** - Install Bitwarden CLI
- **`get <secret_name>`** - Retrieve a specific secret
- **`list`** - List all available secrets in your vault
- **`test`** - Test configuration and connectivity

#### Options

- **`-c, --config FILE`** - Use specific config file (default: `./bitwarden-config.conf`)
- **`-h, --help`** - Show help message
- **`-v, --version`** - Show version information

### Examples

```bash
# Install Bitwarden CLI
./secrets-manager.sh install

# Test your configuration
./secrets-manager.sh test

# Get a specific secret
./secrets-manager.sh get APIKEY-pushover

# List all available secrets
./secrets-manager.sh list

# Use a custom config file
./secrets-manager.sh --config /path/to/custom.conf get my-secret
```

### Using in Scripts

```bash
#!/bin/bash
# Example: Load API key into environment variable
export PUSHOVER_API="$(./secrets-manager.sh get APIKEY-pushover)"

# Use the secret in your application
curl -X POST "https://api.pushover.net/1/messages.json" \
  -d "token=$PUSHOVER_API" \
  -d "user=your_user_key" \
  -d "message=Hello from TSYS!"
```

## Installation Methods

The script automatically tries multiple installation methods in order:

1. **Snap Package** (if snapd is available)
2. **NPM Global Package** (if npm is available)
3. **Direct Binary Download** (fallback method)

## Error Codes

| Code | Description |
|------|-------------|
| 10   | Configuration file not found |
| 20   | Bitwarden CLI not installed |
| 30   | Bitwarden CLI installation failed |
| 40   | Server configuration failed |
| 50   | Session/unlock failed |
| 60   | Secret not found |
| 70   | Login failed |

## Logging

All operations are logged to `/tmp/secrets-manager.sh.log` for debugging and audit purposes.

## Security Considerations

- Configuration files containing credentials are automatically gitignored
- Session tokens are properly cleaned up on script exit
- Master passwords are handled securely without shell history exposure
- All sensitive operations include proper error handling

## Legacy Scripts

## Repository Structure

```
KNELSecretsManager/
├── secrets-manager.sh           # Main secrets management script
├── README.md                    # This documentation
├── LICENSE                      # License information
├── Makefile                     # Build and test automation
├── .gitignore                   # Git ignore rules
├── bin/                        # Legacy scripts and utilities
│   ├── poc.sh                  # Original proof of concept
│   └── prod.sh                 # ChatGPT-assisted production attempt
├── config/                     # Configuration templates
│   └── bitwarden-config.conf.sample  # Sample configuration
├── tests/                      # Test suite
│   └── test-secrets-manager.sh # Comprehensive test framework
└── docs/                       # Documentation
    └── ADR-Node.md             # Architecture Decision Records
```

The main `secrets-manager.sh` script combines the best features of the legacy implementations while adding robust error handling, installation management, and improved security.

## Testing

This project includes a comprehensive test suite designed to work both standalone and when vendored into shell scripting frameworks.

### Running Tests

```bash
# Run all tests
./tests/test-secrets-manager.sh run

# Run tests in CI mode (no colors)
./tests/test-secrets-manager.sh --ci run

# Using Make (recommended)
make test          # Run all tests
make test-ci       # Run in CI mode
make lint          # Run shellcheck
make all           # Run deps, lint, and tests
```

### Test Coverage

The test suite covers:
- Script existence and permissions
- Command-line argument parsing
- Help and version output
- Error handling and exit codes
- Configuration file validation
- Bitwarden CLI dependency checks
- Performance and startup time
- Vendor integration compatibility

### Vendor Integration Testing

When this project is vendored into other shell scripting frameworks:

```bash
# Test as vendored dependency
make vendor-test

# Or manually
mkdir /tmp/vendor-test
cp secrets-manager.sh tests/test-secrets-manager.sh config/bitwarden-config.conf.sample /tmp/vendor-test/
cd /tmp/vendor-test && ./test-secrets-manager.sh --ci run
```

### Development Testing

```bash
# Setup development environment
make dev-setup

# Run tests with development config
make dev-test
```

## Architecture Decision Records

This project includes ADRs for key architectural decisions:

- **ADR-001**: [Node.js Version Management Strategy](docs/ADR-Node.md) - Analysis of MISE vs system packages for Node.js version management

## Contributing

When contributing to this project:

1. **Test all changes thoroughly**:
   ```bash
   make ci  # Run full CI pipeline
   ```

2. **Update documentation as needed**
3. **Follow existing code style and conventions**
4. **Run security checks**:
   ```bash
   make security-check
   ```

5. **Ensure compatibility with vendor integration**:
   ```bash
   make vendor-test
   ```

## Development Commands

```bash
make help           # Show all available commands
make install        # Install dependencies
make dev-setup      # Setup development environment
make lint           # Run shellcheck
make security-check # Basic security validation
make clean          # Clean temporary files
make docs           # Generate documentation
```

## License

See [LICENSE](LICENSE) file for details.