# CSO Architecture Diagrams

This directory contains architectural diagrams for the CSO Shared Services Portal Terraform deployment.

## Diagrams

### 1. Single-Node Architecture (`architecture-single-node.md`)
Shows the development/testing deployment with all services in a single availability zone:
- Single frontend server with EIP
- All backend services in private subnet
- Single NAT gateway for internet access
- Smaller instance sizes for cost optimization

### 2. High Availability Architecture (`architecture-ha.md`)
Shows the production HA deployment across two availability zones:
- Redundant frontend servers behind Application Load Balancer
- AWS Cognito OIDC authentication with ALB listener rules
- Automatic OAuth2 callback configuration (port 8102)
- Services distributed across multiple AZs
- Redundant NAT gateways for fault tolerance
- Multi-AZ RDS for database high availability
- Production-sized instances with comprehensive security

### 3. Terraform Module Structure (`terraform-modules.md`)
Shows the modular Terraform architecture:
- 6 focused modules (networking, security, storage, database, compute, dns)
- Clear dependency relationships
- External integrations (Secrets Manager, AMI lookup)

### 4. Deployment Flow (`deployment-flow.md`)
Shows the complete deployment sequence:
- Infrastructure provisioning phases
- Service installation and configuration
- Dependency management and timing

## Viewing the Diagrams

These diagrams are written in Mermaid format and can be viewed in:

1. **GitHub** - Renders Mermaid diagrams natively
2. **VS Code** - With Mermaid preview extension
3. **Online** - Copy content to https://mermaid.live/
4. **Export** - Use mermaid-cli to generate PNG/SVG files

## Available Formats

### Mermaid Diagrams (Text-based)
These diagrams are written in Mermaid format and can be viewed in GitHub, VS Code, or online.

### Draw.io Diagrams (AWS Iconography)
- `cso-ha-architecture.drawio` - Professional HA architecture with AWS icons
- `cso-single-node-architecture.drawio` - Single-node architecture with AWS icons

**To view draw.io diagrams:**
1. Go to [app.diagrams.net](https://app.diagrams.net)
2. Click "Open Existing Diagram" and upload the `.drawio` file
3. Or install "Draw.io Integration" extension in VS Code

## Converting to Images

**Mermaid to PNG:**
```bash
# Install mermaid-cli
npm install -g @mermaid-js/mermaid-cli

# Convert to PNG
mmdc -i architecture-single-node.md -o architecture-single-node.png
mmdc -i architecture-ha.md -o architecture-ha.png
mmdc -i terraform-modules.md -o terraform-modules.png
mmdc -i deployment-flow.md -o deployment-flow.png
```

**Draw.io to PNG/SVG:**
1. Open diagram in app.diagrams.net
2. File → Export as → PNG/SVG/PDF
3. Choose resolution and download

## Architecture Highlights

### Single-Node Benefits
- **Cost-effective** for development/testing
- **Simple networking** with single AZ
- **Quick deployment** with minimal resources
- **Easy troubleshooting** with centralized components

### HA Benefits
- **Fault tolerance** across multiple AZs
- **Load balancing** with automated OIDC authentication
- **OAuth2 integration** with automatic callback configuration
- **Database redundancy** with Multi-AZ RDS
- **Production scaling** with larger instances
- **Zero-downtime** maintenance capabilities
- **Enterprise security** with encryption, KMS, and user management
- **Well-Architected compliance** across all pillars

### Modular Design Benefits
- **Separation of concerns** with focused modules
- **Reusable components** for different environments
- **Independent testing** of module functionality
- **Clear dependency management** and ordering