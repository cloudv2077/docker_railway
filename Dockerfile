FROM tsl0922/ttyd:latest

# Install Nginx for reverse proxy
RUN apt-get update && \
    apt-get install -y nginx openssl procps && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Create self-signed SSL certificate
RUN mkdir -p /etc/nginx/ssl && \
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/nginx/ssl/nginx.key -out /etc/nginx/ssl/nginx.crt \
    -subj "/C=US/ST=State/L=City/O=Organization/CN=localhost"

# Create default web pages
RUN mkdir -p /var/www/html && \
    echo "<html><body><h1>Web Server is working!</h1></body></html>" > /var/www/html/index.html && \
    echo "<html><body><h1>404 - Page Not Found</h1></body></html>" > /var/www/html/404.html

# Configure Nginx
RUN cat > /etc/nginx/nginx.conf << 'EOF'
user www-data;
worker_processes auto;
pid /run/nginx.pid;

events {
    worker_connections 768;
}

http {
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;

    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;
    ssl_ciphers "EECDH+AESGCM:EDH+AESGCM:AES256+EECDH:AES256+EDH";

    map $args $is_shell {
        default 0;
        ~*shell=1 1;
    }

    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log debug;

    # HTTP Server
    server {
        listen 80 default_server;
        server_name _;

        # Proxy to ttyd for shell=1 requests
        location / {
            # Use map variable for conditional processing
            if ($is_shell = 1) {
                rewrite ^(.*)$ /ttyd last;
            }
            
            # Default content
            root /var/www/html;
            index index.html;
        }

        # Dedicated location for ttyd proxy
        location /ttyd {
            proxy_pass http://127.0.0.1:7681;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_set_header Host $host;
            proxy_read_timeout 1800s;
            proxy_send_timeout 1800s;
            proxy_buffering off;
        }

        # Default 404 page
        error_page 404 /404.html;
        location = /404.html {
            root /var/www/html;
        }
    }

    # HTTPS Server
    server {
        listen 443 ssl default_server;
        server_name _;

        ssl_certificate /etc/nginx/ssl/nginx.crt;
        ssl_certificate_key /etc/nginx/ssl/nginx.key;

        # Proxy to ttyd for shell=1 requests
        location / {
            # Use map variable for conditional processing
            if ($is_shell = 1) {
                rewrite ^(.*)$ /ttyd last;
            }
            
            # Default content
            root /var/www/html;
            index index.html;
        }

        # Dedicated location for ttyd proxy
        location /ttyd {
            proxy_pass http://127.0.0.1:7681;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_set_header Host $host;
            proxy_read_timeout 1800s;
            proxy_send_timeout 1800s;
            proxy_buffering off;
        }

        # Default 404 page
        error_page 404 /404.html;
        location = /404.html {
            root /var/www/html;
        }
    }
}
EOF

# Create startup script that correctly starts ttyd
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

# Start Nginx in the foreground
echo "Starting Nginx..."
nginx -g "daemon off;"
EOF

# Make startup script executable
RUN chmod +x /start.sh

# Expose ports
EXPOSE 80 443 7681

# Set the command to run on container startup
CMD ["/start.sh"]
