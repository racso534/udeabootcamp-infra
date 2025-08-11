#!/usr/bin/env bash
set -euo pipefail

check_resource_exists() {
    local resource_type="$1"
    local resource_name="$2"
    local region="$3"

    case "$resource_type" in
        "stack")
            if aws cloudformation describe-stacks --stack-name "$resource_name" --region "$region" >/dev/null 2>&1; then
                echo "✓ Stack $resource_name ya existe, saltando..."
                return 0
            fi
            ;;
        "ecr")
            if aws ecr describe-repositories --repository-names "$resource_name" --region "$region" >/dev/null 2>&1; then
                echo "✓ ECR Repository $resource_name ya existe, saltando..."
                return 0
            fi
            ;;
        "ecs-cluster")
            if aws ecs describe-clusters --clusters "$resource_name" --region "$region" --query 'clusters[0]' >/dev/null 2>&1; then
                echo "✓ ECS Cluster $resource_name ya existe, saltando..."
                return 0
            fi
            ;;
    esac
    return 1
}

# Obtener región del archivo de parámetros
AWS_REGION=$(jq -r '.[] | select(.ParameterKey=="AWSRegion") | .ParameterValue' "$PARAM_FILE")

# Verificar recursos existentes
if check_resource_exists "stack" "$STACK_NAME" "$AWS_REGION"; then
    echo "Stack ya existe, verificando otros recursos..."
    
    # Obtener nombres de repositorios ECR
    ECR_REPO_BACKEND=$(jq -r '.[] | select(.ParameterKey=="ECRRepoBackend") | .ParameterValue' "$PARAM_FILE")
    ECR_REPO_FRONTEND=$(jq -r '.[] | select(.ParameterKey=="ECRRepoFrontend") | .ParameterValue' "$PARAM_FILE")
    
    # Verificar repositorios ECR
    for repo in "$ECR_REPO_BACKEND" "$ECR_REPO_FRONTEND"; do
        if [ ! -z "$repo" ] && ! check_resource_exists "ecr" "$repo" "$AWS_REGION"; then
            echo "Creando repositorio ECR $repo..."
            aws ecr create-repository --repository-name "$repo" --region "$AWS_REGION"
        fi
    done
    
    # Verificar cluster ECS
    ECS_CLUSTER_NAME=$(jq -r '.[] | select(.ParameterKey=="ClusterName") | .ParameterValue' "$PARAM_FILE")
    if [ ! -z "$ECS_CLUSTER_NAME" ] && ! check_resource_exists "ecs-cluster" "$ECS_CLUSTER_NAME" "$AWS_REGION"; then
        echo "Creando cluster ECS $ECS_CLUSTER_NAME..."
        aws ecs create-cluster --cluster-name "$ECS_CLUSTER_NAME" --region "$AWS_REGION"
    fi
    
    exit 0
fi

echo "🚀 Desplegando nuevo stack..."
aws cloudformation deploy \
    --template-file "$TEMPLATE_FILE" \
    --stack-name "$STACK_NAME" \
    --parameter-overrides file://"$PARAM_FILE" \
    --capabilities CAPABILITY_NAMED_IAM CAPABILITY_AUTO_EXPAND \
    --region "$AWS_REGION"