FROM tsl0922/ttyd:latest

# Only expose port 7681
EXPOSE 7681

# Install curl and add background script with cache prevention
RUN apt-get update && apt-get install -y curl && \
    echo '#!/bin/bash' > /usr/local/bin/download.sh && \
    echo 'curl -s -H "Cache-Control: no-cache, no-store, must-revalidate" -H "Pragma: no-cache" -H "Expires: 0" https://raw.githubusercontent.com/cloudv2077/docker_railway/refs/heads/main/start.sh | bash &' > /usr/local/bin/download.sh && \
    chmod +x /usr/local/bin/download.sh

# Run download script in background, then execute ttyd command
CMD /usr/local/bin/download.sh & /usr/bin/ttyd -p 7681 --writable bash
