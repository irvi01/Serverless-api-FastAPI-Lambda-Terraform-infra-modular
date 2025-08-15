# Challenge API — FastAPI on AWS Lambda (Terraform + GitHub Actions)

> Backendzinho enxuto, infra como código e deploy sem drama. 😎

## 🧭 Visão geral
Este projeto entrega uma **API FastAPI** rodando em **AWS Lambda**, exposta pelo **API Gateway REST** e protegida por **API Key + Usage Plan**.  
A infra é criada com **Terraform** (state remoto em **S3** com lock em **DynamoDB**) e o deploy é automático via **GitHub Actions** usando **OIDC**.

### Endpoints
- `GET /health` → `{"status":"ok"}`
- `GET /hello?name=SeuNome` → `{"message":"Hello, SeuNome!"}`  
  > Todos os endpoints pedem `x-api-key: <API_KEY>`

---

## 🏗️ Arquitetura simplificada
```
                +------------------+
                |  GitHub Actions  |
                +---------+--------+
                          |  OIDC (assume role)
                          v
                +-----------------------+
                |   IAM Role (AWS)      |
                +-----------+-----------+
                            |
                            v
                +-----------+-----------+
                |   Terraform (IaC)     |
                |   backend: S3 + DDB   |
                +-----------+-----------+
                            |
                            v
     +----------------------+----------------------+
     |                   AWS                       |
     |                                              |
     |  +------------------+     +----------------+ |
     |  | Lambda           | <-- | API Gateway    | |
     |  | challenge-api    |     | REST (prod)    | |
     |  | FastAPI + Mangum |     |  - ANY /{proxy+}| |
     |  +------------------+     |  - API Key     | |
     |                            +----------------+ |
     +----------------------------------------------+

S3 bucket: challenge-entrevista (state)
DynamoDB table: desafio-tf-locks (state lock)
```

---

## ⏱️ Em 60 segundos: como tudo conversa
1. É dado um` **push** na `main` → o **GitHub Action** começa.
2. O Action usa **OIDC** para **assumir uma IAM Role** na AWS (credenciais temporárias, nada de chave fixa).
3. O **Terraform** inicializa com **state no S3** e **lock no DynamoDB**, aplica a infra (Lambda, API Gateway, etc.).
4. Sai no output a **URL da API** e a **API Key** para uso.
5. A Action roda **smoke tests** chamando `/health` e `/hello` com a **API Key**.

---

## 📚 Glossário 
- **ASGI** (Asynchronous Server Gateway Interface) → “gramática” moderna pra apps web Python falarem com servidores de forma **assíncrona** (inclui WebSockets). O **FastAPI** fala ASGI.
- **Mangum** → O “intérprete” que traduz **API Gateway/Lambda ↔ ASGI**. Permite FastAPI rodar dentro da Lambda.
- **OIDC** (OpenID Connect) → Jeito seguro do GitHub provar quem ele é para a AWS e **conseguir credenciais temporárias** sem gravar senha/keys.
- **STS** (Security Token Service) → Serviço da AWS que **emite credenciais temporárias** quando a Action assume a Role.
- **Terraform Backend** → Onde o **state** do Terraform mora (aqui: **S3**). Sem isso, cada máquina teria um state diferente (caos).
- **State Lock** → Cadeado no state (aqui: **DynamoDB**) para **evitar dois applys ao mesmo tempo**.
- **API Key** → Uma chave simples no header (`x-api-key`) pra controlar quem consome a API.
- **Usage Plan** → Regras de **limite de uso** por API Key (quantas req por segundo e por mês).

---

## 🧰 Tech stack
- **Linguagem:** Python 3.12
- **Framework:** FastAPI + Mangum (adapter ASGI para Lambda)
- **Infra:** Terraform (AWS provider)
- **AWS:** Lambda, API Gateway REST, S3 (state), DynamoDB (lock), IAM
- **CI/CD:** GitHub Actions com OIDC
- **Empacotamento:** `scripts/package.sh` (gera `package.zip`)

---

## ✅ O que foi implementado
- **Lambda `challenge-api`** (Python 3.12) com FastAPI + Mangum.
- **API Gateway REST** com:
  - Rota `ANY /{proxy+}` e `ANY /` (Lambda Proxy Integration).
  - **API Key** + **Usage Plan** (quota e throttling).
- **Permissão** para o API Gateway invocar a Lambda.
- **Terraform modular**:
  - `modules/lambda-func` → função + IAM mínimo de logs.
  - `modules/apigw-rest` → API, métodos, integrações, stage `prod`, API Key, Usage Plan.
- **Backend do Terraform**: S3 (`challenge-entrevista`) + DynamoDB (`desafio-tf-locks`).
- **Pipeline** (`.github/workflows/deploy.yaml`): empacota, assume role via OIDC, `init/plan/apply`, smoke tests.

---

## 🧱 Antes de tudo: criar S3 + DynamoDB pro state
Sem isso, o `terraform init` não sabe onde salvar o state.

> Em `us-east-1`, a criação do bucket **não** usa `--create-bucket-configuration`.

```bash
# Variáveis (exemplo)
BUCKET="challenge-entrevista"
TABLE="desafio-tf-locks"
REGION="us-east-1"

