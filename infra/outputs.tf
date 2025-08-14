output "api_url" {
  value = module.apigw_rest.api_url
}

output "api_key" {
  value     = module.apigw_rest.api_key
  sensitive = true
}
