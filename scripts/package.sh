#!/bin/bash
set -euo pipefail # Exit em qualquer erro, variáveis não definidas ou falha em pipes

# Variaveis de caminho
# ROOT_DIR é a raiz do repositório, BUILD_DIR é onde as dependências e código serão empacotados,
# ZIP_FILE é o arquivo zip final, APP_DIR é onde o código da aplicação está localizado,
# e REQ_FILE é o arquivo de requisitos do Python.  
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"  
BUILD_DIR="$ROOT_DIR/build"
ZIP_FILE="$ROOT_DIR/package.zip"
APP_DIR="$ROOT_DIR/app"
REQ_FILE="$APP_DIR/requirements.txt"

echo "📦 Empacotando Lambda a partir de: $ROOT_DIR"

# Limpeza anterior
rm -rf "$BUILD_DIR"
rm -f "$ZIP_FILE"

# Verificações básicas para garantir que tudo está no lugar e as ferramentas necessárias estão instaladas
command -v zip >/dev/null 2>&1 || { echo "❌ 'zip' não encontrado. Instale: sudo apt install -y zip"; exit 1; }
test -f "$REQ_FILE" || { echo "❌ $REQ_FILE não existe"; exit 1; }
test -f "$APP_DIR/api.py" -o -f "$APP_DIR/main.py" || { echo "❌ app/api.py não encontrado"; exit 1; }

# Instala dependências no diretório de build 
mkdir -p "$BUILD_DIR"
python -m pip install --upgrade pip >/dev/null
python -m pip install --target "$BUILD_DIR" -r "$REQ_FILE"

# Copia o código
cp -r "$APP_DIR/"* "$BUILD_DIR/"

# Higiene
find "$BUILD_DIR" -type d -name "__pycache__" -prune -exec rm -rf {} +

# Cria o zip na raiz do repo
(
  cd "$BUILD_DIR"
  zip -rq "$ZIP_FILE" .
)
echo "Pacote gerado: $ZIP_FILE"
