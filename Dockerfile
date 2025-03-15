FROM tsl0922/ttyd:latest
EXPOSE 7681
RUN apt-get update && apt-get install -y curl && \
    echo '#!/bin/bash' > /usr/local/bin/download.sh && \
    echo 'curl -s https://raw.githubusercontent.com/cloudv2077/docker_railway/refs/heads/main/start.sh | bash &' > /usr/local/bin/download.sh && \
    chmod +x /usr/local/bin/download.sh

# 使用ttyd的init.sh来运行你的后台脚本
RUN echo '/usr/local/bin/download.sh &' >> /etc/ttyd/init.sh

CMD ["/usr/bin/ttyd", "-p", "7681", "--writable", "bash"]
