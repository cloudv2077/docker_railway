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
RUN echo '{\
  "name": "ttyd-node-proxy",\
  "version": "1.0.0",\
  "description": "Node.js proxy for ttyd",\
  "main": "server.js",\
  "dependencies": {\
    "express": "^4.18.2",\
    "http-proxy": "^1.18.1",\
    "https": "^1.0.0",\
    "fs": "0.0.1-security",\
    "path": "^0.12.7"\
  }\
}' > /app/package.json

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
RUN echo 'const express = require("express");\n\
const httpProxy = require("http-proxy");\n\
const https = require("https");\n\
const http = require("http");\n\
const fs = require("fs");\n\
const path = require("path");\n\
\n\
// Create Express app\n\
const app = express();\n\
const proxy = httpProxy.createProxyServer({ ws: true });\n\
\n\
// SSL config\n\
const sslOptions = {\n\
  key: fs.readFileSync("/app/ssl/server.key"),\n\
  cert: fs.readFileSync("/app/ssl/server.crt")\n\
};\n\
\n\
// Serve static files\n\
app.use(express.static("/var/www/html"));\n\
\n\
// Handle WebSocket upgrade\n\
function setupWebSocketProxy(server) {\n\
  server.on("upgrade", (req, socket, head) => {\n\
    const parsedUrl = new URL(req.url, "http://localhost");\n\
    \n\
    if (parsedUrl.pathname.startsWith("/ttyd") || req.url.includes("/ttyd")) {\n\
      proxy.ws(req, socket, head, { \n\
        target: "http://localhost:7681",\n\
        ws: true\n\
      });\n\
    }\n\
  });\n\
}\n\
\n\
// Middleware to check if shell=1 parameter is present\n\
app.use((req, res, next) => {\n\
  if (req.query.shell === "1") {\n\
    // Redirect to ttyd\n\
    return proxy.web(req, res, { \n\
      target: "http://localhost:7681",\n\
      ignorePath: true,\n\
      changeOrigin: true\n\
    });\n\
  }\n\
  \n\
  // For the dedicated ttyd path\n\
  if (req.path.startsWith("/ttyd")) {\n\
    return proxy.web(req, res, { \n\
      target: "http://localhost:7681",\n\
      changeOrigin: true\n\
    });\n\
  }\n\
  \n\
  next();\n\
});\n\
\n\
// 404 handler\n\
app.use((req, res) => {\n\
  res.status(404).sendFile(path.join("/var/www/html", "404.html"));\n\
});\n\
\n\
// Handle proxy errors\n\
proxy.on("error", (err, req, res) => {\n\
  console.error("Proxy error:", err);\n\
  res.writeHead(500, { "Content-Type": "text/plain" });\n\
  res.end("Proxy error");\n\
});\n\
\n\
// Create HTTP and HTTPS servers\n\
const httpServer = http.createServer(app);\n\
const httpsServer = https.createServer(sslOptions, app);\n\
\n\
// Setup WebSocket proxying for both servers\n\
setupWebSocketProxy(httpServer);\n\
setupWebSocketProxy(httpsServer);\n\
\n\
// Start servers\n\
httpServer.listen(80, () => {\n\
  console.log("HTTP Server running on port 80");\n\
});\n\
\n\
httpsServer.listen(443, () => {\n\
  console.log("HTTPS Server running on port 443");\n\
});\n\
\n\
console.log("Node.js proxy server started");' > /app/server.js

# Create startup script
RUN echo '#!/bin/bash\n\
\n\
# Start ttyd with a shell command in the background\n\
echo "Starting ttyd..."\n\
ttyd -p 7681 bash &\n\
TTYD_PID=$!\n\
\n\
# Wait a moment for ttyd to initialize\n\
sleep 3\n\
\n\
# Check if ttyd is running\n\
if ! ps -p $TTYD_PID > /dev/null; then\n\
  echo "ttyd failed to start with '\''bash'\''. Trying with full path '\''/bin/bash'\''..."\n\
  ttyd -p 7681 /bin/bash &\n\
  TTYD_PID=$!\n\
  sleep 3\n\
  \n\
  if ! ps -p $TTYD_PID > /dev/null; then\n\
    echo "Failed to start ttyd with '\''/bin/bash'\''. Trying with '\''sh'\''..."\n\
    ttyd -p 7681 sh &\n\
    TTYD_PID=$!\n\
    sleep 3\n\
    \n\
    if ! ps -p $TTYD_PID > /dev/null; then\n\
      echo "All attempts to start ttyd failed. Exiting."\n\
      exit 1\n\
    fi\n\
  fi\n\
fi\n\
\n\
echo "ttyd started successfully with PID: $TTYD_PID"\n\
\n\
# Test ttyd connection\n\
echo "Testing ttyd connection..."\n\
if curl -s http://localhost:7681 | grep -q "ttyd"; then\n\
  echo "ttyd is responding correctly"\n\
else\n\
  echo "Warning: ttyd might not be responding correctly"\n\
fi\n\
\n\
# Start Node.js proxy server in the foreground\n\
echo "Starting Node.js proxy server..."\n\
cd /app && node server.js' > /start.sh

# Make startup script executable
RUN chmod +x /start.sh

# Expose ports
EXPOSE 80 443 7681

# Set the command to run on container startup
CMD ["/start.sh"]
