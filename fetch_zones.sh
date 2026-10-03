#!/usr/bin/env bash
# Copies the spawn zones (deathmatch squares files) from the server to here.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Only homepath/legacy/deathmatch/: the rest of homepath is logs and state
# that the server owns.
rsync -avP et:/home/debian/etserver/homepath/legacy/deathmatch/ "$SCRIPT_DIR/homepath/legacy/deathmatch/"