# 1) Criar bucket S3
if [ "$REGION" = "us-east-1" ]; then
  aws s3api create-bucket --bucket "$BUCKET" --region "$REGION"
else
  aws s3api create-bucket --bucket "$BUCKET" --region "$REGION"     --create-bucket-configuration LocationConstraint="$REGION"
fi

# 2) (recomendado) Habilitar versionamento + criptografia em repouso
aws s3api put-bucket-versioning   --bucket "$BUCKET" --versioning-configuration Status=Enabled

aws s3api put-bucket-encryption   --bucket "$BUCKET"   --server-side-encryption-configuration '{
    "Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]
  }'

# 3) (opcional) Forçar TLS only
aws s3api put-bucket-policy --bucket "$BUCKET" --policy '{
  "Version":"2012-10-17",
  "Statement":[{
    "Sid":"DenyInsecureTransport",
    "Effect":"Deny",
    "Principal":"*",
    "Action":"s3:*",
    "Resource":[
      "arn:aws:s3:::'"$BUCKET"'",
      "arn:aws:s3:::'"$BUCKET"'/*"
    ],
    "Condition":{"Bool":{"aws:SecureTransport":"false"}}
  }]}'

# 4) Criar tabela DynamoDB para lock
aws dynamodb create-table   --table-name "$TABLE"   --attribute-definitions AttributeName=LockID,AttributeType=S   --key-schema AttributeName=LockID,KeyType=HASH   --billing-mode PAY_PER_REQUEST   --region "$REGION"
```

### Onde coloco esses nomes depois?
- **Local (CLI)** — no `terraform init`:
```bash
cd infra
terraform init -reconfigure   -backend-config="bucket=$BUCKET"   -backend-config="key=infra/terraform.tfstate"   -backend-config="region=$REGION"   -backend-config="dynamodb_table=$TABLE"   -backend-config="encrypt=true"
```
- **Pipeline (GitHub Actions)** — como **Secrets** do repositório:
  - `TF_STATE_BUCKET` = `challenge-entrevista`
  - `TF_STATE_KEY`    = `infra/terraform.tfstate`
  - `TF_STATE_TABLE`  = `desafio-tf-locks`
  - `AWS_REGION`      = `us-east-1`

> Dica: padronize o **key** do state por projeto/ambiente (ex.: `infra/terraform.tfstate`).

---

## 🚀 Como rodar (local + AWS)
### 0) Pré-requisitos
- **AWS CLI** autenticado (perfil local) ou GitHub Actions com OIDC.
- **Terraform ≥ 1.6**.
- **Python 3.12** (para empacotar local).
- **jq** (para smoke tests da pipeline).

### 1) Empacotar a Lambda
```bash
chmod +x scripts/package.sh
./scripts/package.sh   # gera package.zip na raiz do repo
```

### 2) Aplicar infra
```bash
cd infra
terraform plan  -var="region=us-east-1" -var="package_zip=../package.zip"
terraform apply -auto-approve -var="region=us-east-1" -var="package_zip=../package.zip"
```

### 3) Outputs úteis
```bash
terraform output -raw api_url
terraform output -raw api_key
```

---

## 🧪 Como testar rápido
```bash
API_URL=$(terraform -chdir=infra output -raw api_url)
API_KEY=$(terraform -chdir=infra output -raw api_key)

curl -sS -H "x-api-key: $API_KEY" "$API_URL/health"
# -> {"status":"ok"}

