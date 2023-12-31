resource "aws_s3_bucket" "my_site_bucket" {
  bucket = var.domainName
}

resource "aws_s3_bucket" "log_bucket" {
  bucket = "${var.domainName}-logs"
}

resource "aws_s3_bucket_acl" "s3_bucket_acl" {
  bucket = aws_s3_bucket.log_bucket.id
  acl    = "private"
  depends_on = [aws_s3_bucket_ownership_controls.s3_bucket_acl_ownership]
}

# Resource to avoid error "AccessControlListNotSupported: The bucket does not allow ACLs"
resource "aws_s3_bucket_ownership_controls" "s3_bucket_acl_ownership" {
  bucket = aws_s3_bucket.log_bucket.id
  rule {
    object_ownership = "ObjectWriter"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "l1" {
  bucket = aws_s3_bucket.log_bucket.id
  rule {
    status = "Enabled"
    id     = "expire_all_files"
    expiration {
        days = 15
    }
  }
}

resource "aws_s3_bucket_ownership_controls" "my_site_bucket" {
  bucket = aws_s3_bucket.my_site_bucket.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_website_configuration" "my_site_bucket" {
  bucket = aws_s3_bucket.my_site_bucket.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
}


resource "aws_s3_bucket_public_access_block" "my_site_bucket" {
  bucket = aws_s3_bucket.my_site_bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}


resource "aws_s3_bucket_policy" "my_site_bucket" {
  bucket = aws_s3_bucket.my_site_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource = [
          aws_s3_bucket.my_site_bucket.arn,
          "${aws_s3_bucket.my_site_bucket.arn}/*",
        ]
      },
    ]
  })
  depends_on = [aws_s3_bucket_public_access_block.my_site_bucket]

}


resource "aws_s3_bucket_acl" "my_site_bucket" {
  depends_on = [
    aws_s3_bucket_ownership_controls.my_site_bucket,
    aws_s3_bucket_public_access_block.my_site_bucket,
  ]

  bucket = aws_s3_bucket.my_site_bucket.id
  acl    = "public-read"
}