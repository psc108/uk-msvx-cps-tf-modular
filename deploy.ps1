# Smart deployment script with pre-infrastructure file preparation
param(
    [Parameter(ValueFromRemainingArguments=$true)]
    [string[]]$TerraformArgs,
    [switch]$Destroy,
    [switch]$PrepareFilesOnly,
    [switch]$SkipFilePrep,
    [switch]$AutoApprove
)

$workspace = terraform workspace show
$bucketName = "$workspace-cso-files"

# Handle file preparation phases
if ($PrepareFilesOnly) {
    Write-Host "=== PHASE 1: File Preparation Only ===" -ForegroundColor Cyan
    $TerraformArgs += "-var", "enable_file_prep=true"
    $TerraformArgs += "-target", "module.s3_files"
    $TerraformArgs += "-target", "module.file_prep[0]"
} elseif ($SkipFilePrep) {
    Write-Host "=== PHASE 2: Full Infrastructure (Files Already Prepared) ===" -ForegroundColor Cyan
    $TerraformArgs += "-var", "enable_file_prep=false"
} else {
    # Ask user if they want to skip file prep or update S3
    if (-not $AutoApprove) {
        Write-Host "Files need to be prepared. Choose an option:" -ForegroundColor Yellow
        Write-Host "  Y/yes - Skip file preparation (files already prepared)" -ForegroundColor White
        Write-Host "  N/no  - Update S3 and proceed with full deployment" -ForegroundColor White
        $response = Read-Host "Skip file preparation? (Y/N)"
        
        if ($response -match "^[Yy]([Ee][Ss])?$") {
            Write-Host "=== PHASE 2: Full Infrastructure (Files Already Prepared) ===" -ForegroundColor Cyan
            $TerraformArgs += "-var", "enable_file_prep=false"
        } else {
            Write-Host "=== FULL DEPLOYMENT: File Preparation + Infrastructure ===" -ForegroundColor Cyan
            $TerraformArgs += "-var", "enable_file_prep=false"
        }
    } else {
        Write-Host "=== FULL DEPLOYMENT: File Preparation + Infrastructure ===" -ForegroundColor Cyan
        $TerraformArgs += "-var", "enable_file_prep=false"
    }
}

Write-Host "Checking S3 bucket: $bucketName"

# Compare local files with S3 files by checking existence
try {
    if (Test-Path "files") {
        $localFiles = Get-ChildItem -Path "files" -Recurse -File
        $needsUpload = $false
        $uploadReasons = @()
        
        Write-Host "Comparing local files with S3..."
        
        # Get S3 file list once
        $s3Files = @{}
        $s3Output = aws s3 ls "s3://$bucketName" --recursive 2>$null
        if ($LASTEXITCODE -eq 0 -and $s3Output) {
            foreach ($line in $s3Output -split "`n") {
                if ($line -match "^\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2}\s+(\d+)\s+(.+)$") {
                    $s3Files[$matches[2]] = [int]$matches[1]
                }
            }
        }
        
        $filesToUpload = @()
        foreach ($file in $localFiles) {
            $relativePath = $file.FullName.Substring((Get-Item "files").FullName.Length + 1).Replace("\", "/")
            $localSize = $file.Length
            
            if ($s3Files.ContainsKey($relativePath)) {
                $s3Size = $s3Files[$relativePath]
                if ($s3Size -ne $localSize) {
                    Write-Host "  Size diff: $relativePath (Local: $localSize, S3: $s3Size)" -ForegroundColor Yellow
                    $filesToUpload += $file
                    $uploadReasons += "Size diff: $relativePath"
                } else {
                    Write-Host "  Match: $relativePath ($localSize bytes)" -ForegroundColor Green
                }
            } else {
                Write-Host "  Missing: $relativePath" -ForegroundColor Red
                $filesToUpload += $file
                $uploadReasons += "Missing: $relativePath"
            }
        }
        
        # Upload missing/changed files using AWS CLI
        if ($filesToUpload.Count -gt 0) {
            Write-Host "Uploading $($filesToUpload.Count) files to S3..." -ForegroundColor Yellow
            foreach ($file in $filesToUpload) {
                $relativePath = $file.FullName.Substring((Get-Item "files").FullName.Length + 1).Replace("\", "/")
                Write-Host "  Uploading: $relativePath"
                aws s3 cp $file.FullName "s3://$bucketName/$relativePath"
            }
            Write-Host "File upload completed" -ForegroundColor Green
        }
        
        if ($filesToUpload.Count -gt 0) {
            Write-Host "Files uploaded: $($uploadReasons -join ', ')" -ForegroundColor Yellow
        } else {
            Write-Host "All files match - no S3 uploads needed" -ForegroundColor Green
        }
    } else {
        Write-Host "Local files directory not found" -ForegroundColor Red
    }
} catch {
    Write-Host "Error comparing files: $($_.Exception.Message)" -ForegroundColor Yellow
}

# Handle destroy operations
if ($Destroy) {
    Write-Host "Running dependency cleanup before destroy..." -ForegroundColor Yellow
    if (Test-Path "cleanup-dependencies.ps1") {
        & .\cleanup-dependencies.ps1
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Dependency cleanup failed, continuing with destroy anyway..." -ForegroundColor Yellow
        }
    }
    
    $destroyCmd = "terraform destroy -auto-approve $($TerraformArgs -join ' ')"
    Write-Host "Running: $destroyCmd"
    Invoke-Expression $destroyCmd
    exit $LASTEXITCODE
}

# Determine plan file name based on phase
if ($PrepareFilesOnly) {
    $planFile = "$workspace-fileprep-plan.tfplan"
} else {
    $planFile = "$workspace-plan.tfplan"
}

$planCmd = "terraform plan -out=`"$planFile`" $($TerraformArgs -join ' ')"
Write-Host "Running: $planCmd"
Invoke-Expression $planCmd

if ($LASTEXITCODE -eq 0 -and (Test-Path $planFile)) {
    if ($AutoApprove -or $PrepareFilesOnly) {
        $applyCmd = "terraform apply -auto-approve `"$planFile`""
    } else {
        $applyCmd = "terraform apply `"$planFile`""
    }
    Write-Host "Running: $applyCmd"
    Invoke-Expression $applyCmd
    
    # If this was file prep only, provide next steps
    if ($PrepareFilesOnly -and $LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "=== FILE PREPARATION COMPLETE ===" -ForegroundColor Green
        Write-Host "Files are now prepared in EFS. Run full deployment with:" -ForegroundColor Yellow
        Write-Host "  .\deploy.ps1 -SkipFilePrep" -ForegroundColor White
    }
} else {
    Write-Host "Plan failed or plan file not created, aborting apply" -ForegroundColor Red
    exit 1
}