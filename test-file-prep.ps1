# Test script for file preparation enhancement
param(
    [switch]$TestPhase1Only,
    [switch]$TestPhase2Only,
    [switch]$TestFullDeployment
)

Write-Host "=== File Preparation Enhancement Test Script ===" -ForegroundColor Cyan

if ($TestPhase1Only) {
    Write-Host "Testing Phase 1: File Preparation Only" -ForegroundColor Yellow
    .\deploy.ps1 -PrepareFilesOnly -AutoApprove
} elseif ($TestPhase2Only) {
    Write-Host "Testing Phase 2: Full Infrastructure (Skip File Prep)" -ForegroundColor Yellow
    .\deploy.ps1 -SkipFilePrep -AutoApprove
} elseif ($TestFullDeployment) {
    Write-Host "Testing Full Deployment: Both Phases Automatically" -ForegroundColor Yellow
    .\deploy.ps1 -AutoApprove
} else {
    Write-Host "Usage:" -ForegroundColor White
    Write-Host "  .\test-file-prep.ps1 -TestPhase1Only      # Test file preparation only"
    Write-Host "  .\test-file-prep.ps1 -TestPhase2Only      # Test full infrastructure (files already prepared)"
    Write-Host "  .\test-file-prep.ps1 -TestFullDeployment  # Test complete deployment"
    Write-Host ""
    Write-Host "Manual Usage:" -ForegroundColor White
    Write-Host "  .\deploy.ps1 -PrepareFilesOnly            # Phase 1: Prepare files in EFS"
    Write-Host "  .\deploy.ps1 -SkipFilePrep                # Phase 2: Deploy infrastructure with prepared files"
    Write-Host "  .\deploy.ps1                              # Full deployment (both phases)"
}