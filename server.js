const http = require('http');
const https = require('https');
const fs = require('fs');
const path = require('path');
const os = require('os');

const HTTP_PORT = 3000;
const HTTPS_PORT = 3443;
const PUBLIC_DIR = path.join(__dirname, 'web_app');

// Mahalliy IP manzilni aniqlash
function getLocalIp() {
  const interfaces = os.networkInterfaces();
  for (const name of Object.keys(interfaces)) {
    for (const iface of interfaces[name]) {
      if (iface.family === 'IPv4' && !iface.internal) {
        return iface.address;
      }
    }
  }
  return 'localhost';
}

const MIME_TYPES = {
  '.html': 'text/html',
  '.css': 'text/css',
  '.js': 'text/javascript',
  '.json': 'application/json',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.svg': 'image/svg+xml'
};

function handleRequest(req, res) {
  let reqPath = req.url === '/' ? '/index.html' : req.url;
  let filePath = path.join(PUBLIC_DIR, reqPath.split('?')[0]);

  let ext = path.extname(filePath).toLowerCase();
  let contentType = MIME_TYPES[ext] || 'application/octet-stream';

  fs.readFile(filePath, (err, content) => {
    if (err) {
      if (err.code === 'ENOENT') {
        res.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' });
        res.end('Fayl topilmadi: ' + reqPath);
      } else {
        res.writeHead(500);
        res.end('Server xatosi: ' + err.code);
      }
    } else {
      res.writeHead(200, { 
        'Content-Type': contentType + '; charset=utf-8',
        'Access-Control-Allow-Origin': '*'
      });
      res.end(content, 'utf-8');
    }
  });
}

// 1. Standart HTTP server
const httpServer = http.createServer(handleRequest);
httpServer.listen(HTTP_PORT, '0.0.0.0', () => {
  const localIp = getLocalIp();
  console.log('========================================================');
  console.log('🚀 Aqlli Uy Mahally Serveri Ishga Tushdi!');
  console.log(`💻 Kompyuterda: http://localhost:${HTTP_PORT}`);
  console.log(`📱 Smartfonda (HTTP):  http://${localIp}:${HTTP_PORT}`);
});

// 2. Xavfsiz HTTPS server (Smartfon mikrofoni ishlashi uchun)
const keyPath = path.join(__dirname, 'key.pem');
const certPath = path.join(__dirname, 'cert.pem');

if (fs.existsSync(keyPath) && fs.existsSync(certPath)) {
  const httpsOptions = {
    key: fs.readFileSync(keyPath),
    cert: fs.readFileSync(certPath)
  };

  const httpsServer = https.createServer(httpsOptions, handleRequest);
  httpsServer.listen(HTTPS_PORT, '0.0.0.0', () => {
    const localIp = getLocalIp();
    console.log(`🔒 Smartfonda (HTTPS - Mikrofon uchun): https://${localIp}:${HTTPS_PORT}`);
    console.log('========================================================');
    console.log('ℹ️  Android brauzerida mikrofondan foydalanish uchun HTTPS havolani oching!');
  });
}
