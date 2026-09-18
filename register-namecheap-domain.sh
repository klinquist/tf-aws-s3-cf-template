#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TFVARS_FILE="$SCRIPT_DIR/terraform.tfvars"
NAMECHEAP_API_URL="${NAMECHEAP_API_URL:-https://api.namecheap.com/xml.response}"
YEARS=1
ASSUME_YES=false
BROWSER_MODE=false
DOMAIN_NAME=""

source "$SCRIPT_DIR/scripts/dns-helpers.sh"

usage() {
    cat <<'EOF'
Usage: ./register-namecheap-domain.sh [--browser] [--years N] [--yes] domain.example

Registers an available domain through Namecheap, creates or reuses its public
Route53 hosted zone, assigns the Route53 nameservers during registration, and
updates domainName in terraform.tfvars.

Credentials may be supplied through NAMECHEAP_API_USER, NAMECHEAP_API_KEY,
NAMECHEAP_USERNAME, and NAMECHEAP_CLIENT_IP. Missing values are prompted for.
The client IPv4 address must already be whitelisted in Namecheap.

Contact values can also be supplied with these environment variables:
  NAMECHEAP_CONTACT_FIRST_NAME   NAMECHEAP_CONTACT_LAST_NAME
  NAMECHEAP_CONTACT_ADDRESS1     NAMECHEAP_CONTACT_ADDRESS2 (optional)
  NAMECHEAP_CONTACT_CITY         NAMECHEAP_CONTACT_STATE_PROVINCE
  NAMECHEAP_CONTACT_POSTAL_CODE  NAMECHEAP_CONTACT_COUNTRY (two-letter code)
  NAMECHEAP_CONTACT_PHONE        NAMECHEAP_CONTACT_EMAIL
  NAMECHEAP_CONTACT_ORGANIZATION (optional)

--yes skips the final purchase confirmation and is intended only for deliberate
automation. Domain registration charges are not reversible by this script.

--browser provides an assisted alternative when Namecheap API access is not
available. It opens the purchase and domain-control pages, while the script
creates Route53 DNS, updates terraform.tfvars, and checks your delegation.
EOF
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --years)
            [ "$#" -ge 2 ] || { echo "--years requires a value" >&2; exit 1; }
            YEARS="$2"
            shift 2
            ;;
        --yes)
            ASSUME_YES=true
            shift
            ;;
        --browser)
            BROWSER_MODE=true
            shift
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        -*)
            echo "Unknown option: $1" >&2
            usage >&2
            exit 1
            ;;
        *)
            if [ -n "$DOMAIN_NAME" ]; then
                echo "Only one domain may be registered at a time." >&2
                exit 1
            fi
            DOMAIN_NAME="$1"
            shift
            ;;
    esac
done

if [ -z "$DOMAIN_NAME" ]; then
    read -r -p "Domain to register: " DOMAIN_NAME
fi

DOMAIN_NAME=$(printf '%s' "$DOMAIN_NAME" | tr '[:upper:]' '[:lower:]' | sed 's/\.$//')

if ! printf '%s' "$DOMAIN_NAME" | grep -Eq '^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)+$'; then
    echo "Invalid domain name: $DOMAIN_NAME" >&2
    exit 1
fi

case "$YEARS" in
    ''|*[!0-9]*) echo "--years must be a positive integer." >&2; exit 1 ;;
esac
if [ "$YEARS" -lt 1 ]; then
    echo "--years must be at least 1." >&2
    exit 1
fi

for command_name in aws jq; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
        echo "$command_name is required but was not found on PATH." >&2
        exit 1
    fi
done

create_or_reuse_hosted_zone() {
    hosted_zone_id=$(get_route53_hosted_zone_id "$DOMAIN_NAME")
    created_hosted_zone=false
    if [ -z "$hosted_zone_id" ]; then
        echo "Creating Route53 hosted zone for $DOMAIN_NAME..."
        caller_reference="namecheap-registration-$(date +%s)-$$"
        zone_result=$(aws route53 create-hosted-zone --name "$DOMAIN_NAME" --caller-reference "$caller_reference")
        hosted_zone_id=$(printf '%s' "$zone_result" | jq -r '.HostedZone.Id' | awk -F/ '{print $3}')
        created_hosted_zone=true
    else
        echo "Reusing Route53 hosted zone $hosted_zone_id."
    fi

    nameservers=$(get_route53_nameservers "$hosted_zone_id")
    nameserver_csv=$(printf '%s\n' "$nameservers" | paste -sd, -)
}

