output "role_created" {
  value       = aws_iam_policy.state_file_access_iam_policy.arn
  description = "ARN of the IAM policy created for developer state file access"
}