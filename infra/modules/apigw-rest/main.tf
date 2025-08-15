# Infraestrutura para API Gateway REST com Lambda Proxy
# Este módulo cria um API Gateway REST que integra com uma função Lambda
# A função Lambda deve ser criada em outro módulo e referenciada aqui

resource "aws_api_gateway_rest_api" "this" {
  name = var.api_name
}

# Rota proxy: ANY /{proxy+}
resource "aws_api_gateway_resource" "proxy" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_rest_api.this.root_resource_id
  path_part   = "{proxy+}"
}

resource "aws_api_gateway_method" "any_proxy" {
  rest_api_id      = aws_api_gateway_rest_api.this.id
  resource_id      = aws_api_gateway_resource.proxy.id
  http_method      = "ANY"
  authorization    = "NONE"
  api_key_required = true
}

resource "aws_api_gateway_integration" "any_proxy" {
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.proxy.id
  http_method             = aws_api_gateway_method.any_proxy.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "arn:aws:apigateway:${var.region}:lambda:path/2015-03-31/functions/${var.lambda_arn}/invocations"
}

# Rota raiz: ANY /
resource "aws_api_gateway_method" "any_root" {
  rest_api_id      = aws_api_gateway_rest_api.this.id
  resource_id      = aws_api_gateway_rest_api.this.root_resource_id
  http_method      = "ANY"
  authorization    = "NONE"
  api_key_required = true
}

resource "aws_api_gateway_integration" "any_root" {
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_rest_api.this.root_resource_id
  http_method             = aws_api_gateway_method.any_root.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "arn:aws:apigateway:${var.region}:lambda:path/2015-03-31/functions/${var.lambda_arn}/invocations"
}

# Permitir que o API Gateway invoque a Lambda
resource "aws_lambda_permission" "allow_apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.this.execution_arn}/*/*"
}

# Deploy + Stage com throttling

resource "aws_api_gateway_deployment" "dep" {
  rest_api_id = aws_api_gateway_rest_api.this.id

  # só redeploy quando integração ou métodos mudarem
  triggers = {
    redeploy = sha1(jsonencode([
      aws_api_gateway_integration.any_proxy.id,
      aws_api_gateway_integration.any_root.id,
      aws_api_gateway_method.any_proxy.id,
      aws_api_gateway_method.any_root.id
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_api_gateway_integration.any_proxy,
    aws_api_gateway_integration.any_root
  ]
}


resource "aws_api_gateway_stage" "prod" {
  rest_api_id          = aws_api_gateway_rest_api.this.id
  deployment_id        = aws_api_gateway_deployment.dep.id
  stage_name           = "prod"
  xray_tracing_enabled = true

  # Logs de acesso
  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.apigw_access.arn
    # JSON facilita parse no CloudWatch Logs Insights
    format = jsonencode({
      requestId      = "$context.requestId",
      ip             = "$context.identity.sourceIp",
      requestTime    = "$context.requestTime",
      httpMethod     = "$context.httpMethod",
      path           = "$context.path",
      protocol       = "$context.protocol",
      status         = "$context.status",
      responseLength = "$context.responseLength",
      errorMessage   = "$context.error.message",
      integrationErr = "$context.integration.error"
    })
  }

  # Garante que a conta do APIGW e o LogGroup existam antes do stage
  depends_on = [
    aws_api_gateway_account.account,
    aws_cloudwatch_log_group.apigw_access
  ]
}

# throttling global por método/rota (cobre tudo)
resource "aws_api_gateway_method_settings" "all" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  stage_name  = aws_api_gateway_stage.prod.stage_name
  method_path = "*/*"

  settings {
    throttling_burst_limit = var.throttle_burst
    throttling_rate_limit  = var.throttle_rate
    # se quiser, pode ligar métricas depois. logging exige role do CW.
    # metrics_enabled   = true
    # logging_level     = "INFO"
    # data_trace_enabled = false
  }
}

# API Key (gate simples + tracking)
resource "aws_api_gateway_api_key" "key" {
  name    = "${var.api_name}-key"
  enabled = true
}

# Usage Plan com throttling/quota
resource "aws_api_gateway_usage_plan" "plan" {
  name = "${var.api_name}-plan"

  api_stages {
    api_id = aws_api_gateway_rest_api.this.id
    stage  = aws_api_gateway_stage.prod.stage_name
  }
  throttle_settings {
    burst_limit = var.throttle_burst
    rate_limit  = var.throttle_rate
  }

  quota_settings {
    limit  = 10000
    period = "MONTH"
  }
}

# Vincular a key ao plano
resource "aws_api_gateway_usage_plan_key" "bind" {
  key_id        = aws_api_gateway_api_key.key.id
  key_type      = "API_KEY"
  usage_plan_id = aws_api_gateway_usage_plan.plan.id
}

# Role do API Gateway para escrever logs no CloudWatch
# (necessário para logs de acesso, métricas, etc.)
resource "aws_iam_role" "apigw_cw" {
  name = var.api_gw_logs_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Service = "apigateway.amazonaws.com" },
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "apigw_cw_managed" {
  role       = aws_iam_role.apigw_cw.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
}

resource "aws_api_gateway_account" "account" {
  cloudwatch_role_arn = aws_iam_role.apigw_cw.arn
}


resource "aws_cloudwatch_log_group" "apigw_access" {
  name              = "/aws/apigateway/${aws_api_gateway_rest_api.this.name}/access"
  retention_in_days = var.logs_retention_days
}