open_browser_url() {
    local url="$1"

    if command -v open >/dev/null 2>&1; then
        open "$url"
    elif command -v xdg-open >/dev/null 2>&1; then
        xdg-open "$url"
    elif command -v cmd.exe >/dev/null 2>&1; then
        cmd.exe /c start "" "$url"
    else
        echo "Open this URL in your browser:"
        echo "  $url"
    fi
}

if [ "$BROWSER_MODE" = true ]; then
    echo ""
    echo "Browser-assisted setup for $DOMAIN_NAME"
    echo "  1. Create or reuse a Route53 hosted zone."
    echo "  2. Open Namecheap so you can sign in and purchase the domain."
    echo "  3. Open its Namecheap control panel so you can paste the Route53 nameservers."
    echo "  4. Update terraform.tfvars and check public DNS."
    echo ""

    if [ "$ASSUME_YES" = false ]; then
        read -r -p "Type the full domain name to continue: " confirmation
        if [ "$confirmation" != "$DOMAIN_NAME" ]; then
            echo "Confirmation did not match; no hosted zone was created."
            exit 1
        fi
    fi

    create_or_reuse_hosted_zone
    echo ""
    echo "Route53 nameservers:"
    printf '%s\n' "$nameservers" | sed 's/^/  - /'

    if command -v pbcopy >/dev/null 2>&1; then
        printf '%s\n' "$nameservers" | pbcopy
        echo "(Copied the nameserver list to the clipboard.)"
    fi

    echo ""
    echo "Opening Namecheap's registration page. Complete the purchase in your browser."
    open_browser_url "https://www.namecheap.com/domains/registration/results/?domain=$DOMAIN_NAME"
    read -r -p "Press Enter after the domain appears in your Namecheap account..." _

    update_domain_name_in_tfvars "$DOMAIN_NAME" "$TFVARS_FILE"
    echo "Updated terraform.tfvars."
    echo ""
    echo "Opening the domain control panel. Choose Custom DNS and enter all four nameservers above."
    open_browser_url "https://ap.www.namecheap.com/domains/domaincontrolpanel/$DOMAIN_NAME/domain"
    read -r -p "Press Enter after saving the custom nameservers..." _

    echo ""
    if "$SCRIPT_DIR/scripts/check-dns-delegation.sh" "$DOMAIN_NAME"; then
        echo "Next: ./apply.sh --auto-approve"
    else
        echo "The change may still be propagating. Next:"
        echo "  ./scripts/check-dns-delegation.sh --wait"
        echo "  ./apply.sh --auto-approve"
    fi
    exit 0
fi

for command_name in curl python3; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
        echo "$command_name is required for API mode but was not found on PATH." >&2
        exit 1
    fi
done

prompt_required() {
    local variable_name="$1"
    local label="$2"
    local secret="${3:-false}"
    local current_value="${!variable_name:-}"

    if [ -n "$current_value" ]; then
        return
    fi

    if [ "$secret" = true ]; then
        read -r -s -p "$label: " current_value
        echo ""
    else
        read -r -p "$label: " current_value
    fi

    if [ -z "$current_value" ]; then
        echo "$label is required." >&2
        exit 1
    fi
    printf -v "$variable_name" '%s' "$current_value"
}

prompt_required NAMECHEAP_API_USER "Namecheap API user"
prompt_required NAMECHEAP_API_KEY "Namecheap API key" true
NAMECHEAP_USERNAME="${NAMECHEAP_USERNAME:-$NAMECHEAP_API_USER}"
prompt_required NAMECHEAP_CLIENT_IP "Whitelisted public IPv4 address"

prompt_required NAMECHEAP_CONTACT_FIRST_NAME "Registrant first name"
prompt_required NAMECHEAP_CONTACT_LAST_NAME "Registrant last name"
prompt_required NAMECHEAP_CONTACT_ADDRESS1 "Registrant street address"
NAMECHEAP_CONTACT_ADDRESS2="${NAMECHEAP_CONTACT_ADDRESS2:-}"
prompt_required NAMECHEAP_CONTACT_CITY "Registrant city"
prompt_required NAMECHEAP_CONTACT_STATE_PROVINCE "Registrant state/province"
prompt_required NAMECHEAP_CONTACT_POSTAL_CODE "Registrant postal code"
prompt_required NAMECHEAP_CONTACT_COUNTRY "Registrant country code (for example, US)"
prompt_required NAMECHEAP_CONTACT_PHONE "Registrant phone (for example, +1.5555555555)"
prompt_required NAMECHEAP_CONTACT_EMAIL "Registrant email"
NAMECHEAP_CONTACT_ORGANIZATION="${NAMECHEAP_CONTACT_ORGANIZATION:-}"

