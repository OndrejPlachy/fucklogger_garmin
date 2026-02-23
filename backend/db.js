const Database = require('better-sqlite3');
const path = require('path');

const db = new Database(path.join(__dirname, 'fucklogger.db'), { verbose: console.log });

// Create tables
db.exec(`
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
  );

  CREATE TABLE IF NOT EXISTS sync_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    device_id TEXT NOT NULL,
    synced_at TEXT NOT NULL,
    record_count INTEGER DEFAULT 0
  );
`);

module.exports = db;
