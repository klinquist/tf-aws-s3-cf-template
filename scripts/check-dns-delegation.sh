#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$SCRIPT_DIR/dns-helpers.sh"

WAIT=false
TIMEOUT_SECONDS=600
INTERVAL_SECONDS=30
DOMAIN_NAME=""

while [ "$#" -gt 0 ]; do
    case "$1" in
        --wait)
            WAIT=true
            shift
            ;;
        --timeout)
            TIMEOUT_SECONDS="$2"
            shift 2
            ;;
        --interval)
            INTERVAL_SECONDS="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 [--wait] [--timeout seconds] [--interval seconds] [domain]"
            exit 0
            ;;
        *)
            DOMAIN_NAME="$1"
            shift
            ;;
    esac
done

if [ -z "$DOMAIN_NAME" ]; then
    DOMAIN_NAME=$(get_domain_name_from_tfvars "$REPO_ROOT/terraform.tfvars")
fi

if ! command -v aws >/dev/null 2>&1; then
    echo "AWS CLI is not installed or is not on PATH." >&2
    exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
    echo "jq is not installed or is not on PATH." >&2
    exit 1
fi

HOSTED_ZONE_ID=$(get_route53_hosted_zone_id "$DOMAIN_NAME")

if [ -z "$HOSTED_ZONE_ID" ]; then
    echo "No public Route53 hosted zone found for $DOMAIN_NAME."
    echo "Run ./create-hosted-zone.sh first."
    exit 1
fi

EXPECTED_NS=$(get_route53_nameservers "$HOSTED_ZONE_ID")
EXPECTED_NORMALIZED=$(printf "%s\n" "$EXPECTED_NS" | normalize_nameservers)
REGISTRAR=$(detect_registrar "$DOMAIN_NAME")

check_once() {
    local current_ns
    local current_normalized
    local missing
    local extra

    current_ns=$(get_public_nameservers "$DOMAIN_NAME" || true)
    current_normalized=$(printf "%s\n" "$current_ns" | normalize_nameservers)

    echo ""
    echo "DNS delegation status for $DOMAIN_NAME"
    echo "Hosted Zone ID: $HOSTED_ZONE_ID"
    print_registrar_guidance "$DOMAIN_NAME" "$REGISTRAR"
    echo ""
    echo "Route53 nameservers:"
    printf "%s\n" "$EXPECTED_NS" | sed 's/^/  - /'
    echo ""

    if [ -n "$current_normalized" ]; then
        echo "Current public nameservers:"
        printf "%s\n" "$current_normalized" | sed 's/^/  - /'
    else
        echo "Current public nameservers: none found yet"
    fi

    missing=$(comm -23 <(printf "%s\n" "$EXPECTED_NORMALIZED") <(printf "%s\n" "$current_normalized"))
    extra=$(comm -13 <(printf "%s\n" "$EXPECTED_NORMALIZED") <(printf "%s\n" "$current_normalized"))

    if [ -z "$missing" ] && [ -z "$extra" ]; then
        echo ""
        echo "Status: delegated to Route53. Terraform can request and validate the certificate."
        return 0
    fi

    echo ""
    if [ -n "$current_normalized" ]; then
        echo "Status: registrar still points to:"
        printf "%s\n" "$current_normalized" | sed 's/^/  - /'
    else
        echo "Status: public DNS does not show nameservers for this domain yet."
    fi
    echo "Waiting for Route53 nameservers:"
    printf "%s\n" "$EXPECTED_NORMALIZED" | sed 's/^/  - /'
    return 1
}

if [ "$WAIT" = false ]; then
    check_once
    exit $?
fi

START_TIME=$(date +%s)

while true; do
    if check_once; then
        exit 0
    fi

    NOW=$(date +%s)
    ELAPSED=$((NOW - START_TIME))
    if [ "$ELAPSED" -ge "$TIMEOUT_SECONDS" ]; then
        echo ""
        echo "Timed out after ${TIMEOUT_SECONDS}s waiting for NS delegation."
        exit 1
    fi

    echo ""
    echo "Checking again in ${INTERVAL_SECONDS}s..."
    sleep "$INTERVAL_SECONDS"
done
