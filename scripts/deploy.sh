#!/usr/bin/env bash
set -euo pipefail

# Uso:
# ./scripts/deploy.sh templates/vpc.yml proyectofestivos-network
# ./scripts/deploy.sh templates/infra-app.yml proyectofestivos-infra-app

# Script actualizado para despliegues 100% desde AWS CloudShell.
# - Lee automáticamente parámetros desde params.json (sin hardcodear valores).
# - Compatible con cualquier plantilla CloudFormation (VPC, ECS, Pipeline, etc.).
# - Evita modificar el script al cambiar parámetros; todo se gestiona en params.json.
# - Incluye validaciones y soporte para CAPABILITY_NAMED_IAM.

TEMPLATE_FILE="$1"
STACK_NAME="$2"
PARAM_FILE="${3:-infra/parameters/params.json}"
AWS_REGION="${AWS_REGION:-us-east-1}"

if [ -z "$TEMPLATE_FILE" ] || [ -z "$STACK_NAME" ]; then
  echo "Uso: $0 <template-file> <stack-name> [params.json]"
  exit 1
fi

if [ ! -f "$TEMPLATE_FILE" ]; then
  echo "Template file $TEMPLATE_FILE no existe"
  exit 2
fi

if [ ! -f "$PARAM_FILE" ]; then
  echo "Params file $PARAM_FILE no existe"
  exit 3
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "jq no está instalado. Instalando en CloudShell..."
  sudo yum -y install jq || sudo apt-get update && sudo apt-get install -y jq || true
fi

# build --parameter-overrides string from params.json
PARAM_OVERRIDES=""
for key in $(jq -r 'keys[]' "$PARAM_FILE"); do
  value=$(jq -r --arg k "$key" '.[$k]' "$PARAM_FILE")
  # Skip empty values
  if [ "$value" = "null" ] || [ -z "$value" ]; then
    continue
  fi
  # If value is a string that contains spaces or special chars, wrap in quotes
  PARAM_OVERRIDES="$PARAM_OVERRIDES $key=\"$value\""
done

echo "Deploying $TEMPLATE_FILE as $STACK_NAME to region $AWS_REGION"
echo "Parameter overrides: $PARAM_OVERRIDES"

aws cloudformation deploy \
  --template-file "$TEMPLATE_FILE" \
  --stack-name "$STACK_NAME" \
  --capabilities CAPABILITY_NAMED_IAM CAPABILITY_AUTO_EXPAND \
  --parameter-overrides $PARAM_OVERRIDES \
  --region "$AWS_REGION"
