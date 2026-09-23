#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TFVARS_FILE="$SCRIPT_DIR/terraform.tfvars"
DOMAIN_NAME=""
USES_NAMECHEAP=false
ALREADY_REGISTERED=false

cd "$SCRIPT_DIR"

ask_yes_no() {
    local prompt="$1"
    local answer

    while true; do
        read -r -p "$prompt (y/n): " answer
        case "$answer" in
            [Yy]|[Yy][Ee][Ss]) return 0 ;;
            [Nn]|[Nn][Oo]) return 1 ;;
            *) echo "Please answer yes or no." ;;
        esac
    done
}

open_browser_url() {
    local url="$1"

    if command -v open >/dev/null 2>&1 && open "$url"; then
        return
    fi
    if command -v xdg-open >/dev/null 2>&1 && xdg-open "$url"; then
        return
    fi
    if command -v cmd.exe >/dev/null 2>&1 && cmd.exe /c start "" "$url"; then
        return
    fi

    echo "Open this URL in your browser:"
    echo "  $url"
}

update_terraform_domain() {
    local temp_file

    temp_file=$(mktemp "${TFVARS_FILE}.tmp.XXXXXX")
    awk -v domain="$DOMAIN_NAME" '
        /^[[:space:]]*domainName[[:space:]]*=/ {
            print "domainName = \"" domain "\""
            found_domain = 1
            next
        }
        /^[[:space:]]*SiteTags[[:space:]]*=/ && /YourDomainHere\.com/ {
            print "SiteTags = \"" domain "\""
            next
        }
        { print }
        END {
            if (!found_domain) {
                exit 2
            }
        }
    ' "$TFVARS_FILE" > "$temp_file" || {
        local status=$?
        rm -f "$temp_file"
        echo "Could not update domainName in $TFVARS_FILE." >&2
        return "$status"
    }

    mv "$temp_file" "$TFVARS_FILE"
}

get_hosted_zone_id() {
    local fqdn="${DOMAIN_NAME}."

    aws route53 list-hosted-zones-by-name --dns-name "$DOMAIN_NAME" --max-items 10 \
        | jq -r --arg fqdn "$fqdn" '
            .HostedZones[]
            | select(.Name == $fqdn and .Config.PrivateZone == false)
            | .Id
        ' \
        | head -n 1 \
        | awk -F/ '{print $3}'
}

get_public_nameservers() {
    if command -v dig >/dev/null 2>&1; then
        dig +short NS "$DOMAIN_NAME"
    else
        host -t NS "$DOMAIN_NAME" | awk '/name server/ {print $NF}'
    fi
}

normalize_nameservers() {
    tr '[:upper:]' '[:lower:]' \
        | sed 's/\.$//' \
        | sed '/^[[:space:]]*$/d' \
        | sort -u
}

