# ----------------------------------------------------------------------------------------------
# Lambda Function - Cognito
# ----------------------------------------------------------------------------------------------
resource "aws_lambda_function" "webhook" {
  function_name    = "teams-webhook"
  handler          = "index.handler"
  filename         = data.archive_file.lambda_webhook.output_path
  source_code_hash = data.archive_file.lambda_webhook.output_sha
  memory_size      = 128
  role             = aws_iam_role.webhook.arn
  runtime          = "nodejs14.x"
  timeout          = 10
  
  environment {
    variables = {
      WEBHOOK_URL = var.webhook_url
    }
  }
}

# ----------------------------------------------------------------------------------------------
# Lambda Function Permission - SNS
# ----------------------------------------------------------------------------------------------
resource "aws_lambda_permission" "webhook" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.webhook.arn
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.error_notify.arn
}

# ----------------------------------------------------------------------------------------------
# Archive file - Lambda webhook module
# ----------------------------------------------------------------------------------------------
data "archive_file" "lambda_webhook" {
  type        = "zip"
  output_path = "${path.module}/dist/webhook.zip"

  source {
    content  = <<EOT
'use strict';
exports.__esModule = true;
exports.handler = void 0;
var https = require('node:https');
var WEBHOOK_URL = process.env.WEBHOOK_URL;
var handler = function (event) {
  var sns = event.Records[0].Sns;
  var context = JSON.parse(sns.Message);
  var payload = context.responsePayload;
  var datas = JSON.stringify({
    type: 'message',
    attachments: [
      {
        contentType: 'application/vnd.microsoft.card.adaptive',
        content: {
          $schema: 'http://adaptivecards.io/schemas/adaptive-card.json',
          type: 'AdaptiveCard',
          version: '1.2',
          body: [
            {
              type: 'TextBlock',
              text: payload.errorType,
              size: 'Large',
              weight: 'Bolder',
              spacing: 'None',
            },
            {
              type: 'TextBlock',
              text: payload.errorMessage,
              wrap: true,
            },
          ],
        },
      },
    ],
  });
  var request = https.request(WEBHOOK_URL, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Content-Length': Buffer.byteLength(datas),
    },
  });
  request.write(datas);
  request.end();
};
exports.handler = handler;
EOT
    filename = "index.js"
  }
}


# ----------------------------------------------------------------------------------------------
# AWS IAM Policy Document - Lambda
# ----------------------------------------------------------------------------------------------
data "aws_iam_policy_document" "lambda" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

# ----------------------------------------------------------------------------------------------
# AWS Lambda Role - Cognito
# ----------------------------------------------------------------------------------------------
resource "aws_iam_role" "webhook" {
  name               = "WebhookRole"
  assume_role_policy = data.aws_iam_policy_document.lambda.json

  lifecycle {
    create_before_destroy = false
  }
}

# ----------------------------------------------------------------------------------------------
# AWS Lambda Execution Policy - CloudWatch Full Access
# ----------------------------------------------------------------------------------------------
resource "aws_iam_role_policy_attachment" "cloudwatch" {
  role       = aws_iam_role.webhook.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}
