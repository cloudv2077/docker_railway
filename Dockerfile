FROM tsl0922/ttyd:latest

# Install Node.js
RUN apt-get update && \
    apt-get install -y curl procps && \
    curl -fsSL https://deb.nodesource.com/setup_18.x | bash - && \
    apt-get install -y nodejs && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Create default web pages
RUN mkdir -p /var/www/html && \
    echo "<html><body><h1>Web Server is working!</h1></body></html>" > /var/www/html/index.html && \
    echo "<html><body><h1>404 - Page Not Found</h1></body></html>" > /var/www/html/404.html

# Create Node.js proxy server script
RUN mkdir -p /app
WORKDIR /app

# Create package.json
RUN echo '{ \
  "name": "ttyd-node-proxy", \
  "version": "1.0.0", \
  "description": "Node.js proxy for ttyd", \
  "main": "server.js", \
  "dependencies": { \
    "express": "^4.18.2", \
    "http-proxy": "^1.18.1", \
    "https": "^1.0.0", \
    "fs": "0.0.1-security", \
    "path": "^0.12.7" \
  } \
}' > package.json

# Install dependencies
RUN npm install

# Create self-signed SSL certificate
RUN apt-get update && \
    apt-get install -y openssl && \
    mkdir -p /app/ssl && \
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /app/ssl/server.key -out /app/ssl/server.crt \
    -subj "/C=US/ST=State/L=City/O=Organization/CN=localhost" && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Create Node.js server script
RUN cat > /app/server.js << 'EOF'
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
EOF

# Create startup script
RUN cat > /start.sh << 'EOF'
#!/bin/bash

# Start ttyd with a shell command in the background
echo "Starting ttyd..."
ttyd -p 7681 bash &
TTYD_PID=$!

# Wait a moment for ttyd to initialize
sleep 3

# Check if ttyd is running
if ! ps -p $TTYD_PID > /dev/null; then
  echo "ttyd failed to start with 'bash'. Trying with full path '/bin/bash'..."
  ttyd -p 7681 /bin/bash &
  TTYD_PID=$!
  sleep 3
  
  if ! ps -p $TTYD_PID > /dev/null; then
    echo "Failed to start ttyd with '/bin/bash'. Trying with 'sh'..."
    ttyd -p 7681 sh &
    TTYD_PID=$!
    sleep 3
    
    if ! ps -p $TTYD_PID > /dev/null; then
      echo "All attempts to start ttyd failed. Exiting."
      exit 1
    fi
  fi
fi

echo "ttyd started successfully with PID: $TTYD_PID"

# Test ttyd connection
echo "Testing ttyd connection..."
if curl -s http://localhost:7681 | grep -q "ttyd"; then
  echo "ttyd is responding correctly"
else
  echo "Warning: ttyd might not be responding correctly"
fi

# Start Node.js proxy server in the foreground
echo "Starting Node.js proxy server..."
cd /app && node server.js
EOF

# Make startup script executable
RUN chmod +x /start.sh

# Expose ports
EXPOSE 80 443 7681

# Set the command to run on container startup
CMD ["/start.sh"]
