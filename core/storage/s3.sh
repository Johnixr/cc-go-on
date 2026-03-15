#!/usr/bin/env bash
# cc-go-on: S3-compatible storage backend (AWS S3, Cloudflare R2, MinIO, etc.)
set -euo pipefail

STORAGE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$STORAGE_DIR/common.sh"

storage_upload() {
    local file="$1"
    local endpoint
    endpoint="$(config_get 'storage_options.s3.endpoint' '')"
    local bucket
    bucket="$(config_get 'storage_options.s3.bucket' '')"
    local prefix
    prefix="$(config_get 'storage_options.s3.prefix' 'cc-go-on')"

    if [[ -z "$endpoint" || -z "$bucket" ]]; then
        log_error "S3 storage requires 'endpoint' and 'bucket' in config"
        return 1
    fi

    local filename
    filename="$(basename "$file")"
    local key="${prefix}/${filename}"

    local endpoint_flag=""
    if [[ -n "$endpoint" ]]; then
        endpoint_flag="--endpoint-url $endpoint"
    fi

    # Use AWS CLI (works with any S3-compatible service)
    # shellcheck disable=SC2086
    aws s3 cp "$file" "s3://${bucket}/${key}" $endpoint_flag --quiet

    # Return a download URL
    if [[ "$endpoint" == *"r2"* || "$endpoint" == *"cloudflare"* ]]; then
        echo "${endpoint}/${bucket}/${key}"
    else
        echo "s3://${bucket}/${key}"
    fi
}

storage_download() {
    local url="$1"
    local output="$2"

    if [[ "$url" == s3://* ]]; then
        local endpoint
        endpoint="$(config_get 'storage_options.s3.endpoint' '')"
        local endpoint_flag=""
        if [[ -n "$endpoint" ]]; then
            endpoint_flag="--endpoint-url $endpoint"
        fi
        # shellcheck disable=SC2086
        aws s3 cp "$url" "$output" $endpoint_flag --quiet
    else
        curl -s -o "$output" "$url"
    fi
}
