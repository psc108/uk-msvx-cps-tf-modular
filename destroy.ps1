# Destroy CSO infrastructure
param(
    [Parameter(ValueFromRemainingArguments=$true)]
    [string[]]$TerraformArgs
)

$workspace = terraform workspace show
Write-Host "Destroying infrastructure for workspace: $workspace"

$cmd = "terraform destroy -auto-approve $($TerraformArgs -join ' ')"
Write-Host "Running: $cmd"
Invoke-Expression $cmd