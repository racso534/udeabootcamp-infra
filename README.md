Comandos para ejecutar cloudformation manualmente desde local

1. aws cloudformation deploy --stack-name udeabootcamp-stack-vpc --template-file templates/vpc.yml --capabilities CAPABILITY_NAMED_IAM --region us-east-2
2. aws cloudformation deploy --stack-name udeabootcamp-stack-security --template-file templates/infra-app.yml --capabilities CAPABILITY_NAMED_IAM --region us-east-2
