resource "aws_iam_user" "GithubActionUser" {
  name = "GithubActionUserFor-${var.domain_name}"
}

resource "aws_iam_access_key" "GithubAccessKey" {
  user = aws_iam_user.GithubActionUser.name
}

resource "aws_iam_user_policy" "GitHubActionUserPolicy" {
  name = "GithubActionUserPolicyFor-${var.domain_name}"
  user = aws_iam_user.GithubActionUser.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:*"
        ]
        Resource = [
          var.bucket_arn,
          "${var.bucket_arn}/*"
        ]
        Effect = "Allow"
      },
      {
        Sid    = "VisualEditor2"
        Effect = "Allow"
        Action = "cloudfront:*"
        Resource = var.distribution_arn
      }
    ]
  })
}
