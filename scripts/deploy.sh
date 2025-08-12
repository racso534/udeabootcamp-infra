#!/usr/bin/env bash
set -euo pipefail

check_aws_credentials() {
    echo "🔑 Verificando credenciales AWS..."
    
    if ! aws sts get-caller-identity &>/dev/null; then
        echo "❌ Credenciales AWS no configuradas o inválidas"
        
        # Intentar obtener credenciales del rol
        if aws sts get-session-token &>/dev/null; then
            echo "✅ Usando rol IAM existente"
            return 0
        fi
        
        # Solicitar credenciales si no hay rol
        echo "📝 Configurando credenciales AWS..."
        read -p "AWS Access Key ID: " aws_access_key
        read -p "AWS Secret Access Key: " aws_secret_key
        read -p "Default region [us-east-1]: " aws_region
        aws_region=${aws_region:-us-east-1}
        
        # Configurar credenciales
        aws configure set aws_access_key_id "$aws_access_key"
        aws configure set aws_secret_access_key "$aws_secret_key"
        aws configure set default.region "$aws_region"
        aws configure set output json
        
        # Verificar configuración
        if ! aws sts get-caller-identity &>/dev/null; then
            echo "❌ Error configurando credenciales AWS"
            exit 1
        fi
    fi
    
    echo "✅ Credenciales AWS verificadas"
}

# Validate input parameters
if [ "$#" -ne 3 ]; then
    echo "❌ Error: Missing required parameters"
    echo "Usage: $0 <template-file> <stack-name> <parameter-file>"
    echo "Example: $0 infra/cloudformation/pipeline.yml proyectofestivos-pipeline infra/parameters/params.json"
    exit 1
fi

# Verify AWS credentials first
check_aws_credentials

# Assign parameters to variables
TEMPLATE_FILE="$1"
STACK_NAME="$2"
PARAM_FILE="$3"

# Validate files exist
if [ ! -f "$TEMPLATE_FILE" ]; then
    echo "❌ Error: Template file not found: $TEMPLATE_FILE"
    exit 1
fi

if [ ! -f "$PARAM_FILE" ]; then
    echo "❌ Error: Parameter file not found: $PARAM_FILE"
    exit 1
fi

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

# Validate jq is installed
if ! command -v jq &> /dev/null; then
    echo "❌ Error: jq is required but not installed"
    echo "Please install jq first:"
    echo "For Windows (in PowerShell as admin): choco install jq"
    echo "For Linux: sudo apt-get install jq"
    exit 1
fi

# Get region from parameters file
AWS_REGION=$(jq -r '.[] | select(.ParameterKey=="AWSRegion") | .ParameterValue' "$PARAM_FILE")

if [ -z "$AWS_REGION" ]; then
    echo "❌ Error: Could not find AWSRegion in parameter file"
    exit 1
fi

# Check existing resources
if check_resource_exists "stack" "$STACK_NAME" "$AWS_REGION"; then
    echo "Stack ya existe, verificando otros recursos..."
    
    # Get ECR repository names
    ECR_REPO_BACKEND=$(jq -r '.[] | select(.ParameterKey=="ECRRepoBackend") | .ParameterValue' "$PARAM_FILE")
    ECR_REPO_FRONTEND=$(jq -r '.[] | select(.ParameterKey=="ECRRepoFrontend") | .ParameterValue' "$PARAM_FILE")
    
    # Check ECR repositories
    for repo in "$ECR_REPO_BACKEND" "$ECR_REPO_FRONTEND"; do
        if [ ! -z "$repo" ] && ! check_resource_exists "ecr" "$repo" "$AWS_REGION"; then
            echo "Creando repositorio ECR $repo..."
            aws ecr create-repository --repository-name "$repo" --region "$AWS_REGION"
        fi
    done
    
    # Check ECS cluster
    ECS_CLUSTER_NAME=$(jq -r '.[] | select(.ParameterKey=="ClusterName") | .ParameterValue' "$PARAM_FILE")
    if [ ! -z "$ECS_CLUSTER_NAME" ] && ! check_resource_exists "ecs-cluster" "$ECS_CLUSTER_NAME" "$AWS_REGION"; then
        echo "Creando cluster ECS $ECS_CLUSTER_NAME..."
        aws ecs create-cluster --cluster-name "$ECS_CLUSTER_NAME" --region "$AWS_REGION"
    fi

    # Add final summary
    echo ""
    echo "🎯 Resumen de la infraestructura existente:"
    echo "----------------------------------------"
    echo "✓ Stack CloudFormation: $STACK_NAME"
    echo "✓ Repositorios ECR:"
    echo "  • Backend: $ECR_REPO_BACKEND"
    echo "  • Frontend: $ECR_REPO_FRONTEND"
    echo "✓ Cluster ECS: $ECS_CLUSTER_NAME"
    echo ""
    echo "🎉 Todo listo! La infraestructura ya está desplegada y lista para usar."
    echo ""
    echo "Próximos pasos:"
    echo "  1. Verificar el pipeline en: https://console.aws.amazon.com/codesuite/codepipeline/pipelines"
    echo "  2. Hacer push a tu repo para iniciar un nuevo deployment"
    echo "  3. Monitorear el progreso en AWS Console"
    
    exit 0
fi

echo "🚀 Desplegando nuevo stack..."
aws cloudformation deploy \
    --template-file "$TEMPLATE_FILE" \
    --stack-name "$STACK_NAME" \
    --parameter-overrides file://"$PARAM_FILE" \
    --capabilities CAPABILITY_NAMED_IAM CAPABILITY_AUTO_EXPAND \
    --region "$AWS_REGION"

echo "✅ Despliegue completado exitosamente"

# Show stack outputs
echo "📋 Outputs del stack:"
aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --query 'Stacks[0].Outputs' \
    --output table \
    --region "$AWS_REGION"

echo "🎉 Pipeline listo y configurado! Ahora puedes:"
echo "  1. Verificar el pipeline en la consola de AWS CodePipeline"
echo "  2. Hacer push a tu repo para iniciar el primer deployment"
echo "  3. Monitorear el progreso en AWS Console"