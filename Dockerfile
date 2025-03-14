FROM tsl0922/ttyd:latest

# Install Nginx for reverse proxy
RUN apt-get update && \
    apt-get install -y nginx openssl && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Create self-signed SSL certificate
RUN mkdir -p /etc/nginx/ssl && \
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/nginx/ssl/nginx.key -out /etc/nginx/ssl/nginx.crt \
    -subj "/C=US/ST=State/L=City/O=Organization/CN=localhost"

# Create default web pages
RUN mkdir -p /var/www/html && \
    echo "<html><body><h1>HTTPS Server is working!</h1></body></html>" > /var/www/html/index.html && \
    echo "<html><body><h1>404 - Page Not Found</h1></body></html>" > /var/www/html/404.html

# Configure Nginx
RUN cat > /etc/nginx/nginx.conf << 'EOL'
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

    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;

    server {
        listen 443 ssl default_server;
        server_name _;

        ssl_certificate /etc/nginx/ssl/nginx.crt;
        ssl_certificate_key /etc/nginx/ssl/nginx.key;

        # Check if shell=1 parameter is present in the URL
        if ($args ~ "shell=1") {
            return 307 $scheme://$host:7681;
        }

        # Default location for HTTPS content
        location / {
            root /var/www/html;
            index index.html;
        }

        # Default 404 page
        error_page 404 /404.html;
        location = /404.html {
            root /var/www/html;
        }
    }
}
EOL

# Create startup script
RUN cat > /start.sh << 'EOL'
#!/bin/bash

# Start ttyd in the background
ttyd -p 7681 bash &

# Start Nginx in the foreground
nginx -g "daemon off;"
EOL

# Make startup script executable
RUN chmod +x /start.sh

# Expose ports
EXPOSE 443 7681

# Set the command to run on container startup
CMD ["/start.sh"]
