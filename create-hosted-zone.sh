#!/bin/bash

# Function to install jq based on the platform
install_jq() {
    case "$(uname -s)" in
        Linux*)     
            # Assuming a Debian-based system or Red Hat-based system
            if command -v apt-get &> /dev/null; then
                sudo apt-get update && sudo apt-get install -y jq
            elif command -v yum &> /dev/null; then
                sudo yum install -y jq
            else
                echo "Unsupported Linux package manager. Install jq manually."
            fi
            ;;
        Darwin*)
            # Assuming macOS with Homebrew installed
            if command -v brew &> /dev/null; then
                brew install jq
            else
                echo "Homebrew not found. Install jq manually."
                exit 1
            fi
            ;;
        *)
            echo "Unsupported operating system. Install jq manually."
            exit 1
            ;;
    esac
}



# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo "jq is not installed."
    read -r -p "Do you want to install jq? (y/n) " install_answer
    case $install_answer in
        [Yy]* )
            install_jq
            ;;
        [Nn]* )
            echo "jq is not installed. Exiting script."
            exit 1
            ;;
        * )
            echo "Invalid response."
            exit 1
            ;;
    esac
fi



# Check if AWS CLI is installed
if aws --version > /dev/null 2>&1; then
    echo "AWS CLI is installed."
else
    echo "AWS CLI is not installed. Please install it."
    exit 1
fi

# Check if AWS configuration files exist and are not empty
if [ -s ~/.aws/config ] || [ -s ~/.aws/credentials ]; then
    echo "AWS configuration and credentials are set."
else
    echo "AWS configuration/credentials are missing or incomplete. Please configure them."
    exit 1
fi




# Define the Terraform variable file path
file_path="terraform.tfvars"

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
else
    echo "Extracted domainName: $domain_name"
fi


# Ask the user to confirm the domain name
read -r -p "Is $domain_name the domain name you want to add to AWS Route53? (yes/no) " user_response

# Convert the response to lowercase
user_response=$(echo "$user_response" | awk '{print tolower($0)}')

# Check user response and proceed or exit
case $user_response in
    yes|y)
        echo "Proceeding with adding $domain_name to AWS Route53."
        ;;
    no|n)
        echo "Exiting.  Edit 'terraform.tfvars' and run the script again."
        exit 1
        ;;
    *)
        echo "Invalid response. Please answer yes or no."
        exit 1
        ;;
esac



# Create a hosted zone using the AWS CLI
echo "Creating hosted zone in AWS Route 53..."

if ! output=$(aws route53 create-hosted-zone --name "$domain_name" --caller-reference "$(date +%s)"); then
    echo "Failed to create hosted zone."
    exit 1
fi

# Extract the hosted zone ID from the command output
if ! hosted_zone_id=$(echo "$output" | jq -r '.HostedZone.Id' | awk -F'/' '{print $3}'); then
    echo "Failed to extract hosted zone ID."
    exit 1
fi

echo "Hosted Zone ID: $hosted_zone_id"

echo "Getting name servers..."

# Get hosted zone details
if ! output=$(aws route53 get-hosted-zone --id "$hosted_zone_id"); then
    echo "Failed to get hosted zone details."
    exit 1
fi

# Extract and output the name servers
echo "Name Servers for Hosted Zone ID $hosted_zone_id:"
echo "(Login to your domain registrar and update the name servers to these values.)"
echo ""
echo "$output" | jq -r '.DelegationSet.NameServers[]'
