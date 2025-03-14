#!/bin/bash

# 安装必要的工具
apt-get update && apt-get install -y nginx

# 创建 Nginx 配置文件
cat > /etc/nginx/nginx.conf << 'EOF'
events {
    worker_connections 1024;
}

http {
    server {
        listen 80;
        
        location / {
            if ($args ~ "shell=1") {
                proxy_pass http://127.0.0.1:7681;
                proxy_http_version 1.1;
                proxy_set_header Upgrade $http_upgrade;
                proxy_set_header Connection "upgrade";
                proxy_set_header Host $host;
                proxy_read_timeout 86400;
            }
            
            # 如果不是 shell=1，可以返回其他内容
            return 200 "Welcome to the service. Add ?shell=1 to access the terminal.";
        }
    }
}
EOF

# 创建启动脚本
cat > /usr/local/bin/start-service.sh << 'EOF'
#!/bin/bash

# 启动 ttyd
/usr/bin/ttyd -p 7681 bash &

# 启动 Nginx
nginx -g 'daemon off;'
EOF

chmod +x /usr/local/bin/start-service.sh

# 替换默认的 CMD 命令
echo '#!/bin/bash' > /.dockerenv.sh
echo 'exec /usr/local/bin/start-service.sh' >> /.dockerenv.sh
chmod +x /.dockerenv.sh

echo "Setup complete. The service will now use Nginx to route traffic."
