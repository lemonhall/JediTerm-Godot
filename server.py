"""Godot 4 Web 导出本地服务器 - 自动添加 SharedArrayBuffer 所需的响应头"""

import sys
from http.server import HTTPServer, SimpleHTTPRequestHandler

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8080


class GodotHandler(SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        super().end_headers()


print(f"启动服务器 → http://localhost:{PORT}")
HTTPServer(("0.0.0.0", PORT), GodotHandler).serve_forever()