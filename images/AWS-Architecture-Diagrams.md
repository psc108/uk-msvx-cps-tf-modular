# AWS Architecture Diagrams

This directory contains both Mermaid and draw.io format architecture diagrams for the CSO Shared Services Portal.

## Available Formats

### 1. Mermaid Diagrams (Text-based)
- `architecture-ha.md` - High Availability deployment
- `architecture-single-node.md` - Single-node deployment  
- `terraform-modules.md` - Module structure
- `deployment-flow.md` - Deployment sequence

### 2. Draw.io Diagrams (AWS Iconography)
- `cso-ha-architecture.drawio` - HA deployment with AWS icons
- `cso-single-node-architecture.drawio` - Single-node with AWS icons

## Using Draw.io Diagrams

### Online Viewing
1. Go to [app.diagrams.net](https://app.diagrams.net)
2. Click "Open Existing Diagram"
3. Upload the `.drawio` file

### VS Code Integration
1. Install "Draw.io Integration" extension
2. Open `.drawio` files directly in VS Code
3. Edit diagrams within the IDE

### Desktop Application
1. Download draw.io desktop app
2. Open `.drawio` files directly

## Architecture Highlights

### HA Architecture Features
- **AWS Cognito Authentication** - OIDC integration with ALB
- **Multi-AZ Deployment** - Fault tolerance across availability zones
- **Load Balancer** - Application Load Balancer with listener rules
- **Encrypted Storage** - EBS, EFS, and RDS encryption with KMS
- **Security Services** - Secrets Manager, KMS, and Cognito integration

### Single-Node Architecture Features
- **Direct Access** - No load balancer, direct EIP access
- **Cost Optimized** - Smaller instance sizes for development
- **Single AZ** - All resources in one availability zone
- **Simplified Networking** - Basic public/private subnet design

## Authentication Flows

### HA Deployment (with Cognito)
1. User → ALB (HTTPS:8102)
2. ALB Listener Rule → Cognito
3. Cognito → OAuth2 Login Page
4. User Authentication → Cognito
5. OAuth2 Callback → ALB (/oauth2/idpresponse)
6. ALB → Frontend Servers (authenticated)

### Single-Node Deployment (direct)
1. User → Frontend Server (HTTPS:8102)
2. Direct access to CSO application
3. CSO application authentication only

## Technical Specifications

### AWS Services Depicted
- **Compute**: EC2 instances with proper sizing
- **Networking**: VPC, subnets, IGW, NAT Gateway, ALB
- **Storage**: RDS MySQL, EFS shared storage
- **Security**: KMS, Secrets Manager, Cognito
- **DNS**: Route53 private hosted zones

### Color Coding
- **Orange (#ED7100)**: EC2 Compute instances
- **Blue (#3F48CC)**: Storage services (RDS, EFS)
- **Purple (#8C4FFF)**: Networking services (ALB, Route53)
- **Yellow (#FF9900)**: Security services (KMS, Secrets, Cognito)
- **Green (#248814)**: VPC and networking boundaries

## Exporting Diagrams

### From draw.io to Images
1. Open diagram in draw.io
2. File → Export as → PNG/SVG/PDF
3. Choose resolution and format
4. Download exported image

### From Mermaid to Images
```bash
# Install mermaid-cli
npm install -g @mermaid-js/mermaid-cli

# Convert to PNG
mmdc -i architecture-ha.md -o architecture-ha.png
mmdc -i architecture-single-node.md -o architecture-single-node.png
```

## Integration with Documentation

These diagrams complement the technical documentation in:
- `/readme/README.md` - Deployment and usage instructions
- `/DEPLOYMENT_VALIDATION.md` - Technical validation details
- Environment YAML files - Configuration specifications

The draw.io diagrams provide professional AWS iconography suitable for:
- Architecture reviews
- Technical presentations  
- Documentation attachments
- Stakeholder communications