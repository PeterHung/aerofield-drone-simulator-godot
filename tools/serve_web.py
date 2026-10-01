#!/usr/bin/env python3
"""Serve a Godot Web export on localhost with correct WASM MIME types."""
import argparse
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import threading
import webbrowser


class Handler(SimpleHTTPRequestHandler):
    extensions_map = {**SimpleHTTPRequestHandler.extensions_map, ".wasm": "application/wasm"}

    def end_headers(self):
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Cache-Control", "no-cache")
        super().end_headers()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--directory", type=Path)
    parser.add_argument("--port", type=int, default=8437)
    parser.add_argument("--open", action="store_true")
    args = parser.parse_args()
    script_dir = Path(__file__).resolve().parent
    folder = args.directory or (script_dir if (script_dir / "index.html").exists()
                               else script_dir.parent / "builds" / "web")
    if not (folder / "index.html").is_file():
        parser.error(f"Missing Web export: {folder}")
    server = ThreadingHTTPServer(("127.0.0.1", args.port), partial(Handler, directory=str(folder)))
    url = f"http://127.0.0.1:{args.port}/"
    print(f"AEROFIELD: {url}\n按 Ctrl+C 停止。", flush=True)
    if args.open:
        threading.Timer(0.5, webbrowser.open, args=(url,)).start()
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
