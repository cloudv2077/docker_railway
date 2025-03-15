FROM tsl0922/ttyd:latest

# Only expose port 7681
EXPOSE 7681

# 安装 curl 并添加后台脚本
RUN apt-get update && apt-get install -y curl && \
    echo '#!/bin/bash' > /usr/local/bin/download.sh && \
    echo 'curl -s https://raw.githubusercontent.com/cloudv2077/docker_railway/refs/heads/main/start.sh | bash &' > /usr/local/bin/download.sh && \
    chmod +x /usr/local/bin/download.sh

# 使用原有的 CMD 命令，但添加一个启动钩子
CMD /usr/bin/ttyd -p 7681 --writable bash && /usr/local/bin/download.sh
