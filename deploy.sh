#!/bin/bash
# Smart deployment script with pre-infrastructure file preparation

# Parse command line arguments
PREPARE_FILES_ONLY=false
SKIP_FILE_PREP=false
AUTO_APPROVE=false
TERRAFORM_ARGS=()

while [[ $# -gt 0 ]]; do
    case $1 in
        --prepare-files-only)
            PREPARE_FILES_ONLY=true
            shift
            ;;
        --skip-file-prep)
            SKIP_FILE_PREP=true
            shift
            ;;
        --auto-approve)
            AUTO_APPROVE=true
            shift
            ;;
        *)
            TERRAFORM_ARGS+=("$1")
            shift
            ;;
    esac
done

WORKSPACE=$(terraform workspace show)
BUCKET_NAME="${WORKSPACE}-cso-files"

# Handle file preparation phases
if [ "$PREPARE_FILES_ONLY" = true ]; then
    echo "=== PHASE 1: File Preparation Only ==="
    TERRAFORM_ARGS+=("-var" "enable_file_prep=true" "-target" "module.s3_files" "-target" "module.file_prep[0]")
elif [ "$SKIP_FILE_PREP" = true ]; then
    echo "=== PHASE 2: Full Infrastructure (Files Already Prepared) ==="
    TERRAFORM_ARGS+=("-var" "enable_file_prep=false")
else
    # Ask user if they want to skip file prep or update S3
    if [ "$AUTO_APPROVE" != true ]; then
        echo "Files need to be prepared. Choose an option:"
        echo "  Y/yes - Skip file preparation (files already prepared)"
        echo "  N/no  - Update S3 and proceed with full deployment"
        read -p "Skip file preparation? (Y/N): " response
        
        if [[ "$response" =~ ^[Yy]([Ee][Ss])?$ ]]; then
            echo "=== PHASE 2: Full Infrastructure (Files Already Prepared) ==="
            TERRAFORM_ARGS+=("-var" "enable_file_prep=false")
        else
            echo "=== FULL DEPLOYMENT: File Preparation + Infrastructure ==="
            TERRAFORM_ARGS+=("-var" "enable_file_prep=false")
        fi
    else
        echo "=== FULL DEPLOYMENT: File Preparation + Infrastructure ==="
        TERRAFORM_ARGS+=("-var" "enable_file_prep=false")
    fi
fi

echo "Checking S3 bucket: $BUCKET_NAME"

# Compare local files with S3 files by name and size
if [ -d "files" ]; then
    NEEDS_UPLOAD=false
    UPLOAD_REASONS=""
    
    echo "Comparing local files with S3..."
    
    find files -type f | while read -r file; do
        RELATIVE_PATH=${file#files/}
        LOCAL_SIZE=$(stat -c%s "$file")
        
        # Get S3 file info
        S3_INFO=$(aws s3api head-object --bucket "$BUCKET_NAME" --key "$RELATIVE_PATH" 2>/dev/null)
        
        if [ $? -ne 0 ]; then
            echo "  ✗ Missing: $RELATIVE_PATH"
            NEEDS_UPLOAD=true
            UPLOAD_REASONS="$UPLOAD_REASONS Missing: $RELATIVE_PATH;"
        else
            S3_SIZE=$(echo "$S3_INFO" | jq -r '.ContentLength')
            if [ "$S3_SIZE" != "$LOCAL_SIZE" ]; then
                echo "  ✗ Size diff: $RELATIVE_PATH (Local: $LOCAL_SIZE, S3: $S3_SIZE)"
                NEEDS_UPLOAD=true
                UPLOAD_REASONS="$UPLOAD_REASONS Size diff: $RELATIVE_PATH;"
            else
                echo "  ✓ Match: $RELATIVE_PATH ($LOCAL_SIZE bytes)"
            fi
        fi
    done
    
    if [ "$NEEDS_UPLOAD" = true ]; then
        echo "Files need upload: $UPLOAD_REASONS"
        UPLOAD_FILES="true"
    else
        echo "All files match - skipping upload"
        UPLOAD_FILES="false"
    fi
else
    echo "Local files directory not found - skipping upload"
    UPLOAD_FILES="false"
fi

# Determine plan file name based on phase
if [ "$PREPARE_FILES_ONLY" = true ]; then
    PLAN_FILE="${WORKSPACE}-fileprep-plan.tfplan"
else
    PLAN_FILE="${WORKSPACE}-plan.tfplan"
fi

echo "Running: terraform plan -out=$PLAN_FILE ${TERRAFORM_ARGS[*]}"
terraform plan -out="$PLAN_FILE" "${TERRAFORM_ARGS[@]}"

if [ $? -eq 0 ] && [ -f "$PLAN_FILE" ]; then
    if [ "$AUTO_APPROVE" = true ] || [ "$PREPARE_FILES_ONLY" = true ]; then
        echo "Running: terraform apply -auto-approve $PLAN_FILE"
        terraform apply -auto-approve "$PLAN_FILE"
    else
        echo "Running: terraform apply $PLAN_FILE"
        terraform apply "$PLAN_FILE"
    fi
    
    # If this was file prep only, provide next steps
    if [ "$PREPARE_FILES_ONLY" = true ] && [ $? -eq 0 ]; then
        echo ""
        echo "=== FILE PREPARATION COMPLETE ==="
        echo "Files are now prepared in EFS. Run full deployment with:"
        echo "  ./deploy.sh --skip-file-prep"
    fi
else
    echo "Plan failed or plan file not created, aborting apply"
    exit 1
fi