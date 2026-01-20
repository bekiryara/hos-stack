from http.server import BaseHTTPRequestHandler, HTTPServer
import json
import os


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path in ("/", "/health", "/ready"):
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(b'{"ok":true}')
            return
        self.send_response(404)
        self.end_headers()

    def do_POST(self):
        length = int(self.headers.get("content-length", "0") or "0")
        body = self.rfile.read(length) if length > 0 else b""

        # Print structured line for easy `docker compose logs` grepping.
        try:
            parsed = json.loads(body.decode("utf-8") or "null")
        except Exception:
            parsed = body.decode("utf-8", errors="replace")

        print(json.dumps({"event": "alert_webhook", "path": self.path, "payload": parsed}, ensure_ascii=False))

        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(b'{"ok":true}')

    def log_message(self, fmt, *args):
        # Silence default access logs; we emit our own JSON lines.
        return


def main():
    host = "0.0.0.0"
    port = int(os.environ.get("PORT", "8080"))
    server = HTTPServer((host, port), Handler)
    print(json.dumps({"event": "alert_webhook_started", "host": host, "port": port}))
    server.serve_forever()


if __name__ == "__main__":
    main()


