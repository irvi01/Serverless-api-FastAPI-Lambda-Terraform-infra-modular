module "lambda_func" {
  source      = "./modules/lambda-func"
  lambda_name = var.lambda_name
  runtime     = "python3.12"
  memory_mb   = var.memory_mb
  timeout_sec = var.timeout_sec
  zip_file    = var.package_zip
}
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
