#!/usr/bin/env python3
"""Serveur de recette sur le réseau local : sert le build web d'Akonta et relaie l'API Supabase de recette.

Un seul port : la page et l'API partagent la même origine (pas de CORS, un build web valable pour toute adresse).
  /auth/v1, /rest/v1, /storage/v1, /functions/v1  ->  API Supabase de recette (127.0.0.1:55321)
  /realtime/v1 (WebSocket)                         ->  tunnel vers le service Realtime de la même API
  tout le reste                                    ->  fichiers de app/build/web (retombe sur index.html pour les routes de l'application)
Bibliothèque standard uniquement. Usage : recette/serveur-reseau.py [--port 8080] [--api http://127.0.0.1:55321]
"""
import argparse
import http.client
import mimetypes
import socket
import sys
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlsplit, unquote

ROOT = Path(__file__).resolve().parent.parent
WEB = ROOT / "app" / "build" / "web"
PROXIED = ("/auth/v1", "/rest/v1", "/storage/v1", "/functions/v1")
REALTIME = "/realtime/v1"
HOP_BY_HOP = {"connection", "keep-alive", "proxy-authenticate", "proxy-authorization", "te", "trailers", "transfer-encoding", "upgrade", "host"}


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    api_host = "127.0.0.1"
    api_port = 55321

    def log_message(self, fmt, *args):
        sys.stderr.write("%s %s\n" % (self.address_string(), fmt % args))

    def do_GET(self): self._route()
    def do_HEAD(self): self._route()
    def do_POST(self): self._route()
    def do_PUT(self): self._route()
    def do_PATCH(self): self._route()
    def do_DELETE(self): self._route()
    def do_OPTIONS(self): self._route()

    def _route(self):
        path = urlsplit(self.path).path
        if path.startswith(REALTIME) and self.headers.get("Upgrade", "").lower() == "websocket":
            self._tunnel()
        elif path.startswith(PROXIED):
            self._proxy()
        elif self.command in ("GET", "HEAD"):
            self._static(path)
        else:
            self.send_error(405)

    def _tunnel(self):
        """Relaie une connexion WebSocket octet par octet : la poignée de main HTTP est rejouée telle quelle vers l'API."""
        try:
            upstream = socket.create_connection((self.api_host, self.api_port), timeout=10)
        except OSError as e:
            self.send_error(502, f"Realtime de recette injoignable : {e}")
            return
        upstream.settimeout(None)
        lines = [f"{self.command} {self.path} HTTP/1.1"]
        for k, v in self.headers.items():
            lines.append(f"{k}: {self.api_host}:{self.api_port}" if k.lower() == "host" else f"{k}: {v}")
        upstream.sendall(("\r\n".join(lines) + "\r\n\r\n").encode("latin-1"))
        self.close_connection = True
        client = self.connection

        def pump(src, dst):
            try:
                while (chunk := src.recv(65536)):
                    dst.sendall(chunk)
            except OSError:
                pass
            finally:
                for sock in (src, dst):
                    try:
                        sock.shutdown(socket.SHUT_RDWR)
                    except OSError:
                        pass

        back = threading.Thread(target=pump, args=(upstream, client), daemon=True)
        back.start()
        pump(client, upstream)
        back.join(timeout=5)
        upstream.close()

    def _proxy(self):
        length = int(self.headers.get("Content-Length") or 0)
        body = self.rfile.read(length) if length else None
        headers = {k: v for k, v in self.headers.items() if k.lower() not in HOP_BY_HOP}
        conn = http.client.HTTPConnection(self.api_host, self.api_port, timeout=120)
        try:
            conn.request(self.command, self.path, body=body, headers=headers)
            resp = conn.getresponse()
            data = resp.read()
        except OSError as e:
            self.send_error(502, f"API de recette injoignable : {e}")
            return
        finally:
            conn.close()
        self.send_response(resp.status)
        for k, v in resp.getheaders():
            if k.lower() not in HOP_BY_HOP and k.lower() != "content-length":
                self.send_header(k, v)
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        if self.command != "HEAD":
            self.wfile.write(data)

    def _static(self, path):
        rel = unquote(path).lstrip("/")
        target = (WEB / rel).resolve()
        if not target.is_file() or WEB.resolve() not in target.parents:
            target = WEB / "index.html"  # routes de l'application (go_router) : index.html
        data = target.read_bytes()
        ctype = mimetypes.guess_type(target.name)[0] or "application/octet-stream"
        self.send_response(200)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Cache-Control", "no-cache")
        self.end_headers()
        if self.command != "HEAD":
            self.wfile.write(data)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", type=int, default=8080)
    ap.add_argument("--api", default="http://127.0.0.1:55321")
    args = ap.parse_args()
    api = urlsplit(args.api)
    Handler.api_host, Handler.api_port = api.hostname, api.port
    if not (WEB / "index.html").is_file():
        sys.exit("Build web absent : lancer recette/lancer-reseau.sh (il le compile).")
    ThreadingHTTPServer(("0.0.0.0", args.port), Handler).serve_forever()


if __name__ == "__main__":
    main()
