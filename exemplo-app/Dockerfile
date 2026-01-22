# Imagem de exemplo para testar o pipeline
FROM alpine:3.19

LABEL maintainer="tsgomesdev"
LABEL description="Imagem de exemplo para testar GitHub Actions com ARC"

# Instalar dependências básicas
RUN apk add --no-cache \
    curl \
    bash \
    jq

# Criar usuário não-root
RUN adduser -D -s /bin/bash appuser

# Diretório de trabalho
WORKDIR /app

# Copiar script de exemplo
COPY entrypoint.sh /app/
RUN chmod +x /app/entrypoint.sh

# Trocar para usuário não-root
USER appuser

# Healthcheck
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

# Porta exposta
EXPOSE 8080

# Entrypoint
ENTRYPOINT ["/app/entrypoint.sh"]
