# Remove S3 file resources from Terraform state
# These are now managed by AWS CLI uploads instead of Terraform

Write-Host "Removing S3 file resources from Terraform state..."

# Remove all S3 objects from state
terraform state list | Where-Object { $_ -match "module\.s3_files\.aws_s3_object" } | ForEach-Object {
    Write-Host "Removing: $_"
    cmd /c "terraform state rm `"$_`""
}

# Remove SSM resources that managed S3 files
$ssmResources = @(
    "aws_ssm_document.cso_setup",
    "aws_ssm_association.cso_setup"
)

foreach ($resource in $ssmResources) {
    if (terraform state list | Where-Object { $_ -eq $resource }) {
        Write-Host "Removing: $resource"
        terraform state rm $resource
    }
}

Write-Host "State cleanup completed. S3 files are now managed by AWS CLI."