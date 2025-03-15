FROM tsl0922/ttyd:latest

# Install curl for downloading the remote script
RUN apt-get update && \
    apt-get install -y curl && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Create the /app directory
RUN mkdir -p /app

# Download the start.sh script at build time
RUN curl -s https://raw.githubusercontent.com/cloudv2077/docker_railway/refs/heads/main/start.sh -o /start.sh && \
    chmod +x /start.sh

# Only expose port 7681
EXPOSE 7681

# Set the command to run on container startup
CMD ["/start.sh"]
