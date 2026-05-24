const express = require('express');
const http = require('http');
const path = require('path');
const { Server } = require('socket.io');

const PORT = process.env.PORT || 8083;

const app = express();
const server = http.createServer(app);
const io = new Server(server, {
    cors: { origin: '*' }
});

// Serve static files
app.use(express.static(path.join(__dirname, '.')));

// Fallback: serve index.html for any unmatched route
app.get('/', (req, res) => {
    res.sendFile(path.join(__dirname, 'index.html'));
});

// ============================================================
//  TIKTOK LIVE HLS PROXY ENDPOINT
//  GET /api/tiktok/stream?username=namauser
// ============================================================
app.get('/api/tiktok/stream', async (req, res) => {
    const username = (req.query.username || '').replace('@', '').trim();

    if (!username) {
        return res.status(400).json({ error: 'Parameter username diperlukan.' });
    }

    try {
        // Dynamically import ESM module
        const { TikTokLiveConnection } = await import('tiktok-live-connector');
        const connection = new TikTokLiveConnection(username);

        // Set timeout to avoid hanging
        const timeout = new Promise((_, reject) =>
            setTimeout(() => reject(new Error('Timeout: TikTok tidak merespons dalam 15 detik.')), 15000)
        );

        const connectResult = await Promise.race([
            connection.connect(),
            timeout
        ]);

        // Try to get HLS stream URL from room info
        let hlsUrl = null;
        if (connectResult && connectResult.roomInfo && connectResult.roomInfo.stream_url) {
            hlsUrl = connectResult.roomInfo.stream_url.hls_pull_url;
        }

        // Disconnect after fetching info
        try { connection.disconnect(); } catch (e) {}

        if (hlsUrl) {
            return res.json({
                success: true,
                username,
                hlsUrl,
                message: 'HLS stream URL berhasil diambil.'
            });
        } else {
            return res.json({
                success: false,
                username,
                hlsUrl: null,
                message: `@${username} mungkin tidak sedang live, atau stream URL tidak tersedia.`
            });
        }
    } catch (err) {
        console.error('[TikTok Stream Error]', err.constructor.name, err.message);

        let friendlyMsg = 'Gagal terhubung ke stream TikTok.';
        const errName = err.constructor.name || '';
        const errMsg = (err.message || '').toLowerCase();

        if (errName === 'UserOfflineError' || errMsg.includes('offline') || errMsg.includes("isn't online")) {
            friendlyMsg = `@${username} tidak sedang melakukan live stream saat ini.`;
        } else if (errName === 'UserNotFoundError' || errMsg.includes('not found') || errMsg.includes('404')) {
            friendlyMsg = `Akun TikTok @${username} tidak ditemukan. Periksa kembali username-nya.`;
        } else if (errName === 'AlreadyConnectedError') {
            friendlyMsg = 'Sudah terhubung ke stream ini.';
        } else if (errMsg.includes('timeout') || errName === 'TimeoutError') {
            friendlyMsg = 'Koneksi ke TikTok timeout. Coba lagi sebentar.';
        } else if (errMsg.includes('rate limit') || errMsg.includes('429')) {
            friendlyMsg = 'TikTok membatasi permintaan. Tunggu beberapa menit sebelum mencoba lagi.';
        }

        return res.status(500).json({
            success: false,
            username,
            hlsUrl: null,
            message: friendlyMsg,
            debug: `${errName}: ${err.message}`
        });
    }
});

// ============================================================
//  SOCKET.IO - Real-time status (optional future use)
// ============================================================
io.on('connection', (socket) => {
    console.log('[Socket.IO] Client terhubung:', socket.id);
    socket.on('disconnect', () => {
        console.log('[Socket.IO] Client terputus:', socket.id);
    });
});

// ============================================================
//  START SERVER
// ============================================================
server.listen(PORT, () => {
    console.log(`\n======================================================`);
    console.log(`  KURBAN DIGITAL SERVER RUNNING AT:`);
    console.log(`  http://localhost:${PORT}`);
    console.log(`  API: http://localhost:${PORT}/api/tiktok/stream?username=USERNAME`);
    console.log(`======================================================\n`);
});
