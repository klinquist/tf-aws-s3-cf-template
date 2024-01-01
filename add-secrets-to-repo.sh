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


echo "Getting secrets from terraform state..."
BUCKET=$(terraform state pull | jq -r '.resources[] | select((.type == "aws_s3_bucket") and (.name == "my_site_bucket")) | .instances[0].attributes.id')
CLOUDFRONT_ID=$(terraform state pull | jq -r '.resources[] | select(.type == "aws_cloudfront_distribution") | .instances[0].attributes.id')
ACCESS_KEY=$(terraform state pull | jq -r '.resources[] | select(.type == "aws_iam_access_key") | .instances[0].attributes.id')
SECRET=$(terraform state pull | jq -r '.resources[] | select(.type == "aws_iam_access_key") | .instances[0].attributes.secret')


function showSecrets () {
    echo "Create the following action secrets in your git repo:"
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
read -r -p "Do you want to automatically add secrets to your repo using the 'gh' github CLI command? (y/n) " answer
case $answer in
    [Yy]* )
        # Ask for the repo name
        read -r -p "Enter the repository name (username/repo): " repo_name
        
        
        # Add secrets to repo
        gh secret set AWS_S3_BUCKET_NAME -b "$BUCKET" -R "$repo_name" -a actions
        gh secret set AWS_CLOUDFRONT_DISTRIBUTION_ID -b "$CLOUDFRONT_ID" -R "$repo_name" -a actions
        gh secret set AWS_ACCESS_KEY_ID -b "$ACCESS_KEY" -R "$repo_name" -a actions
        gh secret set AWS_SECRET_ACCESS_KEY -b "$SECRET" -R "$repo_name" -a actions

        echo "done!"
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
