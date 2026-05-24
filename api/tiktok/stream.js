// ============================================================
//  VERCEL SERVERLESS FUNCTION: /api/tiktok/stream
//  GET /api/tiktok/stream?username=namauser
//
//  Mengambil HLS stream URL dari TikTok Live menggunakan
//  tiktok-live-connector (server-side, tidak diblokir browser)
// ============================================================

export default async function handler(req, res) {
    // Hanya izinkan GET
    if (req.method !== 'GET') {
        return res.status(405).json({ error: 'Method Not Allowed' });
    }

    const username = ((req.query && req.query.username) || '').replace('@', '').trim();

    if (!username) {
        return res.status(400).json({ error: 'Parameter username diperlukan.' });
    }

    try {
        const { TikTokLiveConnection } = await import('tiktok-live-connector');
        const connection = new TikTokLiveConnection(username);

        // Timeout 15 detik (Vercel Hobby = 10 detik, Pro = 30 detik)
        const timeout = new Promise((_, reject) =>
            setTimeout(() => reject(Object.assign(new Error('Timeout'), { name: 'TimeoutError' })), 14000)
        );

        const connectResult = await Promise.race([
            connection.connect(),
            timeout
        ]);

        let hlsUrl = null;
        if (connectResult && connectResult.roomInfo && connectResult.roomInfo.stream_url) {
            hlsUrl = connectResult.roomInfo.stream_url.hls_pull_url;
        }

        try { connection.disconnect(); } catch (e) {}

        if (hlsUrl) {
            return res.status(200).json({
                success: true,
                username,
                hlsUrl,
                message: 'HLS stream URL berhasil diambil.'
            });
        } else {
            return res.status(200).json({
                success: false,
                username,
                hlsUrl: null,
                message: `@${username} mungkin tidak sedang live, atau stream URL tidak tersedia.`
            });
        }
    } catch (err) {
        const errName = err.constructor ? err.constructor.name : (err.name || 'Error');
        const errMsg = (err.message || '').toLowerCase();

        let friendlyMsg = 'Gagal terhubung ke stream TikTok.';
        if (errName === 'UserOfflineError' || errMsg.includes("isn't online") || errMsg.includes('offline')) {
            friendlyMsg = `@${username} tidak sedang melakukan live stream saat ini.`;
        } else if (errName === 'UserNotFoundError' || errMsg.includes('not found') || errMsg.includes('404')) {
            friendlyMsg = `Akun TikTok @${username} tidak ditemukan.`;
        } else if (errName === 'TimeoutError' || errMsg.includes('timeout')) {
            friendlyMsg = 'Koneksi ke TikTok timeout. Coba lagi sebentar.';
        } else if (errMsg.includes('rate limit') || errMsg.includes('429')) {
            friendlyMsg = 'TikTok membatasi permintaan. Tunggu beberapa menit.';
        }

        return res.status(500).json({
            success: false,
            username,
            hlsUrl: null,
            message: friendlyMsg,
            debug: `${errName}: ${err.message}`
        });
    }
}
