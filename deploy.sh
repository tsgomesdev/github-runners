#!/bin/bash

# Script para deploy do GitHub ARC Runner Set
# Migração de Docker Swarm para Kubernetes

set -e

# Verificar se as variáveis de ambiente estão definidas
if [ -z "$ORGANIZATION" ]; then
    echo "Erro: Variável ORGANIZATION não definida"
    echo "Uso: export ORGANIZATION=sua-organizacao"
    exit 1
fi

if [ -z "$ACCESS_TOKEN" ]; then
    echo "Erro: Variável ACCESS_TOKEN não definida"
    echo "Uso: export ACCESS_TOKEN=seu-token"
    exit 1
fi

if [ -z "$IMAGE_RUNNER" ]; then
    echo "Erro: Variável IMAGE_RUNNER não definida"
    echo "Uso: export IMAGE_RUNNER=sua-imagem:tag"
    exit 1
fi

NAMESPACE="arc-runners"

echo "==> Criando namespace ${NAMESPACE} (se não existir)..."
kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -

echo "==> Criando/Atualizando Secret com ACCESS_TOKEN..."
kubectl create secret generic github-arc-secret \
    --namespace=${NAMESPACE} \
    --from-literal=github_token="${ACCESS_TOKEN}" \
    --from-literal=organization="${ORGANIZATION}" \
    --dry-run=client -o yaml | kubectl apply -f -

echo "==> Substituindo variáveis no manifesto..."
sed -e "s|\${ORGANIZATION}|${ORGANIZATION}|g" \
    -e "s|\${IMAGE_RUNNER}|${IMAGE_RUNNER}|g" \
    github-arc.yaml > /tmp/github-arc-rendered.yaml

echo "==> Aplicando AutoscalingRunnerSet..."
kubectl apply -f /tmp/github-arc-rendered.yaml

echo "==> Verificando status do deployment..."
kubectl get autoscalingrunnersets -n ${NAMESPACE}

echo ""
echo "Deploy concluído com sucesso!"
echo ""
echo "Comandos úteis:"
echo "  kubectl get pods -n ${NAMESPACE} -w    # Monitorar pods"
echo "  kubectl logs -n ${NAMESPACE} -l app.kubernetes.io/component=runner -f  # Ver logs"
