#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: ./scripts/generate_cert.sh

To jest skrypt zadaniowy dla studenta. Uzupelnij go tak, aby tworzyl:
  - nginx/certs/student-ca.key
  - nginx/certs/student-ca.crt
  - nginx/certs/student-server.key
  - nginx/certs/student-server.csr
  - nginx/certs/student-server.crt

Certyfikat serwera musi byc poprawny dla:
  - localhost
  - reverse-proxy.lab
  - 127.0.0.1

Uzyj nginx/certs/ca.cnf oraz nginx/certs/server.cnf jako plikow konfiguracyjnych OpenSSL.
USAGE
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
LAB_DIR="$(cd -- "${SCRIPT_DIR}/.." >/dev/null 2>&1 && pwd)"
CERT_DIR="${LAB_DIR}/nginx/certs"

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  usage
  exit 0
fi

if [ "$#" -gt 0 ]; then
  echo "Ten skrypt zadaniowy nie przyjmuje opcji." >&2
  usage >&2
  exit 2
fi

require_cmd openssl

mkdir -p "$CERT_DIR"

umask 077

# 1. Wygeneruj prywatny klucz lokalnego CA.
openssl genrsa \
  -out "${CERT_DIR}/student-ca.key" \
  4096

# 2. Wygeneruj self-signed certyfikat CA.
openssl req \
  -x509 \
  -new \
  -sha256 \
  -days 3650 \
  -key "${CERT_DIR}/student-ca.key" \
  -out "${CERT_DIR}/student-ca.crt" \
  -config "${CERT_DIR}/ca.cnf"

# 3. Wygeneruj prywatny klucz serwera.
openssl genrsa \
  -out "${CERT_DIR}/student-server.key" \
  2048

# 4. Wygeneruj CSR dla serwera.
openssl req \
  -new \
  -sha256 \
  -key "${CERT_DIR}/student-server.key" \
  -out "${CERT_DIR}/student-server.csr" \
  -config "${CERT_DIR}/server.cnf"

# 5. Podpisz CSR serwera lokalnym CA.
openssl x509 \
  -req \
  -sha256 \
  -days 825 \
  -in "${CERT_DIR}/student-server.csr" \
  -CA "${CERT_DIR}/student-ca.crt" \
  -CAkey "${CERT_DIR}/student-ca.key" \
  -CAcreateserial \
  -out "${CERT_DIR}/student-server.crt" \
  -extfile "${CERT_DIR}/server.cnf" \
  -extensions v3_req

# 6. Zweryfikuj certyfikat serwera względem naszego CA.
openssl verify \
  -CAfile "${CERT_DIR}/student-ca.crt" \
  "${CERT_DIR}/student-server.crt"

echo
echo "Certyfikaty zostaly wygenerowane:"
echo "  ${CERT_DIR}/student-ca.key"
echo "  ${CERT_DIR}/student-ca.crt"
echo "  ${CERT_DIR}/student-server.key"
echo "  ${CERT_DIR}/student-server.csr"
echo "  ${CERT_DIR}/student-server.crt"

cat >&2 <<'TODO'



TODO: zaimplementuj generowanie certyfikatow.

Wymagane pliki wynikowe:
  nginx/certs/student-ca.key
  nginx/certs/student-ca.crt
  nginx/certs/student-server.key
  nginx/certs/student-server.csr
  nginx/certs/student-server.crt

Wskazowki:
  - Wygeneruj klucz prywatny dla lokalnego CA.
  - Stworz self-signed certyfikat CA z nginx/certs/ca.cnf.
  - Wygeneruj klucz prywatny i CSR dla serwera.
  - Podpisz CSR serwera lokalnym CA.
  - Przy podpisywaniu uzyj nginx/certs/server.cnf oraz rozszerzen v3_req.
  - Zweryfikuj wynik poleceniem openssl verify.

Checker oczekuje dokladnie takich nazw plikow jak powyzej.
TODO

exit 1
