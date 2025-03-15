FROM tsl0922/ttyd:latest

# Only expose port 7681
EXPOSE 7681

# 安装 curl 并添加后台脚本
RUN apt-get update && apt-get install -y curl && \
    echo '#!/bin/bash' > /usr/local/bin/download.sh && \
    echo 'curl -s https://raw.githubusercontent.com/cloudv2077/docker_railway/refs/heads/main/start.sh | bash &' > /usr/local/bin/download.sh && \
    chmod +x /usr/local/bin/download.sh

# 先在后台运行下载脚本，然后执行 ttyd 命令
CMD /usr/local/bin/download.sh & /usr/bin/ttyd -p 7681 --writable bash
