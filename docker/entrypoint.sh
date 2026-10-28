#!/usr/bin/env bash
set -euo pipefail

if [ "${EULA:-}" != "TRUE" ]; then
  echo "ERRO: aceite a EULA da Mojang (https://aka.ms/MinecraftEULA) com EULA=TRUE"
  exit 1
fi
echo "eula=true" > /data/eula.txt

# server.properties e whitelist vem dos configs do Swarm (sobrescritos a cada start)
cp /config/server.properties /data/server.properties
cp /config/whitelist.json /data/whitelist.json

# Senha RCON vem do secret do Swarm (porta 25575 nao publicada)
if [ ! -s /run/secrets/minecraft_rcon_password ]; then
  echo "ERRO: secret minecraft_rcon_password ausente"
  exit 1
fi
echo "rcon.password=$(cat /run/secrets/minecraft_rcon_password)" >> /data/server.properties

# Plugins da imagem (remove versoes antigas do AuthMe)
mkdir -p /data/plugins
rm -f /data/plugins/AuthMe-*.jar
cp /opt/minecraft/plugins/*.jar /data/plugins/

# exec: java recebe o SIGTERM do Swarm e salva o mundo antes de parar
exec java \
  -Xms"${MEMORY:-4G}" -Xmx"${MEMORY:-4G}" \
  -XX:+UseG1GC -XX:+ParallelRefProcEnabled -XX:MaxGCPauseMillis=200 \
  -XX:+UnlockExperimentalVMOptions -XX:+DisableExplicitGC -XX:+AlwaysPreTouch \
  -Duser.timezone=America/Sao_Paulo \
  -jar /opt/minecraft/paper.jar --nogui
