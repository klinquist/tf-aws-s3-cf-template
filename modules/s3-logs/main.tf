resource "aws_s3_bucket" "log_bucket" {
  bucket = "${var.domain_name}-logs"
}

resource "aws_s3_bucket_ownership_controls" "s3_bucket_acl_ownership" {
  bucket = aws_s3_bucket.log_bucket.id
  rule {
    object_ownership = "ObjectWriter"
  }
}

resource "aws_s3_bucket_acl" "s3_bucket_acl" {
  bucket = aws_s3_bucket.log_bucket.id
  acl    = "private"

  depends_on = [aws_s3_bucket_ownership_controls.s3_bucket_acl_ownership]
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
