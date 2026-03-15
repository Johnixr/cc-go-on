#!/usr/bin/env bash
# cc-go-on: Aliyun OSS storage backend
set -euo pipefail

STORAGE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$STORAGE_DIR/common.sh"

storage_upload() {
    local file="$1"
    local bucket
    bucket="$(config_get 'storage_options.oss.bucket' '')"
    local prefix
    prefix="$(config_get 'storage_options.oss.prefix' 'cc-go-on')"
    local endpoint
    endpoint="$(config_get 'storage_options.oss.endpoint' '')"

    if [[ -z "$bucket" ]]; then
        log_error "OSS storage requires 'bucket' in config"
        log_error "  ccgoon.sh config storage_options.oss.bucket <bucket-name>"
        return 1
    fi

    if ! command -v aliyun &>/dev/null; then
        log_error "aliyun CLI not found. Install: https://help.aliyun.com/document_detail/139508.html"
        return 1
    fi

    local filename
    filename="$(basename "$file")"
    local key="${prefix}/${filename}"
    local oss_path="oss://${bucket}/${key}"

    local endpoint_flag=""
    if [[ -n "$endpoint" ]]; then
        endpoint_flag="-e $endpoint"
    fi

    # Upload
    # shellcheck disable=SC2086
    aliyun oss cp "$file" "$oss_path" $endpoint_flag --force >/dev/null 2>&1 || {
        log_error "OSS upload failed"
        return 1
    }

    # Generate a signed URL (valid for 7 days = 604800 seconds)
    local signed_url
    # shellcheck disable=SC2086
    signed_url=$(aliyun oss sign "$oss_path" --timeout 604800 $endpoint_flag 2>/dev/null | grep -o 'https://[^ ]*') || {
        # Fallback: construct public URL if signing fails
        if [[ -n "$endpoint" ]]; then
            signed_url="https://${bucket}.${endpoint#*//}/${key}"
        else
            signed_url="$oss_path"
        fi
    }

    echo "$signed_url"
}

storage_download() {
    local url="$1"
    local output="$2"

    if [[ "$url" == oss://* ]]; then
        local endpoint
        endpoint="$(config_get 'storage_options.oss.endpoint' '')"
        local endpoint_flag=""
        if [[ -n "$endpoint" ]]; then
            endpoint_flag="-e $endpoint"
        fi
        # shellcheck disable=SC2086
        aliyun oss cp "$url" "$output" $endpoint_flag --force >/dev/null 2>&1
    else
        # Signed URL — just curl it
        local http_code
        http_code=$(curl -sL --connect-timeout 10 -w "%{http_code}" -o "$output" "$url")
        if [[ "$http_code" -lt 200 || "$http_code" -ge 300 ]]; then
            log_error "Download failed (HTTP $http_code)"
            return 1
        fi
    fi
}