detect_registrar() {
    local registrar=""

    if command -v curl >/dev/null 2>&1; then
        registrar=$(curl -fsSL --max-time 8 "https://rdap.org/domain/$DOMAIN_NAME" 2>/dev/null \
            | jq -r '
                [
                    .entities[]?
                    | select((.roles // []) | index("registrar"))
                    | .vcardArray[1][]?
                    | select(.[0] == "fn")
                    | .[3]
                ][0] // empty
            ' 2>/dev/null || true)
    fi

    if [ -z "$registrar" ] && command -v whois >/dev/null 2>&1; then
        registrar=$(whois "$DOMAIN_NAME" 2>/dev/null \
            | awk -F: '
                tolower($1) ~ /^registrar$/ {
                    gsub(/^[ \t]+|[ \t]+$/, "", $2)
                    print $2
                    exit
                }
            ' || true)
    fi

    printf '%s' "${registrar:-your registrar}"
}

print_registrar_instructions() {
    local registrar

    if [ "$USES_NAMECHEAP" = true ]; then
        echo "In Namecheap:"
        echo "  1. Open Domain List and click Manage next to $DOMAIN_NAME."
        echo "  2. Find Nameservers and choose Custom DNS."
        echo "  3. Enter all four Route53 nameservers shown below and save."
        open_browser_url "https://ap.www.namecheap.com/domains/domaincontrolpanel/$DOMAIN_NAME/domain"
        return
    fi

    registrar=$(detect_registrar)
    echo "Registrar detected: $registrar"
    echo "Sign in to your registrar and open the nameserver or DNS delegation settings."
    echo "Replace the current authoritative nameservers with all four Route53 nameservers shown below."
}

delegation_matches() {
    local current_nameservers
    local current_normalized
    local expected_normalized

    current_nameservers=$(get_public_nameservers 2>/dev/null || true)
    current_normalized=$(printf '%s\n' "$current_nameservers" | normalize_nameservers)
    expected_normalized=$(printf '%s\n' "$ROUTE53_NAMESERVERS" | normalize_nameservers)

    [ -n "$current_normalized" ] && [ "$current_normalized" = "$expected_normalized" ]
}

wait_for_delegation() {
    local timeout_seconds=3600
    local interval_seconds=30
    local started_at
    local now
    local elapsed
    local current_nameservers

    started_at=$(date +%s)
    while ! delegation_matches; do
        current_nameservers=$(get_public_nameservers 2>/dev/null || true)
        echo ""
        if [ -n "$current_nameservers" ]; then
            echo "Public DNS currently reports:"
            printf '%s\n' "$current_nameservers" | normalize_nameservers | sed 's/^/  - /'
        else
            echo "Public DNS does not report nameservers for $DOMAIN_NAME yet."
        fi
        echo "Waiting for Route53 delegation. Checking again in ${interval_seconds}s..."

        now=$(date +%s)
        elapsed=$((now - started_at))
        if [ "$elapsed" -ge "$timeout_seconds" ]; then
            echo ""
            echo "Timed out after one hour waiting for DNS delegation." >&2
            echo "Confirm the Custom DNS values at your registrar, then run ./setup.sh again." >&2
            return 1
        fi
        sleep "$interval_seconds"
    done

    echo "DNS is delegated to Route53."
}

echo "AWS static-site setup"
echo ""

for command_name in aws jq terraform; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
        echo "$command_name is required but was not found on PATH." >&2
        exit 1
    fi
done

if ! command -v dig >/dev/null 2>&1 && ! command -v host >/dev/null 2>&1; then
    echo "Either dig or host is required to verify DNS delegation." >&2
    exit 1
fi

while true; do
    read -r -p "What domain do you want to use? " DOMAIN_NAME
    DOMAIN_NAME=$(printf '%s' "$DOMAIN_NAME" | tr '[:upper:]' '[:lower:]' | sed 's/\.$//')
    if printf '%s' "$DOMAIN_NAME" | grep -Eq '^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)+$'; then
        break
    fi
    echo "Please enter a valid domain, such as example.com."
done

if ask_yes_no "Do you use Namecheap for this domain?"; then
    USES_NAMECHEAP=true
fi

if ask_yes_no "Have you already registered $DOMAIN_NAME?"; then
    ALREADY_REGISTERED=true
fi

if ! aws sts get-caller-identity >/dev/null 2>&1; then
    echo "AWS credentials are not configured or have expired." >&2
    echo "Configure the AWS CLI (for example, with 'aws configure sso') and try again." >&2
    exit 1
fi

if [ "$ALREADY_REGISTERED" = false ]; then
    echo ""
    if [ "$USES_NAMECHEAP" = true ]; then
        echo "Opening Namecheap. Sign in and complete the domain purchase in your browser."
        open_browser_url "https://www.namecheap.com/domains/registration/results/?domain=$DOMAIN_NAME"
    else
        echo "Register $DOMAIN_NAME with your preferred domain registrar."
    fi
    read -r -p "Press Enter after $DOMAIN_NAME appears in your registrar account..." _
fi

update_terraform_domain
echo "Updated terraform.tfvars for $DOMAIN_NAME."

HOSTED_ZONE_ID=$(get_hosted_zone_id)
if [ -z "$HOSTED_ZONE_ID" ]; then
    echo "Creating a Route53 hosted zone..."
    caller_reference="site-setup-$(date +%s)-$$"
    zone_result=$(aws route53 create-hosted-zone --name "$DOMAIN_NAME" --caller-reference "$caller_reference")
    HOSTED_ZONE_ID=$(printf '%s' "$zone_result" | jq -r '.HostedZone.Id' | awk -F/ '{print $3}')
else
    echo "Reusing Route53 hosted zone $HOSTED_ZONE_ID."
fi

ROUTE53_NAMESERVERS=$(aws route53 get-hosted-zone --id "$HOSTED_ZONE_ID" \
    | jq -r '.DelegationSet.NameServers[]')

echo ""
print_registrar_instructions
echo ""
echo "Route53 nameservers:"
printf '%s\n' "$ROUTE53_NAMESERVERS" | sed 's/^/  - /'

if command -v pbcopy >/dev/null 2>&1 && printf '%s\n' "$ROUTE53_NAMESERVERS" | pbcopy; then
    echo "(Copied the nameserver list to the clipboard.)"
fi

read -r -p "Press Enter after you have saved the custom nameservers..." _

echo "Waiting for public DNS to point to Route53..."
wait_for_delegation

echo ""
echo "Initializing Terraform..."
terraform -chdir="$SCRIPT_DIR" init

echo ""
echo "Applying the AWS infrastructure..."
terraform -chdir="$SCRIPT_DIR" apply -auto-approve

echo ""
echo "AWS infrastructure is ready. Starting GitHub repository setup..."
"$SCRIPT_DIR/set-up-repo.sh"
