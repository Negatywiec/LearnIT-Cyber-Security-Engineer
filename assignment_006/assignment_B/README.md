# Moduł 06 - lab Nginx HTTP

Lab dla studentów obejmuje:

- uruchomienie serwera HTTP na Nginx,
- stworzenie lokalnego CA i certyfikatu serwera,
- wystawienie reverse proxy z Nginx do usługi backendowej,
- sprawdzenie wyniku automatycznym checkerem.

## Wymagania

- Docker z Docker Compose,
- OpenSSL,
- curl.

## Uruchomienie

```bash
cd content/06/lab-nginx-http
./scripts/start_lab.sh
./scripts/check_lab.sh
```

`start_lab.sh` uruchamia tylko środowisko bazowe. Nie generuje certyfikatów
i nie rozwiązuje za studenta zadań z reverse proxy oraz TLS. Student musi uzupełnić:

- `scripts/generate_cert.sh` albo stworzyć wymagane pliki certyfikatów ręcznie,
- `nginx/conf.d/default.conf`,
- `nginx/includes/lab_locations.conf`.

Po zmianie konfiguracji Nginx:

```bash
./scripts/reload_nginx.sh
```

Endpointy:

- `http://127.0.0.1:8080/` - statyczny serwer HTTP,
- `https://localhost:8443/` - oczekiwany po wykonaniu zadania z TLS,
- `https://localhost:8443/api/status` - oczekiwany po wykonaniu zadania z reverse proxy.

Jeżeli na porcie `8443` widzisz `400 Bad Request` albo komunikat
`The plain HTTP request was sent to HTTPS port`, wysyłasz zwykły HTTP na port
TLS. Użyj pełnego adresu `https://localhost:8443/`, a nie
`http://localhost:8443/` ani samego `localhost:8443`.

Nie uruchamiaj jednocześnie katalogu studenckiego i katalogu z rozwiązaniem,
ponieważ oba korzystają z portów `8080` i `8443`.

Zatrzymanie labu:

```bash
./scripts/stop_lab.sh
```
