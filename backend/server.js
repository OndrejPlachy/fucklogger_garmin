const express = require('express');
const cors = require('cors');
const db = require('./db');

const app = express();
const PORT = process.env.PORT || 3000;
const API_KEY = process.env.API_KEY || 'your-secret-key-here';

app.use(cors());
app.use(express.json());

// Auth middleware
const checkApiKey = (req, res, next) => {
    const apiKey = req.get('X-API-Key');
    if (!apiKey || apiKey !== API_KEY) {
        return res.status(401).json({ error: 'Unauthorized' });
    }
    next();
};

// Health check
app.get('/health', (req, res) => {
    res.json({ status: 'ok' });
});

// Sync endpoint
app.post('/api/sync', checkApiKey, (req, res) => {
    const { deviceId, syncedAt, records } = req.body;

    if (!deviceId || !Array.isArray(records)) {
        return res.status(400).json({ error: 'Invalid payload' });
    }

    const insertRecord = db.prepare(`
    INSERT INTO records (device_id, date, count, horniness, dist_1, dist_2, dist_3, dist_4, dist_5, synced_at)
    VALUES (@deviceId, @date, @count, @horniness, @d1, @d2, @d3, @d4, @d5, @syncedAt)
    ON CONFLICT(device_id, date) DO UPDATE SET
      count = excluded.count,
      horniness = excluded.horniness,
      dist_1 = excluded.dist_1,
      dist_2 = excluded.dist_2,
      dist_3 = excluded.dist_3,
      dist_4 = excluded.dist_4,
      dist_5 = excluded.dist_5,
      synced_at = excluded.synced_at
  `);

    const insertLog = db.prepare(`
    INSERT INTO sync_log (device_id, synced_at, record_count)
    VALUES (?, ?, ?)
  `);

    const transaction = db.transaction((recs) => {
        for (const r of recs) {
            if (!r.distribution || r.distribution.length < 5) {
                r.distribution = [0, 0, 0, 0, 0];
            }
            insertRecord.run({
                deviceId,
                date: r.date,
                count: r.count,
                horniness: r.horniness,
                d1: r.distribution[0],
                d2: r.distribution[1],
                d3: r.distribution[2],
                d4: r.distribution[3],
                d5: r.distribution[4],
                syncedAt
            });
        }
        insertLog.run(deviceId, syncedAt, recs.length);
    });

    try {
        transaction(records);
        console.log(`Synced ${records.length} records for ${deviceId}`);
        res.json({ success: true, count: records.length });
    } catch (err) {
        console.error('Sync error:', err);
        res.status(500).json({ error: 'Database error' });
    }
});

// Get data endpoint
app.get('/api/data', checkApiKey, (req, res) => {
    const { year, month } = req.query;
    let query = 'SELECT * FROM records ORDER BY date DESC';
    const params = [];

    if (year) {
        query = "SELECT * FROM records WHERE strftime('%Y', date) = ? ORDER BY date DESC";
        params.push(year);
        if (month) {
            query = "SELECT * FROM records WHERE strftime('%Y', date) = ? AND strftime('%m', date) = ? ORDER BY date DESC";
            params.push(month.toString().padStart(2, '0'));
        }
    }

    try {
        const rows = db.prepare(query).all(...params);
        res.json(rows);
    } catch (err) {
        console.error('Query error:', err);
        res.status(500).json({ error: 'Database error' });
    }
});

app.listen(PORT, '0.0.0.0', () => {
    console.log(`Backend running on port ${PORT}`);
});
