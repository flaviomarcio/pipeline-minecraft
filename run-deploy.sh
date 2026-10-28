#!/usr/bin/env bash
# Build da imagem e deploy do servidor Minecraft no Docker Swarm
set -euo pipefail

cd "$(dirname "$0")"

echo ">> Verificando Docker Swarm..."
if [ "$(docker info --format '{{.Swarm.LocalNodeState}}')" != "active" ]; then
  echo "ERRO: Docker Swarm nao esta ativo. Rode: docker swarm init"
  exit 1
fi

# Configs do Swarm sao imutaveis: o nome leva o hash do arquivo,
# assim qualquer alteracao gera um config novo automaticamente
export SERVER_PROPERTIES_HASH=$(sha256sum config/server.properties | cut -c1-12)
export WHITELIST_HASH=$(sha256sum config/whitelist.json | cut -c1-12)

echo ">> Verificando arquivos..."
docker stack config -c docker-stack.yml > /dev/null
jq empty config/whitelist.json

echo ">> Verificando pastas /data/minecraft..."
mkdir -p /data/minecraft/data /data/minecraft/backup
if [ "$(stat -c '%u' /data/minecraft/data)" != "1000" ] || [ "$(stat -c '%u' /data/minecraft/backup)" != "1000" ]; then
  echo "ERRO: /data/minecraft/data e /data/minecraft/backup devem pertencer ao UID 1000"
  echo "Rode: sudo chown -R 1000:1000 /data/minecraft"
  exit 1
fi

echo ">> Verificando secret minecraft_rcon_password..."
if ! docker secret inspect minecraft_rcon_password > /dev/null 2>&1; then
  head -c 32 /dev/urandom | base64 | tr -d '\n' | docker secret create minecraft_rcon_password - > /dev/null
  echo "   secret criado (senha aleatoria, uso interno)"
fi

echo ">> Build da imagem minecraft-paper:1.21.11 (Dockerfile)..."
docker build -t minecraft-paper:1.21.11 -f Dockerfile .

echo ">> Fazendo deploy da stack minecraft..."
docker stack deploy -c docker-stack.yml --resolve-image never --detach=false minecraft

echo ">> Removendo configs antigos..."
for cfg in $(docker config ls --format '{{.Name}}' | grep -E '^minecraft_(server_properties|whitelist)_'); do
  if [ "$cfg" != "minecraft_server_properties_${SERVER_PROPERTIES_HASH}" ] && [ "$cfg" != "minecraft_whitelist_${WHITELIST_HASH}" ]; then
    docker config rm "$cfg" > /dev/null 2>&1 && echo "   removido: $cfg" || true
  fi
done

echo ">> Status:"
docker stack services minecraft

echo ""
echo "Logs:    docker service logs -f minecraft_server"
echo "Console: docker attach \$(docker ps -q -f name=minecraft_server)  (sair: Ctrl+P Ctrl+Q)"
