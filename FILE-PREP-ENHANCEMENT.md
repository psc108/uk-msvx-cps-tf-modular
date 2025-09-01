# Pre-Infrastructure File Preparation Enhancement

## Overview

This enhancement implements a two-phase deployment approach that eliminates race conditions and ensures all files are ready before any compute instances start.

## Implementation Summary

### New Components Created

1. **File Preparation Module** (`modules/file-prep/`)
   - Creates minimal infrastructure (VPC, subnet, EFS, temporary EC2)
   - Downloads all S3 files to EFS before main infrastructure
   - Extracts and patches installation packages
   - Self-terminates after completion

2. **Enhanced Deploy Scripts**
   - `deploy.ps1` and `deploy.sh` now support phased deployment
   - Auto-detection of deployment phase requirements
   - Improved error handling and user feedback

3. **Updated Storage Module**
   - Supports using pre-prepared EFS from file-prep phase
   - Backward compatible with traditional deployment

4. **Modified Compute Module**
   - Jump server detects pre-prepared files
   - Skips file download if files already prepared
   - Maintains compatibility with traditional approach

### Files Modified (Backups Created)

- `deploy.ps1` → `deploy.ps1.backup`
- `deploy.sh` → `deploy.sh.backup`
- `main.tf` → `main.tf.backup`
- `modules/storage/main.tf` → `modules/storage/main.tf.backup`

### New Files Created

- `modules/file-prep/main.tf`
- `modules/file-prep/variables.tf`
- `modules/file-prep/outputs.tf`
- `modules/file-prep/file-prep-userdata.sh`
- `test-file-prep.ps1`
- `test-file-prep.sh`

## Usage

### Phase 1: File Preparation Only
```powershell
# Windows
.\deploy.ps1 -PrepareFilesOnly

# Linux/macOS
./deploy.sh --prepare-files-only
```

### Phase 2: Full Infrastructure (Files Already Prepared)
```powershell
# Windows
.\deploy.ps1 -SkipFilePrep

# Linux/macOS
./deploy.sh --skip-file-prep
```

### Full Deployment (Both Phases Automatically)
```powershell
# Windows
.\deploy.ps1

# Linux/macOS
./deploy.sh
```

## Benefits

1. **Eliminates Race Conditions** - All files ready before any service starts
2. **Faster Service Startup** - No waiting for file downloads during instance boot
3. **Guaranteed File Availability** - Files present before compute instances launch
4. **Reduced Boot Time** - Instances start immediately with all dependencies ready
5. **Better Error Handling** - File issues caught early, not during service setup
6. **Improved Reliability** - Consistent file state across all instances

## Technical Details

### File Preparation Process

1. **S3 Upload** - Files uploaded to S3 bucket (existing process)
2. **Minimal Infrastructure** - VPC, subnet, security group, EFS created
3. **Temporary Instance** - Small EC2 instance launched with file-prep script
4. **File Distribution** - All S3 files downloaded and prepared in EFS
5. **Package Extraction** - Installation packages extracted and patched
6. **Cleanup** - Temporary instance self-terminates
7. **Ready State** - EFS contains all prepared files

### Deployment Phases

**Phase 1 Resources:**
- S3 files module
- File preparation module (temporary infrastructure + EFS with files)

**Phase 2 Resources:**
- All remaining infrastructure (networking, security, compute, database, DNS)
- Uses prepared EFS from Phase 1

### Backward Compatibility

The enhancement is fully backward compatible:
- Traditional single-phase deployment still works
- Jump server detects if files are pre-prepared
- Falls back to S3 download if files not prepared

## Testing

Use the provided test scripts to validate the implementation:

```powershell
# Test individual phases
.\test-file-prep.ps1 -TestPhase1Only
.\test-file-prep.ps1 -TestPhase2Only

# Test full deployment
.\test-file-prep.ps1 -TestFullDeployment
```

## Rollback Instructions

If issues occur, restore from backups:

```powershell
# Restore original files
copy deploy.ps1.backup deploy.ps1
copy deploy.sh.backup deploy.sh
copy main.tf.backup main.tf
copy modules\storage\main.tf.backup modules\storage\main.tf

# Remove new module
rmdir /s modules\file-prep

# Remove test files
del test-file-prep.ps1
del test-file-prep.sh
del FILE-PREP-ENHANCEMENT.md
```

## Architecture Impact

The enhancement adds a preparatory phase that creates a temporary, minimal infrastructure to prepare files before the main deployment. This approach:

- Reduces main deployment complexity
- Improves reliability and predictability
- Maintains clean separation between file preparation and infrastructure deployment
- Provides clear rollback points between phases

## Next Steps

1. Test the implementation with a development workspace
2. Validate file preparation timing and reliability
3. Monitor EFS performance with pre-loaded files
4. Consider cleanup automation for temporary file-prep infrastructure
5. Update documentation with new deployment patterns