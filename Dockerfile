# syntax=docker/dockerfile:1

# Compila o cliente RCON (usado por run-backup.sh e manage-players.sh)
FROM eclipse-temurin:21-jdk-noble AS rcon-build
COPY docker/rcon/Rcon.java /src/Rcon.java
RUN javac -d /out /src/Rcon.java

FROM eclipse-temurin:21-jre-noble

# UID/GID 1000 = dono das pastas /data/minecraft no host (remove usuario ubuntu da base)
RUN userdel -r ubuntu \
 && useradd -m -u 1000 -U -d /home/minecraft minecraft \
 && mkdir -p /opt/minecraft/plugins /data \
 && chown minecraft:minecraft /data

# Paper 1.21.11 build 132 (oficial PaperMC)
ADD --chmod=644 --checksum=sha256:5ffef465eeeb5f2a3c23a24419d97c51afd7dbb4923ff42df9a3f58bba1ccfba \
    https://fill-data.papermc.io/v1/objects/5ffef465eeeb5f2a3c23a24419d97c51afd7dbb4923ff42df9a3f58bba1ccfba/paper-1.21.11-132.jar \
    /opt/minecraft/paper.jar

# AuthMe Reloaded 6.0.1 (senha por jogador)
ADD --chmod=644 --checksum=sha256:7704335e9e73a634d9d926344f77897f4c74f78f82453a59f5aa0f8d2722450a \
    https://github.com/AuthMe/AuthMeReloaded/releases/download/6.0.1/AuthMe-6.0.1-Paper.jar \
    /opt/minecraft/plugins/AuthMe-6.0.1-Paper.jar

COPY --from=rcon-build /out/ /opt/minecraft/rcon/
COPY --chmod=755 docker/rcon/rcon.sh /usr/local/bin/rcon
COPY --chmod=755 docker/entrypoint.sh /opt/minecraft/entrypoint.sh

USER minecraft
WORKDIR /data
EXPOSE 25565/tcp

HEALTHCHECK --start-period=180s --interval=30s --timeout=5s --retries=3 \
  CMD bash -c '</dev/tcp/127.0.0.1/25565' || exit 1

ENTRYPOINT ["/opt/minecraft/entrypoint.sh"]
