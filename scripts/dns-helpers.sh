#!/bin/bash

get_domain_name_from_tfvars() {
    local file_path="${1:-terraform.tfvars}"
    local domain_name=""

    if [ ! -f "$file_path" ]; then
        echo "File not found: $file_path" >&2
        return 1
    fi

    while IFS='=' read -r key value
    do
        if [[ $key == *"domainName"* ]]; then
            domain_name=$(echo "$value" | xargs | tr -d '"')
            break
        fi
    done < "$file_path"

    if [ -z "$domain_name" ]; then
        echo "domainName not found in $file_path." >&2
        return 1
    fi

    if [[ $domain_name == *"YourDomainHere.com"* ]]; then
        echo "Edit terraform.tfvars and replace YourDomainHere.com before continuing." >&2
        return 1
    fi

    echo "$domain_name"
}

normalize_nameservers() {
    tr '[:upper:]' '[:lower:]' \
        | sed 's/\.$//' \
        | sed '/^[[:space:]]*$/d' \
        | sort -u
}

get_route53_hosted_zone_id() {
    local domain_name="$1"
    local fqdn="${domain_name}."

    aws route53 list-hosted-zones-by-name --dns-name "$domain_name" --max-items 10 \
        | jq -r --arg fqdn "$fqdn" '
            .HostedZones[]
            | select(.Name == $fqdn and .Config.PrivateZone == false)
            | .Id
        ' \
        | head -n 1 \
        | awk -F'/' '{print $3}'
}

get_route53_nameservers() {
    local hosted_zone_id="$1"

    aws route53 get-hosted-zone --id "$hosted_zone_id" \
        | jq -r '.DelegationSet.NameServers[]'
}

get_public_nameservers() {
    local domain_name="$1"

    if command -v dig >/dev/null 2>&1; then
        dig +short NS "$domain_name"
    elif command -v host >/dev/null 2>&1; then
        host -t NS "$domain_name" | awk '/name server/ {print $NF}'
    else
        echo "Neither dig nor host is installed; cannot check public NS delegation." >&2
        return 1
    fi
}

detect_registrar() {
    local domain_name="$1"
    local registrar=""

    if command -v curl >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
        registrar=$(curl -fsSL --max-time 8 "https://rdap.org/domain/$domain_name" 2>/dev/null \
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
        registrar=$(whois "$domain_name" 2>/dev/null \
            | awk -F: '
                tolower($1) ~ /^registrar$/ {
                    gsub(/^[ \t]+|[ \t]+$/, "", $2)
                    print $2
                    exit
                }
            ' || true)
    fi

    if [ -z "$registrar" ]; then
        registrar="Unknown"
    fi

    echo "$registrar"
}

print_registrar_guidance() {
    local domain_name="$1"
    local registrar="$2"
    local registrar_lc

    registrar_lc=$(echo "$registrar" | tr '[:upper:]' '[:lower:]')

    echo "Registrar: $registrar"
    case "$registrar_lc" in
        *namecheap*)
            echo "Open: https://ap.www.namecheap.com/domains/domaincontrolpanel/$domain_name/domain"
            echo "Set Nameservers to Custom DNS and enter the Route53 nameservers below."
            ;;
        *godaddy*)
            echo "Open: https://dcc.godaddy.com/control/$domain_name/settings"
            echo "Choose Manage DNS, then change Nameservers to the Route53 nameservers below."
            ;;
        *porkbun*)
            echo "Open: https://porkbun.com/account/domainsSpeedy"
            echo "Use Details > Authoritative Nameservers and enter the Route53 nameservers below."
            ;;
        *cloudflare*)
            echo "Open: https://dash.cloudflare.com"
            echo "If Cloudflare is your registrar, update the domain's custom nameservers to Route53."
            ;;
        *gandi*)
            echo "Open: https://admin.gandi.net/domain/$domain_name/nameservers"
            echo "Replace the current nameservers with the Route53 nameservers below."
            ;;
        *dynadot*)
            echo "Open: https://www.dynadot.com/account/domain/manage"
            echo "Choose the domain, then update Name Servers to the Route53 nameservers below."
            ;;
        *squarespace*|*google*)
            echo "Open: https://domains.squarespace.com"
            echo "Open the domain's DNS or nameserver settings and enter the Route53 nameservers below."
            ;;
        *)
            echo "Open your registrar's nameserver settings and replace the current nameservers with the Route53 nameservers below."
            ;;
    esac
}
