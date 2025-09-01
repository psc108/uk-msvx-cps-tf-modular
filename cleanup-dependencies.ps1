# Cleanup AWS dependencies before Terraform destroy
# This script removes dependencies that prevent Terraform from destroying resources

Write-Host "Starting AWS dependency cleanup..."

# Function to check if AWS CLI is available
function Test-AwsCli {
    try {
        aws --version | Out-Null
        return $true
    }
    catch {
        Write-Error "AWS CLI not found. Please install AWS CLI and configure credentials."
        return $false
    }
}

# Function to remove EFS mount targets
function Remove-EfsMountTargets {
    param($FileSystemId)
    
    Write-Host "Removing EFS mount targets for $FileSystemId..."
    
    try {
        $mountTargets = aws efs describe-mount-targets --file-system-id $FileSystemId --query 'MountTargets[].MountTargetId' --output text
        
        if ($mountTargets -and $mountTargets -ne "None") {
            $mountTargetIds = $mountTargets -split "`t"
            foreach ($mountTargetId in $mountTargetIds) {
                if ($mountTargetId.Trim()) {
                    Write-Host "Deleting mount target: $mountTargetId"
                    aws efs delete-mount-target --mount-target-id $mountTargetId.Trim()
                }
            }
            
            # Wait for mount targets to be deleted
            Write-Host "Waiting for mount targets to be deleted..."
            do {
                Start-Sleep -Seconds 5
                $remainingTargets = aws efs describe-mount-targets --file-system-id $FileSystemId --query 'MountTargets[].MountTargetId' --output text 2>$null
            } while ($remainingTargets -and $remainingTargets -ne "None")
            
            Write-Host "All mount targets deleted for $FileSystemId"
        }
    }
    catch {
        Write-Warning "Failed to remove mount targets for $FileSystemId : $_"
    }
}

# Function to find and remove security group dependencies
function Remove-SecurityGroupDependencies {
    param($SecurityGroupId)
    
    Write-Host "Checking dependencies for security group $SecurityGroupId..."
    
    try {
        # Check for ENIs using this security group
        $enis = aws ec2 describe-network-interfaces --filters "Name=group-id,Values=$SecurityGroupId" --query 'NetworkInterfaces[].NetworkInterfaceId' --output text
        
        if ($enis -and $enis -ne "None") {
            Write-Host "Found ENIs using security group: $enis"
            # Note: ENIs are typically deleted when their associated resources are deleted
        }
        
        # Check for instances using this security group
        $instances = aws ec2 describe-instances --filters "Name=instance.group-id,Values=$SecurityGroupId" --query 'Reservations[].Instances[].InstanceId' --output text
        
        if ($instances -and $instances -ne "None") {
            Write-Host "Found instances using security group: $instances"
            # Note: Instances should be terminated by Terraform
        }
    }
    catch {
        Write-Warning "Failed to check dependencies for security group $SecurityGroupId : $_"
    }
}

# Main cleanup process
if (-not (Test-AwsCli)) {
    exit 1
}

# Clean up EFS mount targets
Write-Host "Cleaning up EFS mount targets..."
Remove-EfsMountTargets "fs-05c57eb446b01106f"

# Check security group dependencies
Write-Host "Checking security group dependencies..."
Remove-SecurityGroupDependencies "sg-09abb682ead36ec9b"

# Wait a bit for AWS to process deletions
Write-Host "Waiting for AWS to process deletions..."
Start-Sleep -Seconds 10

Write-Host "Dependency cleanup completed. You can now run 'terraform destroy' again."