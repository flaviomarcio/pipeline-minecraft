# pipeline-minecraft

Servidor Minecraft (Paper 1.21.11) para a familia, em Docker Swarm.
Imagem propria (`Dockerfile`): eclipse-temurin:21-jre + Paper oficial + AuthMe, com checksum sha256.

## Seguranca
- Whitelist: so entram `flavio`, `heitor`, `vitor`, `cleice`, `alice`
- Senha por jogador (plugin AuthMe):
  - 1a vez: `/register <senha> <senha>`
  - Depois: `/login <senha>`
- RCON desativado: console via `docker attach`

## Deploy
```bash
./run-deploy.sh
```
O script faz build da imagem `minecraft-paper:1.21.11` e deploy da stack.
Build manual: `docker build -t minecraft-paper:1.21.11 -f Dockerfile .`

## Recursos Swarm
- Stack: `minecraft` / Servico: `minecraft_server`
- Rede: `minecraft-net` (overlay, attachable)
- Imagem: `minecraft-paper:1.21.11`
- Dados: `/data/minecraft/data` (bind mount)
- Backup: `/data/minecraft/backup` (bind mount)
- Porta: TCP 25565 (modo host)

## Comandos
- Logs: `docker service logs -f minecraft_server`
- Console: `docker attach $(docker ps -q -f name=minecraft_server)`
  - Sair: **Ctrl+P Ctrl+Q** (Ctrl+C derruba o servidor)
- Dar OP: `op flavio` (no console)
- Resetar senha: `authme unregister <nick>` (no console)
- Remover: `docker stack rm minecraft`

## No jogo
- Versao do launcher: **1.21.11**
- Nick exatamente igual ao da whitelist (minusculo)
- Endereco: `IP-DO-SERVIDOR:25565`

## Gerenciar jogadores
```bash
./manage-players.sh listar
./manage-players.sh criar <nick>
./manage-players.sh deletar <nick>
./run-deploy.sh   # aplica as alteracoes
```
- UUID offline gerado automaticamente
- Configs do Swarm versionados por hash (sem edicao manual do stack)
- Ao deletar, apagar a senha no console: `authme unregister <nick>`
