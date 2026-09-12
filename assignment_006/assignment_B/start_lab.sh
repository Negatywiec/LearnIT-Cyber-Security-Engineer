#!/usr/bin/env bash
set -euo pipefail

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

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

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
LAB_DIR="$(cd -- "${SCRIPT_DIR}/.." >/dev/null 2>&1 && pwd)"

require_cmd docker
require_cmd curl

if ! docker info >/dev/null 2>&1; then
  echo "Docker daemon is not available. Start Docker and try again." >&2
  exit 1
fi

cd "$LAB_DIR"
compose up -d

echo "Waiting for Nginx on http://127.0.0.1:8080/healthz ..."
ready=0
for _ in {1..30}; do
  if curl -fsS --max-time 2 http://127.0.0.1:8080/healthz >/dev/null 2>&1; then
    ready=1
    break
  fi
  sleep 1
done

if [ "$ready" -ne 1 ]; then
  echo "Nginx did not become ready in time. Check logs with:" >&2
  echo "  docker compose -p module06_nginx_http_lab logs nginx" >&2
  exit 1
fi

echo
echo "Srodowisko startowe dziala."
echo "  Serwer HTTP:   http://127.0.0.1:8080/"
echo "  Backend:       wewnetrzna usluga Docker backend:9000"
echo
echo "Zadania studenta:"
echo "  1. Stworz lokalne CA i certyfikat serwera w nginx/certs/."
echo "  2. Dodaj reverse proxy Nginx /api/ do backend:9000."
echo "  3. Dodaj blok TLS na porcie 443 i podepnij wygenerowany certyfikat."
echo
echo "Uruchom checker:"
echo "  ./scripts/check_lab.sh"
echo
echo "Po zmianie konfiguracji Nginx:"
echo "  ./scripts/reload_nginx.sh"
