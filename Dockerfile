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
    echo "<html><body><h1>Web Server is working!</h1></body></html>" > /var/www/html/index.html && \
    echo "<html><body><h1>404 - Page Not Found</h1></body></html>" > /var/www/html/404.html

# Configure Nginx with proper location blocks
RUN echo 'user www-data;\nworker_processes auto;\npid /run/nginx.pid;\n\nevents {\n    worker_connections 768;\n}\n\nhttp {\n    sendfile on;\n    tcp_nopush on;\n    tcp_nodelay on;\n    keepalive_timeout 65;\n    types_hash_max_size 2048;\n\n    include /etc/nginx/mime.types;\n    default_type application/octet-stream;\n\n    ssl_protocols TLSv1.2 TLSv1.3;\n    ssl_prefer_server_ciphers on;\n    ssl_ciphers "EECDH+AESGCM:EDH+AESGCM:AES256+EECDH:AES256+EDH";\n\n    map $args $is_shell {\n        default 0;\n        ~*shell=1 1;\n    }\n\n    access_log /var/log/nginx/access.log;\n    error_log /var/log/nginx/error.log;\n\n    # HTTP Server\n    server {\n        listen 80 default_server;\n        server_name _;\n\n        # Proxy to ttyd for shell=1 requests\n        location / {\n            # Use map variable for conditional processing\n            if ($is_shell = 1) {\n                rewrite ^(.*)$ /ttyd last;\n            }\n            \n            # Default content\n            root /var/www/html;\n            index index.html;\n        }\n\n        # Dedicated location for ttyd proxy\n        location /ttyd {\n            proxy_pass http://127.0.0.1:7681;\n            proxy_http_version 1.1;\n            proxy_set_header Upgrade $http_upgrade;\n            proxy_set_header Connection "upgrade";\n            proxy_set_header Host $host;\n            proxy_read_timeout 1800s;\n            proxy_send_timeout 1800s;\n            proxy_buffering off;\n        }\n\n        # Default 404 page\n        error_page 404 /404.html;\n        location = /404.html {\n            root /var/www/html;\n        }\n    }\n\n    # HTTPS Server\n    server {\n        listen 443 ssl default_server;\n        server_name _;\n\n        ssl_certificate /etc/nginx/ssl/nginx.crt;\n        ssl_certificate_key /etc/nginx/ssl/nginx.key;\n\n        # Proxy to ttyd for shell=1 requests\n        location / {\n            # Use map variable for conditional processing\n            if ($is_shell = 1) {\n                rewrite ^(.*)$ /ttyd last;\n            }\n            \n            # Default content\n            root /var/www/html;\n            index index.html;\n        }\n\n        # Dedicated location for ttyd proxy\n        location /ttyd {\n            proxy_pass http://127.0.0.1:7681;\n            proxy_http_version 1.1;\n            proxy_set_header Upgrade $http_upgrade;\n            proxy_set_header Connection "upgrade";\n            proxy_set_header Host $host;\n            proxy_read_timeout 1800s;\n            proxy_send_timeout 1800s;\n            proxy_buffering off;\n        }\n\n        # Default 404 page\n        error_page 404 /404.html;\n        location = /404.html {\n            root /var/www/html;\n        }\n    }\n}' > /etc/nginx/nginx.conf

# Create startup script - adding writable option to ttyd
RUN echo '#!/bin/bash\n\n# Start ttyd in the background with writable option\nttyd -p 7681 -w bash &\n\n# Start Nginx in the foreground\nnginx -g "daemon off;"' > /start.sh

# Make startup script executable
RUN chmod +x /start.sh

# Expose ports
EXPOSE 80 443 7681

# Set the command to run on container startup
CMD ["/start.sh"]
