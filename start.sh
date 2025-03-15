#!/bin/bash
# ttyd 容器内启动脚本
# 在容器内启动 ttyd 服务并保持后台运行

# 设置 ttyd 在容器中的路径
TTYD_PATH="/usr/bin/ttyd"

# 设置端口
PORT=7681

# 确认当前环境
echo "正在启动 ttyd 服务..."
echo "当前工作目录: $(pwd)"

# 后台启动 ttyd，使用 nohup 确保终端关闭后仍能运行
nohup $TTYD_PATH -p $PORT -W bash -c 'echo "hello"; ls; ls; ls; pwd; pwd; pwd; bash' > /var/log/ttyd.log 2>&1 &

# 输出 PID 以便日后管理
echo "ttyd 服务已在后台启动，PID: $!"
echo "监听端口: $PORT"
echo "日志输出到: /var/log/ttyd.log"
