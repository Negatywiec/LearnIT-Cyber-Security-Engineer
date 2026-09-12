import json
import os
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


BACKEND_ID = os.environ.get("BACKEND_ID", "backend-unknown")
PORT = int(os.environ.get("PORT", "9000"))


class Handler(BaseHTTPRequestHandler):
    server_version = "Module06Backend/1.0"

    def do_GET(self):
        payload = {
            "backend_id": BACKEND_ID,
            "client_address": self.client_address[0],
            "host": self.headers.get("Host", ""),
            "method": self.command,
            "path": self.path,
            "service": "backend-http-server",
            "x_forwarded_for": self.headers.get("X-Forwarded-For", ""),
            "x_forwarded_proto": self.headers.get("X-Forwarded-Proto", ""),
            "x_real_ip": self.headers.get("X-Real-IP", ""),
            "x_request_id": self.headers.get("X-Request-ID", ""),
        }
        body = json.dumps(payload, indent=2, sort_keys=True).encode("utf-8")

        self.send_response(200)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("X-Backend-ID", BACKEND_ID)
        self.send_header("X-Powered-By", "training-backend")
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, fmt, *args):
        print("%s - - %s" % (self.address_string(), fmt % args), flush=True)


def main():
    server = ThreadingHTTPServer(("0.0.0.0", PORT), Handler)
    print("Backend listening on 0.0.0.0:%d" % PORT, flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