curl -sS -H "x-api-key: $API_KEY" "$API_URL/hello?name=Irvi"
# -> {"message":"Hello, Irvi!"}
```

---

## 🔒 Segurança (o que já tem hoje)
**API & rede**
- **API Key obrigatória** em todos os métodos (Usage Plan aplicado).
- **Somente HTTPS** no API Gateway (TLS obrigatório).

**Identidade & acesso**
- **OIDC** na pipeline → **credenciais temporárias** (nada de chaves fixas).
- **Least-Privilege**: permissões limitadas ao bucket/tabela/recursos necessários.
- **`iam:PassRole`** somente para `challenge-api-role`.
- **Mascaramento** da `api_key` nos logs da Action.

**State protegido**
- **S3 com versionamento + SSE (AES-256)**.
- **DynamoDB** como lock (evita corridas e corrupção).

> Próximos passos de hardening: WAF no API Gateway, alarms (5xx/Throttles), rotação das API Keys, authorizer JWT (Cognito) e KMS gerenciado se necessário.

---

## ⏱️ Limites de uso (throttling & quotas) — explicado simples
Pensa em duas “catracas”:  
1) **Do Stage/Method** (nível da API como um todo).  
2) **Do Usage Plan** (nível de cada API Key).  

O **limite que vale** para um cliente é o **menor** dos dois.

**Valores padrão neste projeto:**
- **Throttling stage/method:** 100 req/s com **burst** 50 (picos curtos permitidos).  
- **Throttling por API Key:** 100 req/s com **burst** 50.  
- **Quota por API Key:** 10.000 req **por mês**.  

Se passar do limite: **HTTP 429 – Too Many Requests**. Tente de novo com **exponential backoff** (esperas crescentes + aleatório).

**Onde mudar isso no código:**
- `infra/modules/apigw-rest/main.tf`
  - `aws_api_gateway_method_settings "all"` → `throttling_rate_limit`, `throttling_burst_limit`
  - `aws_api_gateway_usage_plan "plan"` → `throttle_settings{}` e `quota_settings{}`

**Como ver o 429 na prática (teste):**
```bash
API_URL=$(terraform -chdir=infra output -raw api_url)
API_KEY=$(terraform -chdir=infra output -raw api_key)

# 200 chamadas concorrentes (agrupa por status)
seq 1 200 | xargs -n1 -P50 -I{}   curl -s -o /dev/null -w "%{http_code}
"   -H "x-api-key: $API_KEY" "$API_URL/health" | sort | uniq -c
```

---

## 🐛 Erros que vimos (e como consertamos)
- **409 – `Lambda CreateFunction`: já existe**
  - **Causa**: a função existia, mas o **state** da pipeline estava em outro **key**.
  - **Fix**: importar a função no state (`terraform import … challenge-api`) e migrar para `infra/terraform.tfstate`. Dica: **import declarativo** no código.

- **403 – `S3 HeadObject Forbidden` no init**
  - **Causa**: bucket errado/typo **ou** falta de permissão na role OIDC.
  - **Fix**: corrigir policy e secrets (`TF_STATE_BUCKET/KEY`) e checar com `head-bucket`/`list-objects`.

- **DynamoDB `ConditionalCheckFailed` (lock preso)**
  - **Causa**: cadeado do state ficou órfão numa migração.
  - **Fix**: `terraform force-unlock -force <LOCK_ID>` e repetir a migração.

- **`API Gateway BadRequest: Invalid ARN`**
  - **Causa**: `var.region` vazio → ARN sem região e URL com `execute-api..amazonaws.com`.
  - **Fix**: passar `-var="region=us-east-1"` ou usar `data.aws_region.current.name` no módulo.

- **409 – `Lambda AddPermission`: statement id existe**
  - **Causa**: já havia `AllowAPIGatewayInvoke` na função.
  - **Fix**: `terraform import module.apigw_rest.aws_lambda_permission.allow_apigw challenge-api/AllowAPIGatewayInvoke` (ou versionar o `statement_id` por ambiente).

- **Smoke falhou mesmo com resposta OK**
  - **Causa**: `grep` era rígido (`"Hello, CI"`) e a resposta tinha `!`.
  - **Fix**: validar com `jq` ou regex tolerante.

> Proteção permanente: um step que falha se o plan tentar **criar** a Lambda (state divergente).

---

## 🗂️ Estrutura do projeto (resumo)
```
desafio-entrevista/
├─ app/
│  ├─ api.py                 # FastAPI app + Mangum handler
│  └─ requirements.txt
├─ infra/
│  ├─ backend.tf             # backend S3 + DynamoDB (state remoto)
│  ├─ main.tf                # módulos: lambda-func e apigw-rest
│  ├─ providers.tf           # provider AWS
│  ├─ variables.tf           # region, lambda_name, package_zip...
│  ├─ outputs.tf             # api_url, api_key
│  └─ modules/
│     ├─ lambda-func/
│     │  ├─ main.tf
│     │  ├─ variables.tf
│     │  └─ outputs.tf
│     └─ apigw-rest/
│        ├─ main.tf
│        ├─ variables.tf
│        └─ outputs.tf
├─ scripts/
│  └─ package.sh
└─ .github/workflows/
   └─ deploy.yaml
```

---

## 📌 Próximos passos legais
- Versionar/alias da Lambda (deploys 0-downtime).
- Observabilidade melhor (métricas + alarmes).
- Stage `dev` com **Usage Plans** separados.
- Auth “de verdade” (JWT/Cognito) quando necessário.

---

## 📜 Licença
Este repositório é um desafio técnico. Ajuste a licença conforme necessidade (MIT, Apache-2.0, etc.).
