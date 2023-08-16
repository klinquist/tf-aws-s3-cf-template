BUCKET=$(terraform state pull | jq '.resources[] | select(.type == "aws_s3_bucket") | .instances[0].attributes.id')
CLOUDFRONT_ID=$(terraform state pull | jq '.resources[] | select(.type == "aws_cloudfront_distribution") | .instances[0].attributes.id')
ACCESS_KEY=$(terraform state pull | jq '.resources[] | select(.type == "aws_iam_access_key") | .instances[0].attributes.id')
SECRET=$(terraform state pull | jq '.resources[] | select(.type == "aws_iam_access_key") | .instances[0].attributes.secret')

echo "Create the following action variables in your git repo:"
echo "AWS_S3_BUCKET_NAME=$BUCKET"   
echo "AWS_CLOUDFRONT_ID=$CLOUDFRONT_ID"
echo "AWS_ACCESS_KEY_ID=$ACCESS_KEY"
echo "AWS_SECRET_ACCESS_KEY=$SECRET"
