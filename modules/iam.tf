resource "aws_iam_user" "GithubActionUser" {
    name = "GithubActionUserFor-${var.domainName}"
}

resource "aws_iam_access_key" "GithubAccessKey" {
  user = aws_iam_user.GithubActionUser.name
}

resource "aws_iam_user_policy" "GitHubActionUserPolicy" {
  count = 1
  name = "GithubActionUserPolicyFor-${var.domainName}"
  user = aws_iam_user.GithubActionUser.name
policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": [
                "s3:*"
            ],
            "Resource": [
                "arn:aws:s3:::${var.domainName}",
                "arn:aws:s3:::${var.domainName}/*"
            ],
            "Effect": "Allow"
        },
        {
            "Sid": "VisualEditor2",
            "Effect": "Allow",
            "Action": "cloudfront:*",
            "Resource": "${aws_cloudfront_distribution.my_cloudfront.arn}"
        }
    ]
}
EOF
}