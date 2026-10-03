#!/usr/bin/env bash
# Copies server files to the server, then restarts the container.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

usage() {
    cat <<USAGE
Usage: ./deploy.sh <target>

Targets:
  etserver  copy this whole folder except maps/
  maps      copy only maps/
  configs   copy only ../legacy-configs/
  help      show this message

The container is restarted after every copy.
USAGE
}

# The leading slash limits the exclude to the top-level maps/ folder.
copy_etserver() { rsync -avP --exclude /maps/ "$SCRIPT_DIR/" et:etserver/; }
copy_maps()     { rsync -avP "$SCRIPT_DIR/maps/" et:etserver/maps/; }
copy_configs()  { rsync -avP "$SCRIPT_DIR/../legacy-configs/" et:legacy-configs/; }

restart_server() {
    ssh et "cd etserver && sudo docker compose up -d --force-recreate"
}

target="${1:-help}"

case "$target" in
    etserver)       copy_etserver ;;
    maps)           copy_maps ;;
    configs)        copy_configs ;;
    help|-h|--help) usage; exit 0 ;;
    *)
        echo "Unknown target: $target" >&2
        usage >&2
        exit 1
        ;;
esac

restart_server