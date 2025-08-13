#!/bin/bash
set -e

PARAMS_FILE="parameters/params.json"

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

deploy_stack infra/cloudformation/iam.yml "${STACK_PREFIX:-proyectofestivos}-iam"
deploy_stack infra/cloudformation/vpc.yml "${STACK_PREFIX:-proyectofestivos}-vpc"
#deploy_stack infra/cloudformation/infra-ecr.yml "${STACK_PREFIX:-proyectofestivos}-ecr"
deploy_stack infra/cloudformation/infra-app.yml "${STACK_PREFIX:-proyectofestivos}-infra"
deploy_stack infra/cloudformation/pipeline.yml "${STACK_PREFIX:-proyectofestivos}-pipeline"

echo "✅ Despliegue completo"
