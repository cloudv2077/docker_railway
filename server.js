const express = require('express');
const httpProxy = require('http-proxy');
const https = require('https');
const http = require('http');
const fs = require('fs');
const path = require('path');

// Create Express app
const app = express();
const proxy = httpProxy.createProxyServer({ ws: true });

// SSL config
const sslOptions = {
  key: fs.readFileSync('/app/ssl/server.key'),
  cert: fs.readFileSync('/app/ssl/server.crt')
};

// Serve static files
app.use(express.static('/var/www/html'));

// Handle WebSocket upgrade
function setupWebSocketProxy(server) {
  server.on('upgrade', (req, socket, head) => {
    const parsedUrl = new URL(req.url, 'http://localhost');
    
    if (parsedUrl.pathname.startsWith('/ttyd') || req.url.includes('/ttyd')) {
      proxy.ws(req, socket, head, { 
        target: 'http://localhost:7681',
        ws: true
      });
    }
  });
}

// Middleware to check if shell=1 parameter is present
app.use((req, res, next) => {
  if (req.query.shell === '1') {
    // Redirect to ttyd
    return proxy.web(req, res, { 
      target: 'http://localhost:7681',
      ignorePath: true,
      changeOrigin: true
    });
  }
  
  // For the dedicated ttyd path
  if (req.path.startsWith('/ttyd')) {
    return proxy.web(req, res, { 
      target: 'http://localhost:7681',
      changeOrigin: true
    });
  }
  
  next();
});

// 404 handler
app.use((req, res) => {
  res.status(404).sendFile(path.join('/var/www/html', '404.html'));
});

// Handle proxy errors
proxy.on('error', (err, req, res) => {
  console.error('Proxy error:', err);
  res.writeHead(500, { 'Content-Type': 'text/plain' });
  res.end('Proxy error');
});

// Create HTTP and HTTPS servers
const httpServer = http.createServer(app);
const httpsServer = https.createServer(sslOptions, app);

// Setup WebSocket proxying for both servers
setupWebSocketProxy(httpServer);
setupWebSocketProxy(httpsServer);

// Start servers
httpServer.listen(80, () => {
  console.log('HTTP Server running on port 80');
});

httpsServer.listen(443, () => {
  console.log('HTTPS Server running on port 443');
});

console.log('Node.js proxy server started');
