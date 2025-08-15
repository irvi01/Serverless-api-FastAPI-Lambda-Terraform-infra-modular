#Infraestructure main.tf

#Modulo da lambda
module "lambda_func" {
  source      = "./modules/lambda-func"
  lambda_name = var.lambda_name
  runtime     = "python3.12"
  memory_mb   = var.memory_mb
  timeout_sec = var.timeout_sec
  zip_file    = var.package_zip
}
# Modulo do API Gateway REST
module "apigw_rest" {
  source               = "./modules/apigw-rest"
  api_name             = "${var.lambda_name}-api"
  region               = var.region
  lambda_arn           = module.lambda_func.lambda_arn
  lambda_invoke_arn    = module.lambda_func.invoke_arn
  lambda_function_name = module.lambda_func.function_name
  throttle_burst       = 50
  throttle_rate        = 100
}

# Modulo do WAF para o API Gateway
module "waf_apigw" {
  source     = "./modules/waf-apigw"
  name       = "challenge-api-waf"
  region     = var.region
  api_id     = module.apigw_rest.rest_api_id
  stage_name = module.apigw_rest.stage_name
  tags       = { Project = "challenge-api" }
}