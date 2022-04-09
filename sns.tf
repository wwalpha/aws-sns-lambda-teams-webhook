# ----------------------------------------------------------------------------------------------
# AWS SNS Topic
# ----------------------------------------------------------------------------------------------
resource "aws_sns_topic" "error_notify" {
  name = "teams-error-nofity"
}

# ----------------------------------------------------------------------------------------------
# AWS SNS Topic Suscription
# ----------------------------------------------------------------------------------------------
resource "aws_sns_topic_subscription" "error_notify" {
  topic_arn = aws_sns_topic.error_notify.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.webhook.arn
}
