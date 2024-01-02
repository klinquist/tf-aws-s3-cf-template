#!/bin/bash

# Define the Terraform variable file path
file_path="terraform.tfvars"


get_domain_name() {
    # Check if file exists
    if [ ! -f "$file_path" ]; then
        echo "File not found: $file_path"
        exit 1
    fi

    # Read the file and extract the domainName value
    while IFS='=' read -r key value
    do
        if [[ $key == *"domainName"* ]]; then
            # Trim leading and trailing spaces and quotes
            domain_name=$(echo "$value" | xargs | tr -d '"')
            break
        fi
    done < "$file_path"

    # Check if domain_name is extracted
    if [ -z "$domain_name" ]; then
        echo "domainName not found in the file."
        exit 1
    fi

}

# Ask the user if they want to add secrets to their repo
read -r -p "Do you want to run 'terraform destroy' to destroy the AWS environment for your website?  This will make it go away. (y/n): " answer
case $answer in
    [Yy]* )
        get_domain_name
        ;;
    [Nn]* )
        exit 1
        ;;
    * )
        echo "Invalid response."
        exit 1
        ;;
esac


# Empty the s3 buckets
aws s3 rm s3://"$domain_name" --recursive
aws s3 rm s3://"$domain_name"-logs --recursive


# Run terraform destroy
terraform destroy


read -r -p "Do you want to remove your domain from Route53?  This will remove all DNS records including MX records. (y/n): " answer
case $answer in
    [Yy]* )
        ;;
    [Nn]* )
        exit 1
        ;;
    * )
        echo "Invalid response."
        exit 1
        ;;
esac


FQDN="$domain_name."

# Fetch the hosted zone ID for the given domain name
HOSTED_ZONE_ID=$(aws route53 list-hosted-zones | jq -r '.HostedZones[] | select(.Name=="'"$FQDN"'") | .Id' | cut -d'/' -f3)

# Check if HOSTED_ZONE_ID is empty
if [ -z "$HOSTED_ZONE_ID" ]; then
    echo "Hosted zone ID not found for domain $domain_name"
    exit 1
fi

echo "Hosted Zone ID for $domain_name: $HOSTED_ZONE_ID"

# List and delete all records except NS and SOA
RECORD_SETS=$(aws route53 list-resource-record-sets --hosted-zone-id "$HOSTED_ZONE_ID")
RECORD_SETS_COUNT=$(echo "$RECORD_SETS" | jq '.ResourceRecordSets | length')

for (( i=0; i<"$RECORD_SETS_COUNT"; i++ ))
do
    RECORD_NAME=$(echo "$RECORD_SETS" | jq -r ".ResourceRecordSets[$i].Name")
    RECORD_TYPE=$(echo "$RECORD_SETS" | jq -r ".ResourceRecordSets[$i].Type")

    if [[ $RECORD_TYPE != "NS" && $RECORD_TYPE != "SOA" ]]; then
        CHANGE_BATCH=$(echo "$RECORD_SETS" | jq -c ".ResourceRecordSets[$i] | {Changes: [{Action: \"DELETE\", ResourceRecordSet: .}]}")
        echo "Deleting record set: $RECORD_NAME $RECORD_TYPE"
        aws route53 change-resource-record-sets --hosted-zone-id "$HOSTED_ZONE_ID" --change-batch "$CHANGE_BATCH"
    fi
done

# Delete the hosted zone
echo "Deleting hosted zone: $HOSTED_ZONE_ID"
aws route53 delete-hosted-zone --id "$HOSTED_ZONE_ID"



read -r -p "Do you want to delete the repository from github? This is going to make you type a code into your browser to grant this ability from the cli. (y/n) " answer
case $answer in
    [Yy]* )
        ;;
    [Nn]* )
        exit 1
        ;;
    * )
        echo "Invalid response."
        exit 1
        ;;
esac


gh auth refresh -h github.com -s delete_repo
gh repo delete --yes


echo "Done, you may now delete this folder if you wish :)"