#!/usr/bin/env bash
exec java -XX:TieredStopAtLevel=1 -Xshare:auto -cp /opt/minecraft/rcon Rcon "$@"
