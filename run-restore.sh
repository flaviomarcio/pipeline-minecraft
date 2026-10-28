#!/usr/bin/env bash
# Restaura um backup do servidor Minecraft
# Uso: ./run-restore.sh                 (lista backups)
#      ./run-restore.sh <arquivo.tar.gz>
set -euo pipefail

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

if [ $# -eq 0 ]; then
  echo "Backups disponiveis:"
  ls -1th /data/minecraft/backup/minecraft-*.tar.gz 2>/dev/null || echo "  (nenhum)"
  echo ""
  echo "Uso: $(basename "$0") <arquivo.tar.gz>"
  exit 0
fi

BACKUP=$(realpath "$1")
if [ ! -f "$BACKUP" ]; then
  log "ERRO: arquivo nao encontrado: $1"
  exit 1
fi

log "Verificando integridade de $BACKUP"
tar -tzf "$BACKUP" > /dev/null

echo ""
echo "ATENCAO: o servidor sera parado e o mundo atual substituido por:"
echo "  $BACKUP"
echo "O estado atual sera mantido em /data/minecraft/data.pre-restore-<data>"
read -r -p "Digite SIM para continuar: " CONFIRMA
if [ "$CONFIRMA" != "SIM" ]; then
  log "Cancelado"
  exit 1
fi

SERVICO_EXISTE=false
if docker service inspect minecraft_server > /dev/null 2>&1; then
  SERVICO_EXISTE=true
  log "Parando servico minecraft_server (salva o mundo antes de parar)"
  docker service scale minecraft_server=0 --detach=false
  while [ -n "$(docker ps -q -f name=minecraft_server)" ]; do sleep 2; done
fi

PRE_RESTORE="/data/minecraft/data.pre-restore-$(date +%Y%m%d-%H%M%S)"
log "Movendo estado atual para $PRE_RESTORE"
mv /data/minecraft/data "$PRE_RESTORE"

log "Extraindo backup"
tar -C /data/minecraft -xzf "$BACKUP"

if [ "$SERVICO_EXISTE" = true ]; then
  log "Subindo servico minecraft_server"
  docker service scale minecraft_server=1 --detach=false
fi

log "Restore concluido"
echo "Depois de validar o jogo, apague o estado anterior:"
echo "  rm -rf $PRE_RESTORE"
