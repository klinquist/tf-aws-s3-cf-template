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


echo "Getting secrets from terraform state..."
BUCKET=$(terraform state pull | jq -r '.resources[] | select((.type == "aws_s3_bucket") and (.name == "my_site_bucket")) | .instances[0].attributes.id')
CLOUDFRONT_ID=$(terraform state pull | jq -r '.resources[] | select(.type == "aws_cloudfront_distribution") | .instances[0].attributes.id')
ACCESS_KEY=$(terraform state pull | jq -r '.resources[] | select(.type == "aws_iam_access_key") | .instances[0].attributes.id')
SECRET=$(terraform state pull | jq -r '.resources[] | select(.type == "aws_iam_access_key") | .instances[0].attributes.secret')


function showSecrets () {
    echo "Create the following action secrets in your git repo if you want to set up auto-deployment in the future."
    echo ""
    echo "AWS_S3_BUCKET_NAME=$BUCKET"
    echo "AWS_CLOUDFRONT_DISTRIBUTION_ID=$CLOUDFRONT_ID"
    echo "AWS_ACCESS_KEY_ID=$ACCESS_KEY"
    echo "AWS_SECRET_ACCESS_KEY=$SECRET"
}


# Check if gh is installed
if ! command -v gh &> /dev/null; then
    echo "gh is not installed. You'll have to manually add the secrets to github."
    showSecrets
    exit
fi

# Check if logged in to GitHub
if ! gh auth status &> /dev/null; then
    echo "You are not logged in to GitHub. You'll have to manually add the secrets to github."
    showSecrets
    exit 1
fi




# Ask the user if they want to add secrets to their repo
read -r -p "Do you want to create a new repository from this folder, commit all files, and set up a github action to auto-deploy the '_site' subfolder to s3? " answer
case $answer in
    [Yy]* )
        get_domain_name
        rm -rf .git
        git init
        mkdir -p .github/workflows
        mv sample-github-action/build-and-deploy.yml .github/workflows/deploy.yml
        rm -rf sample-github-action
        echo "Creating repo $domain_name"
        gh repo create "$domain_name" --private --source=. --remote=upstream
        echo "Adding secrets to repo..."
        gh secret set AWS_S3_BUCKET_NAME -b "$BUCKET" -a actions
        gh secret set AWS_CLOUDFRONT_DISTRIBUTION_ID -b "$CLOUDFRONT_ID" --a actions
        gh secret set AWS_ACCESS_KEY_ID -b "$ACCESS_KEY" -a actions
        gh secret set AWS_SECRET_ACCESS_KEY -b "$SECRET" -a actions
        echo "Committing files to repo..."
        git add ./*
        git commit -m "Initial commit"
        git push -u origin main
        echo "Done! In a few minutes, your site should be available at https://www.$domain_name"
        exit 0
        ;;
    [Nn]* )
        showSecrets
        exit 0
        ;;
    * )
        echo "Invalid response."
        exit 1
        ;;
esac