import http.server
import socketserver
import json
import sqlite3
import os
import threading
from urllib.parse import urlparse, parse_qs

PORT = 3000
API_KEY = "your-secret-key-here"
DB_FILE = "fucklogger.db"

def init_db():
    conn = sqlite3.connect(DB_FILE)
    c = conn.cursor()
    c.execute('''
        CREATE TABLE IF NOT EXISTS records (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            device_id TEXT NOT NULL,
            date TEXT NOT NULL,
            count INTEGER DEFAULT 0,
            horniness INTEGER DEFAULT 3,
            dist_1 INTEGER DEFAULT 0,
            dist_2 INTEGER DEFAULT 0,
            dist_3 INTEGER DEFAULT 0,
            dist_4 INTEGER DEFAULT 0,
            dist_5 INTEGER DEFAULT 0,
            synced_at TEXT,
            UNIQUE(device_id, date)
        )
    ''')
    c.execute('''
        CREATE TABLE IF NOT EXISTS sync_log (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            device_id TEXT NOT NULL,
            synced_at TEXT NOT NULL,
            record_count INTEGER DEFAULT 0
        )
    ''')
    conn.commit()
    conn.close()

class RequestHandler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        parsed_path = urlparse(self.path)
        
        if parsed_path.path == "/":
            self.send_response(200)
            self.send_header('Content-type', 'text/html')
            self.end_headers()
            self.wfile.write(b"""
                <html>
                <head><title>FuckLogger Backend</title></head>
                <body>
                    <h1>Backend is Running!</h1>
                    <p>Sync Endpoint: <code>POST /api/sync</code></p>
                    <p>View Data: <a href="/api/data">/api/data</a></p>
                </body>
                </html>
            """)
            return

        if parsed_path.path == "/health":
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps({"status": "ok"}).encode())
            return

        if parsed_path.path == "/api/data":
            if not self.check_auth(): return
            
            query = parse_qs(parsed_path.query)
            year = query.get('year', [None])[0]
            month = query.get('month', [None])[0]
            
            conn = sqlite3.connect(DB_FILE)
            conn.row_factory = sqlite3.Row
            c = conn.cursor()
            
            sql = "SELECT * FROM records ORDER BY date DESC"
            params = []
            
            if year:
                sql = "SELECT * FROM records WHERE strftime('%Y', date) = ? ORDER BY date DESC"
                params.append(year)
                if month:
                    sql = "SELECT * FROM records WHERE strftime('%Y', date) = ? AND strftime('%m', date) = ? ORDER BY date DESC"
                    params.append(month.zfill(2))
            
            c.execute(sql, params)
            rows = [dict(row) for row in c.fetchall()]
            conn.close()
            
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps(rows).encode())
            return
            
        self.send_error(404)

    def do_POST(self):
        if self.path == "/api/sync":
            print(f"Received SYNC request from {self.client_address}") # DEBUG LOG
            if not self.check_auth(): 
                print("Authentication failed")
                return
            
            content_length = int(self.headers['Content-Length'])
            post_data = self.rfile.read(content_length)
            try:
                data = json.loads(post_data)
                print(f"Payload received: {json.dumps(data, indent=2)}") # DEBUG LOG
                
                device_id = data.get('deviceId')
                synced_at = data.get('syncedAt')
                records = data.get('records', [])
                
                if not device_id or not isinstance(records, list):
                    self.send_response(400)
                    self.end_headers()
                    self.wfile.write(b'{"error": "Invalid payload"}')
                    return

                conn = sqlite3.connect(DB_FILE)
                c = conn.cursor()
                
                try:
                    for r in records:
                        dist = r.get('distribution', [0,0,0,0,0])
                        if len(dist) < 5: dist = [0,0,0,0,0]
                        
                        c.execute('''
                            INSERT INTO records (device_id, date, count, horniness, dist_1, dist_2, dist_3, dist_4, dist_5, synced_at)
                            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                            ON CONFLICT(device_id, date) DO UPDATE SET
                                count=excluded.count,
                                horniness=excluded.horniness,
                                dist_1=excluded.dist_1,
                                dist_2=excluded.dist_2,
                                dist_3=excluded.dist_3,
                                dist_4=excluded.dist_4,
                                dist_5=excluded.dist_5,
                                synced_at=excluded.synced_at
                        ''', (device_id, r['date'], r['count'], r['horniness'], 
                              dist[0], dist[1], dist[2], dist[3], dist[4], synced_at))
                    
                    c.execute('INSERT INTO sync_log (device_id, synced_at, record_count) VALUES (?, ?, ?)',
                              (device_id, synced_at, len(records)))
                    
                    conn.commit()
                    response = {"success": True, "count": len(records)}
                    status = 200
                except Exception as e:
                    print(f"Error: {e}")
                    conn.rollback()
                    response = {"error": "Database error"}
                    status = 500
                finally:
                    conn.close()
                
                self.send_response(status)
                self.send_header('Content-type', 'application/json')
                self.end_headers()
                self.wfile.write(json.dumps(response).encode())

            except json.JSONDecodeError:
                self.send_response(400)
                self.end_headers()
                self.wfile.write(b'{"error": "Invalid JSON"}')
            return
            
        self.send_error(404)

    def check_auth(self):
        # Check header first
        key = self.headers.get('X-API-Key')
        
        # If not in header, check query params (for browser testing)
        if not key:
            parsed = urlparse(self.path)
            params = parse_qs(parsed.query)
            if 'key' in params:
                key = params['key'][0]

        if key != API_KEY:
            self.send_response(401)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps({"error": "Unauthorized"}).encode())
            return False
        return True

if __name__ == "__main__":
    init_db()
    with socketserver.TCPServer(("", PORT), RequestHandler) as httpd:
        print(f"Serving at port {PORT}")
        httpd.serve_forever()
