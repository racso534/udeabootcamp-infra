#!/bin/bash
set -e

PARAMS_FILE="parameters/params.json"

echo "=== Validando credenciales AWS ==="
aws sts get-caller-identity --output text > /dev/null || { echo "❌ Credenciales inválidas"; exit 1; }

echo "=== Leyendo parámetros desde $PARAMS_FILE ==="
AWS_REGION=$(jq -r '.[] | select(.ParameterKey=="AWSRegion") | .ParameterValue' $PARAMS_FILE)
ACCOUNT_ID=$(jq -r '.[] | select(.ParameterKey=="AWSAccount") | .ParameterValue' $PARAMS_FILE)
REPO_NAME=$(jq -r '.[] | select(.ParameterKey=="ECRRepoBackend") | .ParameterValue' $PARAMS_FILE)
TAG=$(jq -r '.[] | select(.ParameterKey=="TagImage") | .ParameterValue' $PARAMS_FILE)

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

function push_init_image() {
	
	echo "=== Construyendo Image Docker ==="
	echo "=== REPO_NAME $REPO_NAME ==="
	echo "=== TAG $TAG ==="
	echo "La ubicación actual es: $(pwd)"
	
	aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

	# Construir la imagen
	docker build -t $REPO_NAME:$TAG .

	# Etiquetar para ECR
	docker tag $REPO_NAME:$TAG $ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$REPO_NAME:$TAG

	# Subir a ECR
	docker push $ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$REPO_NAME:$TAG
	
	echo "=== Completada Image Docker ==="
}

deploy_stack infra/cloudformation/iam.yml "${STACK_PREFIX:-proyectofestivos}-iam"
deploy_stack infra/cloudformation/vpc.yml "${STACK_PREFIX:-proyectofestivos}-vpc"
deploy_stack infra/cloudformation/infra-ecr.yml "${STACK_PREFIX:-proyectofestivos}-ecr"

#push_init_image

#deploy_stack infra/cloudformation/infra-app.yml "${STACK_PREFIX:-proyectofestivos}-infra"
deploy_stack infra/cloudformation/pipeline.yml "${STACK_PREFIX:-proyectofestivos}-pipeline"

echo "✅ Despliegue completo"
