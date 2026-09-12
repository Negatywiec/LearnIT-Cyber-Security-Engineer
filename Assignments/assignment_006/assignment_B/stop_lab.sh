#!/usr/bin/env bash
set -euo pipefail

compose() {
  if docker compose version >/dev/null 2>&1; then
    docker compose -p module06_nginx_http_lab "$@"
  elif command -v docker-compose >/dev/null 2>&1; then
    docker-compose -p module06_nginx_http_lab "$@"
  else
    echo "Docker Compose is required." >&2
    exit 1
  fi
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
LAB_DIR="$(cd -- "${SCRIPT_DIR}/.." >/dev/null 2>&1 && pwd)"

require_cmd docker

cd "$LAB_DIR"
compose down "$@"
