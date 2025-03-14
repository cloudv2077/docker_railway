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
COPY nginx.conf /etc/nginx/nginx.conf

# Create startup script with proper delay for ttyd initialization
RUN echo '#!/bin/bash\n\n# Start ttyd in the background with writable option\nttyd -p 7681 -w bash &\nTTYD_PID=$!\n\n# Wait for ttyd to start\necho "Waiting for ttyd to initialize..."\nsleep 3\nif ! kill -0 $TTYD_PID 2>/dev/null; then\n  echo "ttyd failed to start"\n  exit 1\nfi\necho "ttyd started successfully"\n\n# Start Nginx in the foreground\nnginx -g "daemon off;"' > /start.sh

# Make startup script executable
RUN chmod +x /start.sh

# Expose ports
EXPOSE 80 443 7681

# Set the command to run on container startup
CMD ["/start.sh"]