NAMECHEAP_CONTACT_COUNTRY=$(printf '%s' "$NAMECHEAP_CONTACT_COUNTRY" | tr '[:lower:]' '[:upper:]')
if ! printf '%s' "$NAMECHEAP_CLIENT_IP" | grep -Eq '^([0-9]{1,3}\.){3}[0-9]{1,3}$'; then
    echo "NAMECHEAP_CLIENT_IP must be an IPv4 address." >&2
    exit 1
fi
if ! printf '%s' "$NAMECHEAP_CONTACT_COUNTRY" | grep -Eq '^[A-Z]{2}$'; then
    echo "NAMECHEAP_CONTACT_COUNTRY must be a two-letter country code." >&2
    exit 1
fi

response_file=$(mktemp "${TMPDIR:-/tmp}/namecheap-response.XXXXXX")
trap 'rm -f "$response_file"' EXIT

namecheap_call() {
    local command="$1"
    shift
    local curl_arguments=(
        --silent --show-error --fail
        --request POST
        "$NAMECHEAP_API_URL"
        --data-urlencode "ApiUser=$NAMECHEAP_API_USER"
        --data-urlencode "ApiKey=$NAMECHEAP_API_KEY"
        --data-urlencode "UserName=$NAMECHEAP_USERNAME"
        --data-urlencode "ClientIp=$NAMECHEAP_CLIENT_IP"
        --data-urlencode "Command=$command"
    )

    while [ "$#" -gt 0 ]; do
        if [ "$#" -lt 2 ]; then
            echo "Internal error: unpaired Namecheap API argument." >&2
            exit 1
        fi
        curl_arguments+=(--data-urlencode "$1=$2")
        shift 2
    done

    curl "${curl_arguments[@]}" > "$response_file"
}

assert_namecheap_success() {
    local result
    local status
    local error_count

    result=$(python3 "$SCRIPT_DIR/scripts/parse-namecheap-response.py" "$response_file" errors)
    status=$(printf '%s' "$result" | jq -r '.status')
    error_count=$(printf '%s' "$result" | jq '.errors | length')

    if [ "$status" != "OK" ] || [ "$error_count" -ne 0 ]; then
        echo "Namecheap API request failed:" >&2
        printf '%s' "$result" | jq -r '.errors[] | "  \(.number): \(.message)"' >&2
        if [ "$error_count" -eq 0 ]; then
            echo "  Response status: $status" >&2
        fi
        exit 1
    fi
}

echo "Checking availability and pricing for $DOMAIN_NAME..."
namecheap_call namecheap.domains.check DomainList "$DOMAIN_NAME"
assert_namecheap_success
check_result=$(python3 "$SCRIPT_DIR/scripts/parse-namecheap-response.py" "$response_file" check)

if [ "$(printf '%s' "$check_result" | jq -r '.Available // "false"' | tr '[:upper:]' '[:lower:]')" != "true" ]; then
    echo "$DOMAIN_NAME is not available for registration." >&2
    exit 1
fi

is_premium=$(printf '%s' "$check_result" | jq -r '.IsPremiumName // "false"' | tr '[:upper:]' '[:lower:]')
premium_price=$(printf '%s' "$check_result" | jq -r '.PremiumRegistrationPrice // "0"')
premium_renewal=$(printf '%s' "$check_result" | jq -r '.PremiumRenewalPrice // "0"')
eap_fee=$(printf '%s' "$check_result" | jq -r '.EapFee // "0"')

if [ "$eap_fee" != "0" ] && [ "$eap_fee" != "0.0" ] && [ "$eap_fee" != "0.0000" ]; then
    echo "Namecheap's API cannot register domains that are in an Early Access Period (EAP fee: $eap_fee)." >&2
    exit 1
fi

