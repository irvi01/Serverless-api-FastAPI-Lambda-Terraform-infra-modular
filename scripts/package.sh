#!/usr/bin/env bash
set -euo pipefail

# Empacota a Lambda em package.zip na RAIZ do repo
# - Instala dependências em build/ (vendor)
# - Copia o código de app/ para build/
# - Gera package.zip com tudo dentro (sem subpasta "python/")
# Compatível com Terraform var package_zip=../package.zip (rodando de infra/)

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT_DIR/app"
BUILD_DIR="$ROOT_DIR/build"
ZIP_PATH="$ROOT_DIR/package.zip"

PY="${PYTHON:-python3}"  # permite exportar PYTHON=python3.12 se quiser

echo "📦 Empacotando Lambda a partir de: $ROOT_DIR"

# Limpeza
rm -rf "$BUILD_DIR" "$ZIP_PATH"
mkdir -p "$BUILD_DIR"

# Venv temporária só para instalar deps (evita PEP 668)
VENV_DIR="$ROOT_DIR/.venv_pkg"
rm -rf "$VENV_DIR"
$PY -m venv "$VENV_DIR"
source "$VENV_DIR/bin/activate"
python -m pip install --upgrade pip wheel

# Instala dependências diretamente em build/
python -m pip install -r "$APP_DIR/requirements.txt" -t "$BUILD_DIR"

# Copia o código da app (inclui api.py, etc)
cp -R "$APP_DIR/"* "$BUILD_DIR/"

deactivate
rm -rf "$VENV_DIR"

# Zipa (conteúdo da pasta build/ direto na raiz do zip)
( cd "$BUILD_DIR" && zip -qr "$ZIP_PATH" . )

# Opcional: remover build/ após zip
rm -rf "$BUILD_DIR"

echo "✅ Gerado: $ZIP_PATH"
unzip -l "$ZIP_PATH" | head -n 20
