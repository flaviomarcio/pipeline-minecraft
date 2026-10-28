#!/usr/bin/env bash
# Gerencia os jogadores da whitelist (config/whitelist.json)
set -euo pipefail

cd "$(dirname "$0")"

usage() {
  cat <<EOF
Uso: $(basename "$0") <comando> [nick]

Comandos:
  listar          Lista os jogadores da whitelist
  criar <nick>    Adiciona jogador (gera UUID offline)
  deletar <nick>  Remove jogador

Apos criar/deletar, aplique com: ./run-deploy.sh
EOF
  exit 1
}

# UUID offline do Minecraft: UUID v3 de "OfflinePlayer:<nick>"
offline_uuid() {
  local hex b6 b8
  hex=$(printf 'OfflinePlayer:%s' "$1" | md5sum | cut -c1-32)
  b6=$(printf '%02x' $(( (0x${hex:12:2} & 0x0f) | 0x30 )))
  b8=$(printf '%02x' $(( (0x${hex:16:2} & 0x3f) | 0x80 )))
  hex="${hex:0:12}${b6}${hex:14:2}${b8}${hex:18:14}"
  echo "${hex:0:8}-${hex:8:4}-${hex:12:4}-${hex:16:4}-${hex:20:12}"
}

validar_nick() {
  if ! [[ "$1" =~ ^[A-Za-z0-9_]{3,16}$ ]]; then
    echo "ERRO: nick invalido '$1' (3 a 16 caracteres: letras, numeros, _)"
    exit 1
  fi
}

existe() {
  jq -e --arg n "$1" 'any(.[]; (.name | ascii_downcase) == ($n | ascii_downcase))' config/whitelist.json > /dev/null
}

salvar() {
  local tmp
  tmp=$(mktemp config/whitelist.json.XXXXXX)
  jq "$@" config/whitelist.json > "$tmp"
  mv "$tmp" config/whitelist.json
}

command -v jq > /dev/null || { echo "ERRO: jq nao instalado (sudo apt install jq)"; exit 1; }
[ -f config/whitelist.json ] || echo "[]" > config/whitelist.json

case "${1:-}" in
  listar)
    jq -r '"NICK\tUUID", (sort_by(.name | ascii_downcase)[] | "\(.name)\t\(.uuid)")' config/whitelist.json | column -t
    echo ""
    echo "Total: $(jq length config/whitelist.json)"
    ;;
  criar)
    [ $# -eq 2 ] || usage
    validar_nick "$2"
    if existe "$2"; then
      echo "ERRO: jogador '$2' ja existe"
      exit 1
    fi
    salvar --arg n "$2" --arg u "$(offline_uuid "$2")" '. + [{uuid: $u, name: $n}]'
    echo "Jogador '$2' criado. Nick no jogo deve ser exatamente: $2"
    echo "Aplique com: ./run-deploy.sh"
    ;;
  deletar)
    [ $# -eq 2 ] || usage
    if ! existe "$2"; then
      echo "ERRO: jogador '$2' nao encontrado"
      exit 1
    fi
    salvar --arg n "$2" 'map(select((.name | ascii_downcase) != ($n | ascii_downcase)))'
    echo "Jogador '$2' removido da whitelist."
    CID=$(docker ps -q -f name=minecraft_server -f status=running | head -n1)
    if [ -n "$CID" ]; then
      docker exec "$CID" rcon authme unregister "$2" || true
    else
      echo "Servidor parado: depois do deploy rode: docker exec \$(docker ps -q -f name=minecraft_server) rcon authme unregister $2"
    fi
    echo "Aplique com: ./run-deploy.sh"
    ;;
  *)
    usage
    ;;
esac
