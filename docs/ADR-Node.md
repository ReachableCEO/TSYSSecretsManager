# ADR-001: Node.js Version Management Strategy

## Status
Proposed

## Context

The TSYS Secrets Manager project needs to make an architectural decision regarding Node.js version management across development, staging, and production environments. This decision impacts:

- Development workflow and environment consistency
- Production stability and security posture
- Operational complexity and maintenance overhead
- Compliance with enterprise security policies
- Integration with existing shell scripting frameworks

As this project will be git vendor included into shell scripting frameworks, the Node.js management approach must be portable and not introduce complex dependencies on the consuming systems.

## Decision Drivers

1. **Security and Compliance**: Enterprise security requirements mandate automated security updates and clear audit trails
2. **Operational Simplicity**: Minimize operational overhead and complexity in production environments
3. **Development Efficiency**: Enable developers to work with appropriate Node.js versions for different projects
4. **Vendor Integration**: Support clean integration when vendored into other shell scripting frameworks
5. **Stability**: Ensure production deployments are stable and predictable
6. **Version Flexibility**: Ability to test and deploy with specific Node.js versions when needed

## Options Considered

### Option 1: MISE (Modern Infrastructure Software Engineering)
**Description**: Use MISE for polyglot runtime version management across all environments.

**Pros**:
- Zero-overhead performance (no shims, direct binary execution)
- Multi-version support with automatic project-based switching
- Modern Rust-based implementation with enhanced security
- Excellent developer experience with unified tooling
- Support for `.nvmrc` and other standard version files
- Task runner capabilities

**Cons**:
- Additional operational complexity in production
- Custom security update processes required
- Not managed by distribution security teams
- Requires team training and adoption
- May complicate vendor integration scenarios

### Option 2: System Package Manager (Debian apt)
**Description**: Use distribution-provided Node.js packages for all environments.

**Pros**:
- Managed by Debian security team with automatic updates
- Battle-tested in enterprise environments
- Integration with existing configuration management
- Clear audit trails and compliance support
- Minimal operational overhead
- Standard enterprise security practices

**Cons**:
- Often outdated versions (significant lag behind releases)
- Limited to single system-wide version
- Cannot easily test multiple Node.js versions
- May not support latest language features
- Difficulty matching exact versions across environments

### Option 3: Containerized Deployment with Official Images
**Description**: Use official Node.js Docker images with pinned versions.

**Pros**:
- Reproducible deployments with exact version control
- Security scanning and automated vulnerability management
- Isolation from host system dependencies
- Industry standard approach for modern deployments
- Easy version management through Dockerfile

**Cons**:
- Requires container orchestration infrastructure
- Additional complexity for simple script deployments
- May be overkill for shell script frameworks
- Learning curve for container-naive environments

### Option 4: Hybrid Approach
**Description**: Use different tools for different environments and use cases.

**Pros**:
- Optimized approach for each environment's specific needs
- Flexibility to choose best tool for each scenario
- Can evolve strategy as requirements change

**Cons**:
- Increased complexity managing multiple approaches
- Potential for environment drift and inconsistencies
- More documentation and training required

## Decision

**Selected: Option 4 - Hybrid Approach with System Packages as Primary**

### Primary Strategy:
- **Production Environments**: Use Debian system packages (apt) for Node.js installation
- **Development Environments**: Use MISE for flexibility and multi-version testing
- **Vendor Integration**: Document both approaches, default to system packages

### Rationale:

1. **Security-First Production**: System packages provide the security posture required for enterprise production environments with automated security updates and established audit trails.

2. **Development Flexibility**: MISE enables developers to test across multiple Node.js versions and maintain development-production parity when needed.

3. **Vendor-Friendly**: When this project is vendored into shell scripting frameworks, defaulting to system packages minimizes external dependencies and complexity for consuming systems.

4. **Gradual Adoption**: Teams can start with system packages and adopt MISE for development as needed, without disrupting production systems.

## Implementation Guidelines

### For Production Deployments:
```bash
# Install Node.js via system package manager
sudo apt update
sudo apt install nodejs npm

# Verify installation
node --version
npm --version
```

### For Development Environments:
```bash
# Install MISE
curl https://mise.run | sh

# Configure for project
mise use node@18.17.0
mise use node@20.9.0  # For testing newer versions

# Project-specific configuration
echo "node 18.17.0" > .tool-versions
```

### For Vendor Integration:
- Default installation scripts should use system packages
- Provide optional MISE support for advanced users
- Document both approaches clearly
- Include version compatibility matrix

## Consequences

### Positive:
- Production systems maintain enterprise security standards
- Development teams gain version management flexibility
- Reduced vendor integration complexity
- Clear separation of concerns between environments
- Future migration paths remain open

### Negative:
- Increased documentation requirements
- Potential for environment drift if not managed properly
- Team training required for both approaches
- Slightly more complex CI/CD pipelines

### Neutral:
- Need to maintain compatibility with both package management approaches
- Version testing required across both installation methods

## Compliance and Security Considerations

### System Package Approach:
- Automatic security updates via `unattended-upgrades`
- Integration with enterprise vulnerability scanners
- Standard audit procedures apply
- Compliance with distribution security policies

### MISE Approach (Development Only):
- Manual security update processes
- Custom vulnerability monitoring required
- Developer responsibility for version management
- Clear policies needed for version selection

## Monitoring and Metrics

### Track:
- Node.js version distribution across environments
- Security update lag time between environments
- Developer adoption of MISE in development
- Issues related to version mismatches

### Success Criteria:
- Zero production security incidents related to Node.js versions
- <1 week lag time for critical security updates in production
- >90% developer satisfaction with version management workflow
- Successful vendor integrations with minimal friction

## Review Schedule

This ADR should be reviewed:
- Quarterly for the first year
- Annually thereafter
- When major Node.js LTS versions are released
- After significant security incidents
- When vendor integration patterns change

## References

- [MISE Documentation](https://mise.jdx.dev/)
- [Node.js Release Schedule](https://nodejs.org/en/about/releases/)
- [Debian Node.js Packages](https://packages.debian.org/search?keywords=nodejs)
- [Enterprise Node.js Security Best Practices](https://nodejs.org/en/docs/guides/security/)

---

**Decision Date**: 2025-07-16  
**Decision Makers**: Architecture Team, Security Team, DevOps Team  
**Next Review**: 2025-10-16