# Keystone High Availability Clustering

## Overview
This document outlines the approach for clustering two Keystone servers to provide high availability and load distribution for the identity service.

## Current Architecture
- **keystone01.dev-ha.local** - Primary Keystone server
- **keystone02.dev-ha.local** - Secondary Keystone server
- **Shared RDS Database** - Both servers connect to the same MySQL database
- **Application Load Balancer** - Distributes traffic between servers

## Clustering Components

### 1. Database Layer (Already Implemented)
- **Shared RDS Instance**: Both Keystone servers connect to the same RDS MySQL database
- **Database Schema**: Single keystone database shared between both servers
- **Connection String**: `mysql+pymysql://keystone:KeystonePass123@dev-ha-db.ceumaalxwunl.eu-west-2.rds.amazonaws.com/keystone`

### 2. Fernet Key Synchronization
Keystone uses Fernet tokens that must be synchronized across all nodes.

**Implementation Options:**
- **EFS Shared Storage**: Mount shared EFS volume at `/etc/keystone/fernet-keys/`
- **Key Rotation Script**: Automated script to sync keys between servers
- **Manual Sync**: Copy keys from primary to secondary during setup

**Recommended Approach - EFS:**
```bash
# Mount EFS for fernet keys
mount -t efs fs-12345678:/ /etc/keystone/fernet-keys/
```

### 3. Load Balancer Configuration
**Application Load Balancer (ALB) Setup:**
- **Target Group**: Both keystone servers on port 5000
- **Health Check**: `GET /api/idm/v3` endpoint
- **SSL Termination**: ALB handles SSL, forwards HTTP to backends
- **Sticky Sessions**: Not required for stateless tokens

**Target Group Configuration:**
```
Protocol: HTTPS
Port: 5000
Health Check Path: /api/idm/v3
Health Check Interval: 30s
Healthy Threshold: 2
Unhealthy Threshold: 3
```

### 4. Service Discovery
**DNS Configuration:**
- **Primary Endpoint**: `keystone.dev-ha.local` → ALB
- **Individual Servers**: `keystone01.dev-ha.local`, `keystone02.dev-ha.local`
- **Internal Resolution**: Route 53 private hosted zone

## Implementation Steps

### Phase 1: Prepare Second Server
1. Deploy keystone02 using same setup scripts
2. Ensure both servers connect to shared RDS database
3. Verify individual server functionality

### Phase 2: Fernet Key Synchronization
1. **Option A - EFS Mount:**
   ```bash
   # On both servers
   mkdir -p /etc/keystone/fernet-keys-shared
   mount -t efs fs-12345678:/ /etc/keystone/fernet-keys-shared
   ln -sf /etc/keystone/fernet-keys-shared /etc/keystone/fernet-keys
   ```

2. **Option B - Key Sync Script:**
   ```bash
   # Copy keys from primary to secondary
   scp -r keystone01:/etc/keystone/fernet-keys/* keystone02:/etc/keystone/fernet-keys/
   ```

### Phase 3: Load Balancer Setup
1. Create ALB target group with both servers
2. Configure health checks
3. Update DNS to point to ALB
4. Test failover scenarios

### Phase 4: Monitoring & Maintenance
1. **Health Monitoring**: CloudWatch alarms for server health
2. **Key Rotation**: Automated fernet key rotation across cluster
3. **Database Monitoring**: RDS performance and connection monitoring

## Configuration Files

### Keystone Configuration (Both Servers)
```ini
[DEFAULT]

[database]
connection = mysql+pymysql://keystone:KeystonePass123@dev-ha-db.ceumaalxwunl.eu-west-2.rds.amazonaws.com/keystone

[token]
provider = fernet

[fernet_tokens]
key_repository = /etc/keystone/fernet-keys/
```

### Apache Virtual Host (Both Servers)
```apache
<VirtualHost *:5000>
    ServerName keystone.dev-ha.local
    WSGIDaemonProcess keystone-public processes=5 threads=1
    WSGIProcessGroup keystone-public
    WSGIScriptAlias /api/idm /usr/local/bin/keystone-wsgi-public
    
    # Health check endpoint
    <Location /api/idm/v3>
        Require all granted
    </Location>
</VirtualHost>
```

## Testing Cluster

### Functional Tests
```bash
# Test individual servers
curl -k https://keystone01.dev-ha.local:5000/api/idm/v3
curl -k https://keystone02.dev-ha.local:5000/api/idm/v3

# Test load balancer
curl -k https://keystone.dev-ha.local/api/idm/v3

# Test token consistency
openstack --os-auth-url https://keystone.dev-ha.local/api/idm/v3 token issue
```

### Failover Tests
1. Stop keystone service on primary server
2. Verify traffic routes to secondary
3. Restart primary and verify load distribution
4. Test token validation across both servers

## Security Considerations
- **SSL Certificates**: Ensure both servers have valid certificates
- **Network Security**: Restrict inter-server communication to required ports
- **Database Security**: Use least-privilege database credentials
- **Key Security**: Protect fernet keys with appropriate file permissions

## Maintenance Procedures
- **Rolling Updates**: Update one server at a time to maintain availability
- **Key Rotation**: Coordinate fernet key rotation across cluster
- **Database Maintenance**: Schedule during low-traffic periods
- **Backup Strategy**: Regular backups of database and configuration

## Troubleshooting
- **Token Validation Failures**: Check fernet key synchronization
- **Database Connection Issues**: Verify RDS connectivity from both servers
- **Load Balancer Issues**: Check target group health status
- **SSL Certificate Problems**: Ensure certificates match server names