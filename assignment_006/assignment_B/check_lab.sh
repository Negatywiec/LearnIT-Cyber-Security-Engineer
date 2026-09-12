#!/usr/bin/env bash
set -u

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
LAB_DIR="$(cd -- "${SCRIPT_DIR}/.." >/dev/null 2>&1 && pwd)"
CERT_DIR="${LAB_DIR}/nginx/certs"
CA_CERT="${CERT_DIR}/student-ca.crt"
SERVER_CERT="${CERT_DIR}/student-server.crt"
SERVER_KEY="${CERT_DIR}/student-server.key"

pass_count=0
fail_count=0
warn_count=0
docker_ok=0

pass() {
  pass_count=$((pass_count + 1))
  echo "[PASS] $1"
}

fail() {
  fail_count=$((fail_count + 1))
  echo "[FAIL] $1"
}

warn() {
  warn_count=$((warn_count + 1))
  echo "[WARN] $1"
}

has_cmd() {
  command -v "$1" >/dev/null 2>&1
}

compose() {
  if docker compose version >/dev/null 2>&1; then
    docker compose -p module06_nginx_http_lab "$@"
  elif command -v docker-compose >/dev/null 2>&1; then
    docker-compose -p module06_nginx_http_lab "$@"
  else
    return 127
  fi
}

check_required_commands() {
  for cmd in docker openssl curl; do
    if has_cmd "$cmd"; then
      pass "Command available: $cmd"
    else
      fail "Missing required command: $cmd"
    fi
  done

  if has_cmd docker && docker info >/dev/null 2>&1; then
    docker_ok=1
    pass "Docker daemon is available"
  else
    fail "Docker daemon is not available"
  fi
}

check_certificates() {
  if [ -f "$CA_CERT" ] &&
     [ -f "$SERVER_CERT" ] &&
     [ -f "$SERVER_KEY" ]; then
    pass "Certificate files exist"
  else
    fail "Student certificate files are missing. Complete ./scripts/generate_cert.sh or create equivalent files manually"
    return
  fi

  if openssl verify -CAfile "$CA_CERT" "$SERVER_CERT" >/dev/null 2>&1; then
    pass "Server certificate verifies against local CA"
  else
    fail "Server certificate does not verify against local CA"
  fi

  cert_text="$(openssl x509 -in "$SERVER_CERT" -noout -text 2>/dev/null)"
  if printf '%s\n' "$cert_text" | grep -q "DNS:localhost"; then
    pass "Server certificate contains DNS SAN: localhost"
  else
    fail "Server certificate does not contain DNS SAN: localhost"
  fi

  if printf '%s\n' "$cert_text" | grep -q "DNS:reverse-proxy.lab"; then
    pass "Server certificate contains DNS SAN: reverse-proxy.lab"
  else
    fail "Server certificate does not contain DNS SAN: reverse-proxy.lab"
  fi

  if printf '%s\n' "$cert_text" | grep -q "IP Address:127.0.0.1"; then
    pass "Server certificate contains IP SAN: 127.0.0.1"
  else
    fail "Server certificate does not contain IP SAN: 127.0.0.1"
  fi
}

check_containers() {
  if [ "$docker_ok" -ne 1 ]; then
    warn "Skipping container checks because Docker is not available"
    return
  fi

  if ! compose ps >/dev/null 2>&1; then
    fail "Docker Compose project is not available. Run ./scripts/start_lab.sh"
    return
  fi

  nginx_id="$(compose ps -q nginx 2>/dev/null)"
  backend_id="$(compose ps -q backend 2>/dev/null)"

  if [ -n "$nginx_id" ] && docker inspect -f '{{.State.Running}}' "$nginx_id" 2>/dev/null | grep -q true; then
    pass "Nginx container is running"
  else
    fail "Nginx container is not running"
  fi

  if [ -n "$backend_id" ] && docker inspect -f '{{.State.Running}}' "$backend_id" 2>/dev/null | grep -q true; then
    pass "Backend container is running"
  else
    fail "Backend container is not running"
  fi

  if compose exec -T nginx nginx -t >/dev/null 2>&1; then
    pass "Nginx configuration test passes"
  else
    fail "Nginx configuration test fails"
  fi
}

check_http_server() {
  if curl -fsS --max-time 5 http://127.0.0.1:8080/healthz 2>/dev/null | grep -qx "ok"; then
    pass "HTTP health endpoint responds"
  else
    fail "HTTP health endpoint does not respond"
  fi

  body="$(curl -fsS --max-time 5 http://127.0.0.1:8080/ 2>/dev/null)"
  if printf '%s\n' "$body" | grep -q "Module 06 local HTTP server"; then
    pass "Nginx serves the static HTTP page"
  else
    fail "Nginx does not serve the expected static HTTP page"
  fi

  headers="$(curl -fsS -D - -o /dev/null --max-time 5 http://127.0.0.1:8080/assets/app.js 2>/dev/null)"
  if printf '%s\n' "$headers" | grep -qi '^Cache-Control: public, max-age=300'; then
    pass "Static asset has expected Cache-Control header"
  else
    fail "Static asset does not have expected Cache-Control header"
  fi

  direct_backend="$(curl -fsS --max-time 2 http://127.0.0.1:9000/status 2>/dev/null)"
  if printf '%s\n' "$direct_backend" | grep -q '"service": "backend-http-server"'; then
    fail "Backend is directly exposed on host port 9000"
  else
    pass "Backend is not directly exposed on host port 9000"
  fi
}

check_https_and_proxy() {
  if [ ! -f "$CA_CERT" ]; then
    fail "Cannot check HTTPS without local CA certificate"
    return
  fi

  if curl -fsS --max-time 5 --cacert "$CA_CERT" https://localhost:8443/healthz 2>/dev/null | grep -qx "ok"; then
    pass "HTTPS endpoint validates with the local CA"
  else
    fail "HTTPS endpoint does not validate with the local CA"
  fi

  api_body="$(curl -fsS --max-time 5 --cacert "$CA_CERT" https://localhost:8443/api/status 2>/dev/null)"
  if printf '%s\n' "$api_body" | grep -q '"service": "backend-http-server"'; then
    pass "Reverse proxy reaches the backend service"
  else
    fail "Reverse proxy does not return the expected backend response"
  fi

  if printf '%s\n' "$api_body" | grep -q '"x_forwarded_proto": "https"'; then
    pass "Reverse proxy forwards X-Forwarded-Proto"
  else
    fail "Reverse proxy does not forward X-Forwarded-Proto"
  fi

  api_headers="$(curl -fsS -D - -o /dev/null --max-time 5 --cacert "$CA_CERT" https://localhost:8443/api/status 2>/dev/null)"
  if printf '%s\n' "$api_headers" | grep -qi '^X-Lab-Proxy: nginx-reverse-proxy'; then
    pass "Reverse proxy adds X-Lab-Proxy header"
  else
    fail "Reverse proxy does not add X-Lab-Proxy header"
  fi

  if printf '%s\n' "$api_headers" | grep -qi '^X-Powered-By:'; then
    fail "Upstream X-Powered-By header is visible to the client"
  else
    pass "Upstream X-Powered-By header is hidden by Nginx"
  fi
}

cd "$LAB_DIR" || exit 1

check_required_commands
check_certificates
check_containers
check_http_server
check_https_and_proxy

echo
echo "Summary: ${pass_count} passed, ${fail_count} failed, ${warn_count} warnings"

if [ "$fail_count" -gt 0 ]; then
  exit 1
fi

exit 0
