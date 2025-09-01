#!/bin/bash
# S3 Progress Monitor Script
# Monitors S3 transfers with file size, transfer rate, and ETA

s3_cp_with_progress() {
    local s3_path="$1"
    local local_path="$2"
    local description="$3"
    
    echo "=== Starting download: $description ==="
    echo "Source: $s3_path"
    echo "Destination: $local_path"
    echo "Time: $(date)"
    
    # Get file size from S3
    local file_size=$(aws s3api head-object --bucket "${s3_path#s3://}" --key "${s3_path##*/}" --query 'ContentLength' --output text 2>/dev/null || echo "unknown")
    
    if [ "$file_size" != "unknown" ]; then
        local size_mb=$((file_size / 1024 / 1024))
        echo "File size: ${size_mb}MB (${file_size} bytes)"
    fi
    
    # Start transfer with progress
    local start_time=$(date +%s)
    
    # Use AWS CLI with progress (if available) or fallback to basic monitoring
    if aws s3 cp "$s3_path" "$local_path" --cli-read-timeout 0 --cli-write-timeout 0 2>&1; then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        
        if [ -f "$local_path" ] && [ "$file_size" != "unknown" ] && [ $duration -gt 0 ]; then
            local rate_mbps=$((size_mb / duration))
            echo "Transfer completed successfully!"
            echo "Duration: ${duration}s"
            echo "Average rate: ${rate_mbps}MB/s"
        else
            echo "Transfer completed successfully!"
        fi
        echo "=== Download completed: $description ==="
        return 0
    else
        echo "ERROR: Transfer failed for $description"
        echo "=== Download failed: $description ==="
        return 1
    fi
}

# Export function for use in cloud-init
export -f s3_cp_with_progress