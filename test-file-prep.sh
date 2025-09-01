#!/bin/bash
# Test script for file preparation enhancement

echo "=== File Preparation Enhancement Test Script ==="

case "$1" in
    --test-phase1)
        echo "Testing Phase 1: File Preparation Only"
        ./deploy.sh --prepare-files-only --auto-approve
        ;;
    --test-phase2)
        echo "Testing Phase 2: Full Infrastructure (Skip File Prep)"
        ./deploy.sh --skip-file-prep --auto-approve
        ;;
    --test-full)
        echo "Testing Full Deployment: Both Phases Automatically"
        ./deploy.sh --auto-approve
        ;;
    *)
        echo "Usage:"
        echo "  ./test-file-prep.sh --test-phase1      # Test file preparation only"
        echo "  ./test-file-prep.sh --test-phase2      # Test full infrastructure (files already prepared)"
        echo "  ./test-file-prep.sh --test-full        # Test complete deployment"
        echo ""
        echo "Manual Usage:"
        echo "  ./deploy.sh --prepare-files-only       # Phase 1: Prepare files in EFS"
        echo "  ./deploy.sh --skip-file-prep           # Phase 2: Deploy infrastructure with prepared files"
        echo "  ./deploy.sh                            # Full deployment (both phases)"
        ;;
esac