#!/bin/bash

echo "🚀 Aplicação de exemplo iniciada!"
echo "📅 Data: $(date)"
echo "🖥️  Hostname: $(hostname)"

# Servidor HTTP simples para healthcheck
while true; do
    echo -e "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n\r\n{\"status\":\"healthy\",\"timestamp\":\"$(date -Iseconds)\"}" | nc -l -p 8080 -q 1
done