tld=${DOMAIN_NAME#*.}
quoted_price=""
if [ "$is_premium" = "true" ]; then
    quoted_price="${premium_price} USD premium registration; renewal currently ${premium_renewal} USD"
else
    namecheap_call namecheap.users.getPricing \
        ProductType DOMAIN \
        ProductCategory DOMAINS \
        ActionName REGISTER \
        ProductName "$tld"
    assert_namecheap_success
    price_result=$(python3 "$SCRIPT_DIR/scripts/parse-namecheap-response.py" "$response_file" price "$tld" "$YEARS")
    price=$(printf '%s' "$price_result" | jq -r '.Price // empty')
    currency=$(printf '%s' "$price_result" | jq -r '.Currency // "USD"')
    if [ -n "$price" ]; then
        quoted_price="$price $currency"
    else
        quoted_price="unavailable from the pricing API; Namecheap will charge the current account price"
    fi
fi

echo ""
echo "Registration summary"
echo "  Domain: $DOMAIN_NAME"
echo "  Term: $YEARS year(s)"
echo "  Quoted price: $quoted_price"
echo "  DNS: a Route53 hosted zone will be created or reused"
echo "  Terraform: $TFVARS_FILE will be updated after successful registration"
echo ""

if [ "$ASSUME_YES" = false ]; then
    read -r -p "Type the full domain name to authorize this purchase: " confirmation
    if [ "$confirmation" != "$DOMAIN_NAME" ]; then
        echo "Confirmation did not match; nothing was purchased."
        exit 1
    fi
fi

create_or_reuse_hosted_zone

registration_arguments=(
    DomainName "$DOMAIN_NAME"
    Years "$YEARS"
    Nameservers "$nameserver_csv"
    AddFreeWhoisguard yes
    WGEnabled yes
)

for contact_type in Registrant Tech Admin AuxBilling; do
    registration_arguments+=(
        "${contact_type}FirstName" "$NAMECHEAP_CONTACT_FIRST_NAME"
        "${contact_type}LastName" "$NAMECHEAP_CONTACT_LAST_NAME"
        "${contact_type}Address1" "$NAMECHEAP_CONTACT_ADDRESS1"
        "${contact_type}City" "$NAMECHEAP_CONTACT_CITY"
        "${contact_type}StateProvince" "$NAMECHEAP_CONTACT_STATE_PROVINCE"
        "${contact_type}PostalCode" "$NAMECHEAP_CONTACT_POSTAL_CODE"
        "${contact_type}Country" "$NAMECHEAP_CONTACT_COUNTRY"
        "${contact_type}Phone" "$NAMECHEAP_CONTACT_PHONE"
        "${contact_type}EmailAddress" "$NAMECHEAP_CONTACT_EMAIL"
    )
    if [ -n "$NAMECHEAP_CONTACT_ADDRESS2" ]; then
        registration_arguments+=("${contact_type}Address2" "$NAMECHEAP_CONTACT_ADDRESS2")
    fi
    if [ -n "$NAMECHEAP_CONTACT_ORGANIZATION" ]; then
        registration_arguments+=("${contact_type}OrganizationName" "$NAMECHEAP_CONTACT_ORGANIZATION")
    fi
done

if [ "$is_premium" = "true" ]; then
    registration_arguments+=(IsPremiumDomain true PremiumPrice "$premium_price")
fi

echo "Registering $DOMAIN_NAME with the Route53 nameservers..."
namecheap_call namecheap.domains.create "${registration_arguments[@]}"

if ! api_result=$(python3 "$SCRIPT_DIR/scripts/parse-namecheap-response.py" "$response_file" errors) || \
   [ "$(printf '%s' "$api_result" | jq -r '.status')" != "OK" ] || \
   [ "$(printf '%s' "$api_result" | jq '.errors | length')" -ne 0 ]; then
    echo "Namecheap registration failed. The Route53 hosted zone was left in place for inspection." >&2
    if [ "$created_hosted_zone" = true ]; then
        echo "New hosted zone ID: $hosted_zone_id" >&2
    fi
    printf '%s' "${api_result:-{}}" | jq -r '.errors[]? | "  \(.number): \(.message)"' >&2 || true
    exit 1
fi

registration_result=$(python3 "$SCRIPT_DIR/scripts/parse-namecheap-response.py" "$response_file" registration)
registered=$(printf '%s' "$registration_result" | jq -r '.Registered // "false"' | tr '[:upper:]' '[:lower:]')
if [ "$registered" != "true" ]; then
    echo "Namecheap returned success but did not report the domain as registered." >&2
    echo "The Route53 hosted zone was left in place for inspection: $hosted_zone_id" >&2
    exit 1
fi

update_domain_name_in_tfvars "$DOMAIN_NAME" "$TFVARS_FILE"
charged_amount=$(printf '%s' "$registration_result" | jq -r '.ChargedAmount // "unknown"')

echo ""
echo "Registered $DOMAIN_NAME (charged amount: $charged_amount)."
echo "Route53 hosted zone: $hosted_zone_id"
echo "Nameservers:"
printf '%s\n' "$nameservers" | sed 's/^/  - /'
echo "Updated terraform.tfvars. DNS delegation can take time to appear publicly."
echo "Next: ./scripts/check-dns-delegation.sh --wait && ./apply.sh --auto-approve"
