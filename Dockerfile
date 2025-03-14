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

# Configure Nginx - all in one line to avoid Dockerfile parsing errors
RUN echo 'user www-data;\nworker_processes auto;\npid /run/nginx.pid;\n\nevents {\n    worker_connections 768;\n}\n\nhttp {\n    sendfile on;\n    tcp_nopush on;\n    tcp_nodelay on;\n    keepalive_timeout 65;\n    types_hash_max_size 2048;\n\n    include /etc/nginx/mime.types;\n    default_type application/octet-stream;\n\n    ssl_protocols TLSv1.2 TLSv1.3;\n    ssl_prefer_server_ciphers on;\n    ssl_ciphers "EECDH+AESGCM:EDH+AESGCM:AES256+EECDH:AES256+EDH";\n\n    access_log /var/log/nginx/access.log;\n    error_log /var/log/nginx/error.log;\n\n    server {\n        listen 443 ssl default_server;\n        server_name _;\n\n        ssl_certificate /etc/nginx/ssl/nginx.crt;\n        ssl_certificate_key /etc/nginx/ssl/nginx.key;\n\n        # Check if shell=1 parameter is present in the URL\n        if ($args ~ "shell=1") {\n            return 307 $scheme://$host:7681;\n        }\n\n        # Default location for HTTPS content\n        location / {\n            root /var/www/html;\n            index index.html;\n        }\n\n        # Default 404 page\n        error_page 404 /404.html;\n        location = /404.html {\n            root /var/www/html;\n        }\n    }\n}' > /etc/nginx/nginx.conf

# Create startup script - all in one line to avoid Dockerfile parsing errors
RUN echo '#!/bin/bash\n\n# Start ttyd in the background\nttyd -p 7681 bash &\n\n# Start Nginx in the foreground\nnginx -g "daemon off;"' > /start.sh

# Make startup script executable
RUN chmod +x /start.sh

# Expose ports
EXPOSE 443 7681

# Set the command to run on container startup
CMD ["/start.sh"]
