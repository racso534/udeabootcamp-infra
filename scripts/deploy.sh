#!/bin/bash
set -e

PARAMS_FILE="params.json"

echo "=== Validando credenciales AWS ==="
aws sts get-caller-identity --output text > /dev/null || { echo "❌ Credenciales inválidas"; exit 1; }

echo "=== Leyendo parámetros desde $PARAMS_FILE ==="
AWS_REGION=$(jq -r '.[] | select(.ParameterKey=="AWSRegion") | .ParameterValue' $PARAMS_FILE)

function deploy_stack() {
  local template=$1
  local stack=$2
  echo "=== Desplegando $stack ==="
  aws cloudformation deploy \
    --template-file $template \
    --stack-name $stack \
    --parameter-overrides file://$PARAMS_FILE \
    --capabilities CAPABILITY_NAMED_IAM \
    --region $AWS_REGION
}

deploy_stack templates/iam.yml "${STACK_PREFIX:-proyectofestivos}-iam"
deploy_stack templates/vpc.yml "${STACK_PREFIX:-proyectofestivos}-vpc"
deploy_stack templates/infra-app.yml "${STACK_PREFIX:-proyectofestivos}-infra"
deploy_stack templates/pipeline.yml "${STACK_PREFIX:-proyectofestivos}-pipeline"

echo "✅ Despliegue completo"
