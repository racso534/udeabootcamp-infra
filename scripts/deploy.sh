#!/bin/bash
set -e

STACK_NAME=$1
TEMPLATE_FILE=$2
REGION="us-east-2"  # Ajusta según tu necesidad

if [ -z "$STACK_NAME" ] || [ -z "$TEMPLATE_FILE" ]; then
    echo "Uso: ./deploy.sh <stack-name> <template-file>"
    exit 1
fi

aws cloudformation deploy \
  --stack-name "$STACK_NAME" \
  --template-file "$TEMPLATE_FILE" \
  --capabilities CAPABILITY_NAMED_IAM \
  --region "$REGION"