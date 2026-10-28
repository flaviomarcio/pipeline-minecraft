#!/usr/bin/env bash
# Backup do servidor Minecraft (1x por dia via cron, retencao de 2 dias)
# Cron (04:00): 0 4 * * * /caminho/run-backup.sh >> /data/minecraft/backup/backup.log 2>&1
set -euo pipefail

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

if [ ! -d /data/minecraft/data ] || [ ! -d /data/minecraft/backup ]; then
  log "ERRO: /data/minecraft/data ou /data/minecraft/backup nao existe"
  exit 1
fi

# Impede duas execucoes simultaneas
exec 9> /data/minecraft/backup/.backup.lock
if ! flock -n 9; then
  log "ERRO: outro backup em execucao"
  exit 1
fi

ARQUIVO="/data/minecraft/backup/minecraft-$(date +%Y%m%d-%H%M%S).tar.gz"
CID=$(docker ps -q -f name=minecraft_server -f status=running | head -n1)

# Servidor rodando: pausa gravacoes e forca salvar o mundo em disco
if [ -n "$CID" ]; then
  log "Servidor ativo: save-off + save-all flush"
  docker exec "$CID" rcon "say Backup iniciado, pode haver lentidao" > /dev/null || true
  docker exec "$CID" rcon save-off > /dev/null
  # Garante que as gravacoes voltem mesmo se o backup falhar
  trap 'docker exec "$CID" rcon save-on > /dev/null 2>&1 || true; rm -f "$ARQUIVO.partial"' EXIT
  docker exec "$CID" rcon save-all flush > /dev/null
else
  log "Servidor parado: backup a frio"
  trap 'rm -f "$ARQUIVO.partial"' EXIT
fi

log "Compactando /data/minecraft/data -> $ARQUIVO"
tar -C /data/minecraft -czf "$ARQUIVO.partial" --exclude='data/logs' data

if [ -n "$CID" ]; then
  docker exec "$CID" rcon save-on > /dev/null
  docker exec "$CID" rcon "say Backup concluido" > /dev/null || true
  log "save-on"
fi

log "Verificando integridade"
tar -tzf "$ARQUIVO.partial" > /dev/null
mv "$ARQUIVO.partial" "$ARQUIVO"
log "OK: $ARQUIVO ($(du -h "$ARQUIVO" | cut -f1))"

# Retencao: mantem os 2 backups mais recentes (1 por dia = 2 dias)
ls -1t /data/minecraft/backup/minecraft-*.tar.gz | tail -n +3 | while read -r antigo; do
  rm -f "$antigo"
  log "Removido (retencao): $antigo"
done
