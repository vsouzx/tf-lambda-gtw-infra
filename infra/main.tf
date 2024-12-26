resource "aws_iam_role" "iam_for_lambda"{
    name                    = "iam_for_lambda"
    assume_role_policy      = data.aws_iam_policy_document.assume_role.json
}

resource "aws_iam_policy" "lambda_logging" {
    name = "lambda_logging"
    path = "/"
    description = "IAM policy for logging from a lambda"
    policy = <<EOF
    {
        "Version":"2012-10-17",
        "Statement": [
            {
                "Action": [
                    "logs:CreateLogGroup",
                    "logs:CreateLogStream",
                    "logs:PutLogEvents"
                ],
                "Resource": "arn:aws:logs:*:*:*",
                "Effect": "Allow"
            },
            {
                "Action": [
                    "dynamodb:*"
                ],
                "Resource": "*",
                "Effect": "Allow"
            }
        ]
    }
    EOF
}

resource "aws_lambda_function" "lambda" {
    filename           = "lambda.zip"
    function_name      = "avaliacoes_lambda"
    role               = aws_iam_role.iam_for_lambda.arn

    source_code_hash   = data.archive_file.lambda.output_base64sha256

    runtime            = "python3.10"
    handler            = "lambda.lambda_handler"

    environment {
    variables = {
      API_GATEWAY_URL = var.api_gateway_url
      DYNAMODB_TABLE  = var.dynamo_table
    }
  }
}

resource "aws_cloudwatch_log_group" "example"{
    name = "/aws/lambda/${aws_lambda_function.lambda.function_name}"
    retention_in_days = 7
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
    role = aws_iam_role.iam_for_lambda.name
    policy_arn = aws_iam_policy.lambda_logging.arn
}

resource "aws_api_gateway_rest_api" "avaliacoes_gw_api"{
    name = "avaliacoes_gw_api"
    description = "REST API for lambda"

    endpoint_configuration {
      types = ["REGIONAL"]
    }
}

resource "aws_api_gateway_resource" "avaliacoes_gw_api_resource" {
    parent_id       = aws_api_gateway_rest_api.avaliacoes_gw_api.root_resource_id
    path_part       = "avaliacoes"
    rest_api_id     = aws_api_gateway_rest_api.avaliacoes_gw_api.id
}

resource "aws_api_gateway_method" "gw_api_method_post" {
    authorization   = "NONE"
    http_method     = "POST"
    resource_id     = aws_api_gateway_resource.avaliacoes_gw_api_resource.id
    rest_api_id     = aws_api_gateway_rest_api.avaliacoes_gw_api.id
}

resource "aws_api_gateway_method" "gw_api_method_get" {
    authorization   = "NONE"
    http_method     = "GET"
    resource_id     = aws_api_gateway_resource.avaliacoes_gw_api_resource.id
    rest_api_id     = aws_api_gateway_rest_api.avaliacoes_gw_api.id
}

resource "aws_api_gateway_method" "gw_api_method_put" {
    authorization   = "NONE"
    http_method     = "PUT"
    resource_id     = aws_api_gateway_resource.avaliacoes_gw_api_resource.id
    rest_api_id     = aws_api_gateway_rest_api.avaliacoes_gw_api.id
}

resource "aws_api_gateway_integration" "lambda_integration_post" {
    http_method = aws_api_gateway_method.gw_api_method_post.http_method
    resource_id = aws_api_gateway_resource.avaliacoes_gw_api_resource.id
    rest_api_id = aws_api_gateway_rest_api.avaliacoes_gw_api.id
    type        = "AWS_PROXY"

    integration_http_method     = "POST" #para lambda_proxy, sempre deve ser POST
    uri = aws_lambda_function.lambda.invoke_arn
}

resource "aws_api_gateway_integration" "lambda_integration_get" {
    http_method = aws_api_gateway_method.gw_api_method_get.http_method
    resource_id = aws_api_gateway_resource.avaliacoes_gw_api_resource.id
    rest_api_id = aws_api_gateway_rest_api.avaliacoes_gw_api.id
    type        = "AWS_PROXY"

    integration_http_method     = "POST" #para lambda_proxy, sempre deve ser POST
    uri = aws_lambda_function.lambda.invoke_arn
}

resource "aws_api_gateway_integration" "lambda_integration_put" {
    http_method = aws_api_gateway_method.gw_api_method_put.http_method
    resource_id = aws_api_gateway_resource.avaliacoes_gw_api_resource.id
    rest_api_id = aws_api_gateway_rest_api.avaliacoes_gw_api.id
    type        = "AWS_PROXY"

    integration_http_method     = "POST" #para lambda_proxy, sempre deve ser POST
    uri = aws_lambda_function.lambda.invoke_arn
}

resource "aws_api_gateway_method_response" "response_200_post" {
  rest_api_id = aws_api_gateway_rest_api.avaliacoes_gw_api.id
  resource_id = aws_api_gateway_resource.avaliacoes_gw_api_resource.id
  http_method = aws_api_gateway_method.gw_api_method_post.http_method
  status_code = "200"
}

resource "aws_api_gateway_method_response" "response_200_get" {
  rest_api_id = aws_api_gateway_rest_api.avaliacoes_gw_api.id
  resource_id = aws_api_gateway_resource.avaliacoes_gw_api_resource.id
  http_method = aws_api_gateway_method.gw_api_method_get.http_method
  status_code = "200"
}

resource "aws_api_gateway_method_response" "response_200_put" {
  rest_api_id = aws_api_gateway_rest_api.avaliacoes_gw_api.id
  resource_id = aws_api_gateway_resource.avaliacoes_gw_api_resource.id
  http_method = aws_api_gateway_method.gw_api_method_put.http_method
  status_code = "200"
}

resource "aws_api_gateway_deployment" "api_deployment" {
    rest_api_id = aws_api_gateway_rest_api.avaliacoes_gw_api.id

      triggers = {
        redeployment = sha1(jsonencode([
            aws_api_gateway_resource.avaliacoes_gw_api_resource.id,
            aws_api_gateway_method.gw_api_method_post.id,
            aws_api_gateway_method.gw_api_method_get.id,
            aws_api_gateway_method.gw_api_method_put.id,
            aws_api_gateway_integration.lambda_integration_post.id,
            aws_api_gateway_integration.lambda_integration_get.id,
            aws_api_gateway_integration.lambda_integration_put.id
        ]))
    }

    lifecycle {
      create_before_destroy = true
    }

    depends_on = [ 
        aws_api_gateway_integration.lambda_integration_post,
        aws_api_gateway_integration.lambda_integration_get,
        aws_api_gateway_integration.lambda_integration_put
    ]
}

resource "aws_lambda_permission" "apigw_lambda_permission" {
    action = "lambda:InvokeFunction"
    function_name = aws_lambda_function.lambda.function_name
    principal = "apigateway.amazonaws.com"
    statement_id = "AllowExecutionFromAPIGateway"
    source_arn = "${aws_api_gateway_rest_api.avaliacoes_gw_api.execution_arn}/*"
}

resource "aws_api_gateway_stage" "api_stage" {
  deployment_id = aws_api_gateway_deployment.api_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.avaliacoes_gw_api.id
  stage_name    = var.stage_name
}

