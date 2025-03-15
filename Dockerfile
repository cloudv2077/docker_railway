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
COPY package.json /app/
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

# Create the server.js file
COPY server.js /app/

# Create startup script that launches both ttyd and your Node.js server
COPY start.sh /
RUN chmod +x /start.sh

# Expose ports
EXPOSE 80 443 7681

# Set the command to run on container startup
ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["/start.sh"]
