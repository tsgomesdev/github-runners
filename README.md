# 🚀 GitHub Actions Runner Controller (ARC) - Guia Completo

Este documento descreve a migração dos **GitHub Self-Hosted Runners** do Docker Swarm para o Kubernetes utilizando o **GitHub Actions Runner Controller (ARC)**.

---

## 📋 Índice

1. [O que é isso?](#-o-que-é-isso)
2. [Por que migrar?](#-por-que-migrar)
3. [Arquitetura](#-arquitetura)
4. [Pré-requisitos](#-pré-requisitos)
5. [Estrutura de Arquivos](#-estrutura-de-arquivos)
6. [Instalação Passo a Passo](#-instalação-passo-a-passo)
7. [Como Usar nos Workflows](#-como-usar-nos-workflows)
8. [Gerenciamento e Operações](#-gerenciamento-e-operações)
9. [Troubleshooting](#-troubleshooting)
10. [Referências](#-referências)

---

## 🤔 O que é isso?

### GitHub Actions
O **GitHub Actions** é uma ferramenta de automação que permite executar tarefas automaticamente quando algo acontece no seu repositório (como um push de código). Essas tarefas são chamadas de **workflows**.

### Runners
Os **runners** são os "computadores" que executam essas tarefas. Existem dois tipos:
- **GitHub-hosted runners**: Fornecidos pelo GitHub (gratuitos com limite)
- **Self-hosted runners**: Você gerencia seus próprios servidores

### GitHub ARC (Actions Runner Controller)
O **ARC** é uma ferramenta oficial do GitHub que permite rodar runners dentro do Kubernetes de forma automática e escalável. Ele cria runners sob demanda quando há jobs para executar e os remove quando terminam.

---

## 🎯 Por que migrar?

| Aspecto | Docker Swarm (Antes) | Kubernetes + ARC (Depois) |
|---------|---------------------|---------------------------|
| **Escalabilidade** | Manual (replicas fixas) | Automática (0 a N runners) |
| **Custo** | Runner sempre ligado | Runner só existe quando necessário |
| **Manutenção** | Scripts personalizados | Gerenciado pelo ARC |
| **Segurança** | Runner persistente | Runner efêmero (descartável) |
| **Integração** | Básica | Nativa com GitHub |

---

## 🏗 Arquitetura

### Antes (Docker Swarm)
```
┌─────────────────────────────────────────────────────┐
│                   Docker Swarm                       │
│  ┌─────────────────────────────────────────────┐    │
│  │         github_docker_runner                 │    │
│  │  ┌─────────────────────────────────────┐    │    │
│  │  │   Container do Runner               │    │    │
│  │  │   - Sempre ligado                   │    │    │
│  │  │   - Conecta ao Docker do host       │    │    │
│  │  │   - Registra na organização GitHub  │    │    │
│  │  └─────────────────────────────────────┘    │    │
│  └─────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────┘
```

### Depois (Kubernetes + ARC)
```
┌──────────────────────────────────────────────────────────────────┐
│                         Kubernetes Cluster                        │
│                                                                    │
│  ┌─────────────────────────────────────┐                          │
│  │   Namespace: arc-systems            │                          │
│  │  ┌─────────────────────────────┐   │                          │
│  │  │  ARC Controller             │   │  ← Gerencia os runners   │
│  │  │  (sempre rodando)           │   │                          │
│  │  └─────────────────────────────┘   │                          │
│  │  ┌─────────────────────────────┐   │                          │
│  │  │  Listener                   │   │  ← Escuta jobs do GitHub │
│  │  │  (sempre rodando)           │   │                          │
│  │  └─────────────────────────────┘   │                          │
│  └─────────────────────────────────────┘                          │
│                                                                    │
│  ┌─────────────────────────────────────┐                          │
│  │   Namespace: arc-runners            │                          │
│  │                                     │                          │
│  │   Quando há um job no GitHub:       │                          │
│  │  ┌─────────────────────────────┐   │                          │
│  │  │  Pod do Runner (efêmero)    │   │                          │
│  │  │  ┌────────┐ ┌────────────┐ │   │                          │
│  │  │  │ Runner │ │ DinD       │ │   │                          │
│  │  │  │        │ │ (Docker)   │ │   │                          │
│  │  │  └────────┘ └────────────┘ │   │                          │
│  │  └─────────────────────────────┘   │                          │
│  │                                     │                          │
│  │   Quando não há jobs: (vazio)       │                          │
│  └─────────────────────────────────────┘                          │
└──────────────────────────────────────────────────────────────────┘
```

---

## ✅ Pré-requisitos

Antes de começar, você precisa ter:

1. **Cluster Kubernetes** funcionando
2. **kubectl** configurado e conectado ao cluster
3. **Helm** instalado (gerenciador de pacotes do Kubernetes)
4. **Token do GitHub** com permissões:
   - `admin:org` (para organização)
   - ou `repo` (para repositório individual)
5. **Registro de imagens Docker** (ex: Docker Hub, Harbor, etc.)

### Verificando os pré-requisitos

```bash
# Verificar kubectl
kubectl version --client

# Verificar conexão com o cluster
kubectl cluster-info

# Verificar Helm
helm version
```

---

## 📁 Estrutura de Arquivos

```
github-arc/
├── README.md                    # Esta documentação
├── docker-stack.yaml           # (Antigo) Configuração do Docker Swarm
├── github-arc.yaml             # Manifesto do AutoscalingRunnerSet
├── github-arc-secret.yaml      # Template do Secret com credenciais
├── deploy.sh                   # Script automatizado de deploy
└── github-runners/
    ├── Dockerfile              # Imagem personalizada do runner
    └── start.sh                # Script de inicialização do runner
```

---

## 📝 Instalação Passo a Passo

### Passo 1: Criar o Token do GitHub

1. Acesse https://github.com/settings/tokens
2. Clique em **"Generate new token (classic)"**
3. Dê um nome descritivo (ex: "ARC Kubernetes")
4. Selecione as permissões:
   - ✅ `repo` (acesso completo aos repositórios)
   - ✅ `admin:org` (se for usar em uma organização)
5. Clique em **"Generate token"**
6. **COPIE O TOKEN** (ele só aparece uma vez!)

### Passo 2: Construir a Imagem do Runner

```bash
# Entrar na pasta do Dockerfile
cd github-runners

# Construir a imagem
docker build -t SEU_REGISTRO/github-runner:latest .

# Enviar para o registro
docker push SEU_REGISTRO/github-runner:latest
```

**Exemplo:**
```bash
docker build -t registry.tasso.dev.br/github-runner:latest .
docker push registry.tasso.dev.br/github-runner:latest
```

### Passo 3: Instalar o ARC Controller

O controller é o "cérebro" que gerencia os runners.

```bash
# Criar o namespace para o controller
kubectl create namespace arc-systems

# Instalar o controller via Helm
helm install arc \
    --namespace arc-systems \
    oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set-controller \
    --wait
```

**Verificar se está funcionando:**
```bash
kubectl get pods -n arc-systems
```

Você deve ver algo como:
```
NAME                                    READY   STATUS    RESTARTS   AGE
arc-gha-rs-controller-fd9657656-xxxxx   1/1     Running   0          1m
```

### Passo 4: Criar o Secret com as Credenciais

O secret armazena informações sensíveis (como o token do GitHub).

```bash
# Criar o namespace para os runners
kubectl create namespace arc-runners

# Criar o secret
kubectl create secret generic github-arc-secret \
    --namespace arc-runners \
    --from-literal=github_token="SEU_TOKEN_AQUI"
```

**Exemplo:**
```bash
kubectl create secret generic github-arc-secret \
    --namespace arc-runners \
    --from-literal=github_token="ghp_xxxxxxxxxxxxxxxxxxxx"
```

### Passo 5: Instalar o Runner Scale Set

Este é o recurso que define como os runners serão criados.

```bash
helm install github-runner-set \
    --namespace arc-runners \
    --set githubConfigUrl="https://github.com/SUA_ORGANIZACAO" \
    --set githubConfigSecret=github-arc-secret \
    --set minRunners=0 \
    --set maxRunners=10 \
    oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set
```

**Exemplo:**
```bash
helm install github-runner-set \
    --namespace arc-runners \
    --set githubConfigUrl="https://github.com/tsgomesdev" \
    --set githubConfigSecret=github-arc-secret \
    --set minRunners=0 \
    --set maxRunners=10 \
    oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set
```

**Parâmetros explicados:**
| Parâmetro | Descrição |
|-----------|-----------|
| `githubConfigUrl` | URL da sua organização ou repositório no GitHub |
| `githubConfigSecret` | Nome do secret criado no passo anterior |
| `minRunners` | Número mínimo de runners sempre ativos (0 = econômico) |
| `maxRunners` | Número máximo de runners simultâneos |

### Passo 6: Verificar a Instalação

```bash
# Ver o AutoscalingRunnerSet
kubectl get autoscalingrunnersets -n arc-runners

# Ver o listener (deve estar Running)
kubectl get pods -n arc-systems

# Ver logs do listener
kubectl logs -n arc-systems -l app.kubernetes.io/name=github-runner-set-listener
```

---

## 💻 Como Usar nos Workflows

Para usar os runners do ARC nos seus workflows do GitHub Actions, basta especificar o nome do runner set em `runs-on`:

### Exemplo Básico

```yaml
# .github/workflows/exemplo.yml
name: Meu Workflow

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  build:
    # IMPORTANTE: Use o nome do seu runner set aqui
    runs-on: github-runner-set
    
    steps:
      - name: Checkout do código
        uses: actions/checkout@v4
      
      - name: Executar testes
        run: |
          echo "Rodando no ARC!"
          java -version
          mvn --version
          docker --version
```

### Exemplo com Build Docker

```yaml
name: Build e Push Docker

on:
  push:
    branches: [main]

jobs:
  build:
    runs-on: github-runner-set
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Login no Registry
        run: docker login -u ${{ secrets.DOCKER_USER }} -p ${{ secrets.DOCKER_PASS }}
      
      - name: Build da imagem
        run: docker build -t minha-app:${{ github.sha }} .
      
      - name: Push da imagem
        run: docker push minha-app:${{ github.sha }}
```

### Exemplo com Maven

```yaml
name: Build Java com Maven

on: [push]

jobs:
  build:
    runs-on: github-runner-set
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Build com Maven
        run: mvn clean package -DskipTests
      
      - name: Executar testes
        run: mvn test
```

---

## 🔧 Gerenciamento e Operações

### Comandos Úteis do Dia a Dia

```bash
# ═══════════════════════════════════════════════════════════════
# VERIFICAR STATUS
# ═══════════════════════════════════════════════════════════════

# Ver status dos runner sets
kubectl get autoscalingrunnersets -n arc-runners

# Ver runners ativos (só aparecem quando há jobs)
kubectl get pods -n arc-runners

# Ver todos os componentes do ARC
kubectl get pods -n arc-systems

# ═══════════════════════════════════════════════════════════════
# VER LOGS
# ═══════════════════════════════════════════════════════════════

# Logs do controller
kubectl logs -n arc-systems -l app.kubernetes.io/name=gha-rs-controller

# Logs do listener
kubectl logs -n arc-systems -l app.kubernetes.io/component=runner-scale-set-listener

# Logs de um runner específico (quando estiver rodando)
kubectl logs -n arc-runners <NOME_DO_POD>

# ═══════════════════════════════════════════════════════════════
# ESCALAR RUNNERS
# ═══════════════════════════════════════════════════════════════

# Alterar número mínimo/máximo de runners
helm upgrade github-runner-set \
    --namespace arc-runners \
    --set minRunners=1 \
    --set maxRunners=20 \
    --reuse-values \
    oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set

# ═══════════════════════════════════════════════════════════════
# ATUALIZAR CONFIGURAÇÕES
# ═══════════════════════════════════════════════════════════════

# Atualizar o token do GitHub
kubectl delete secret github-arc-secret -n arc-runners
kubectl create secret generic github-arc-secret \
    --namespace arc-runners \
    --from-literal=github_token="NOVO_TOKEN"

# Reiniciar o listener para aplicar novo token
kubectl rollout restart deployment -n arc-systems -l app.kubernetes.io/component=runner-scale-set-listener

# ═══════════════════════════════════════════════════════════════
# REMOVER TUDO
# ═══════════════════════════════════════════════════════════════

# Remover o runner set
helm uninstall github-runner-set -n arc-runners

# Remover o controller
helm uninstall arc -n arc-systems

# Remover os namespaces
kubectl delete namespace arc-runners
kubectl delete namespace arc-systems
```

### Monitorar em Tempo Real

```bash
# Acompanhar pods sendo criados/destruídos
watch kubectl get pods -n arc-runners

# Ou com kubectl diretamente
kubectl get pods -n arc-runners -w
```

---

## 🔍 Troubleshooting

### Problema: Nenhum runner aparece quando executo um workflow

**Possíveis causas e soluções:**

1. **Verificar se o listener está rodando:**
   ```bash
   kubectl get pods -n arc-systems
   ```
   O listener deve estar com status `Running`.

2. **Verificar logs do listener:**
   ```bash
   kubectl logs -n arc-systems -l app.kubernetes.io/component=runner-scale-set-listener
   ```
   Procure por erros de autenticação ou conexão.

3. **Verificar se o nome do runner está correto no workflow:**
   ```yaml
   runs-on: github-runner-set  # Deve ser exatamente este nome
   ```

4. **Verificar se o token tem as permissões corretas:**
   - O token precisa ter `admin:org` para organizações
   - Ou `repo` para repositórios individuais

### Problema: Erro de autenticação no GitHub

```bash
# Verificar logs do listener
kubectl logs -n arc-systems -l app.kubernetes.io/component=runner-scale-set-listener

# Se aparecer erro 401 ou 403, o token está inválido ou sem permissão
# Solução: Criar novo token e atualizar o secret
kubectl delete secret github-arc-secret -n arc-runners
kubectl create secret generic github-arc-secret \
    --namespace arc-runners \
    --from-literal=github_token="NOVO_TOKEN"
```

### Problema: Pod do runner fica em estado "Pending"

```bash
# Ver detalhes do pod
kubectl describe pod <NOME_DO_POD> -n arc-runners

# Causas comuns:
# - Recursos insuficientes no cluster
# - Imagem não encontrada
# - Node selector não satisfeito
```

### Problema: Erro ao fazer docker build dentro do runner

Verifique se o DinD (Docker in Docker) está configurado:

```bash
# Ver se o pod tem o container dind
kubectl get pod <NOME_DO_POD> -n arc-runners -o jsonpath='{.spec.containers[*].name}'
```

Se não estiver usando DinD, você precisa configurar o runner set com o sidecar do Docker.

### Problema: Runner demora para iniciar

Isso é normal na primeira execução porque o Kubernetes precisa baixar a imagem. Para melhorar:

1. **Usar um registro local** (mais rápido)
2. **Configurar `minRunners=1`** (sempre ter um runner pronto)
3. **Usar cache de imagens** no cluster

---

## 🔄 Comparativo: Antes vs Depois

### Configuração Antiga (Docker Swarm)

```yaml
# docker-stack.yaml
version: '3.3'
services:
  github_docker_runner:
    image: ${IMAGE_RUNNER}
    environment:
      - ORGANIZATION=${ORGANIZATION}
      - ACCESS_TOKEN=${ACCESS_TOKEN}
    deploy:
      replicas: 1
```

**Problemas:**
- Runner sempre ligado (mesmo sem jobs)
- Escala manual
- Script personalizado para registro/remoção

### Configuração Nova (Kubernetes + ARC)

```bash
# Instalação via Helm
helm install github-runner-set \
    --set githubConfigUrl="https://github.com/ORG" \
    --set githubConfigSecret=github-arc-secret \
    --set minRunners=0 \
    --set maxRunners=10 \
    oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set
```

**Vantagens:**
- Runners criados sob demanda
- Escala automática
- Gerenciado pelo GitHub ARC
- Runners efêmeros (mais seguros)

---

## 📚 Referências

- [GitHub ARC - Documentação Oficial](https://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners-with-actions-runner-controller)
- [ARC - GitHub Repository](https://github.com/actions/actions-runner-controller)
- [Helm Charts do ARC](https://github.com/actions/actions-runner-controller/tree/master/charts)

---

## 📞 Suporte

Se você encontrar problemas não listados aqui:

1. Verifique os logs dos componentes
2. Consulte a documentação oficial do GitHub ARC
3. Abra uma issue no repositório do projeto

---

*Documentação criada em Janeiro/2026*
*Migração: Docker Swarm → Kubernetes (GitHub ARC)*
