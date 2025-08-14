# Role IAM com permissão para logar no CloudWatch e executar a Lambda

# Serviço lambda pode assumir esta role
# (Aqui não vamos criar a role para evitar erro 409. Vamos apenas LER a role existente.)
data "aws_iam_role" "lambda_role" {
  name = "challenge-api-role"
}

# Role da função Lambda
# (Mantido o comentário: a role é a "challenge-api-role", já existente. Não criamos novamente.)
# (Se precisar criar uma vez manualmente, use o passo que já fizemos fora do Terraform.)
# (Sem lifecycle aqui porque não há recurso sendo criado.)
# -- REMOVIDO o resource "aws_iam_role" para evitar EntityAlreadyExists (409) --

# Política inline mínima para gerar logs no CloudWatch
resource "aws_iam_role_policy" "lambda_logs" {
  name = "${var.lambda_name}-logs"
  role = data.aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect   = "Allow",
      Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"],
      Resource = "*"
    }]
  })
}

#Função Lambda
# A função Lambda em si, que usa a role criada acima
# O arquivo ZIP deve estar no caminho relativo especificado em variables.tf
# O handler é definido no arquivo api.py como "api.handler"
# O runtime padrão é Python 3.12, mas pode ser alterado via variável
# A memória e timeout também são configuráveis via variáveis
# O nome da função Lambda é definido pela variável lambda_name

resource "aws_lambda_function" "this" {

  function_name    = var.lambda_name
  role             = data.aws_iam_role.lambda_role.arn
  filename         = var.zip_file
  handler          = "api.handler"
  runtime          = var.runtime
  memory_size      = var.memory_mb
  timeout          = var.timeout_sec
  source_code_hash = filebase64sha256(var.zip_file) #força atualização quando o ZIP muda
}
