variable "name" { type = string }
variable "region" { type = string }     # mesma região do API
variable "api_id" { type = string }     # ID do API Gateway REST
variable "stage_name" { type = string } 
variable "rate_limit" {
  type    = number
  default = 25
} # req por 5 min por IP
variable "enable" {
  type    = bool
  default = true
}
variable "tags" {
  type    = map(string)
  default = {}
}

# WAF v2 REGIONAL 
variable "scope" {
  type    = string
  default = "REGIONAL"
  validation {
    condition     = contains(["REGIONAL"], var.scope)
    error_message = "Este módulo suporta apenas scope REGIONAL (API Gateway Regional)."
  }
}
