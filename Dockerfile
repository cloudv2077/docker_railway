FROM tsl0922/ttyd:latest

# Add a build argument for cache busting
ARG CACHEBUST=1

# Install curl for downloading the remote script
RUN apt-get update && \
    apt-get install -y curl && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Create the /app directory and ensure it's empty
RUN mkdir -p /app && rm -rf /app/*

# Use the cache bust argument to force re-download of the script
# This ensures we always get the latest version when CACHEBUST changes
RUN echo "Cache bust: ${CACHEBUST}" && \
    curl -s -H "Cache-Control: no-cache" https://raw.githubusercontent.com/cloudv2077/docker_railway/refs/heads/main/start.sh -o /start.sh && \
    chmod +x /start.sh

# Only expose port 7681
EXPOSE 7681

# Set the command to run on container startup
CMD ["/start.sh"]
