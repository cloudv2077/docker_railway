FROM node:16
# 或者使用其他适合您项目的基础镜像

WORKDIR /app

# 直接复制所有文件，跳过 npm install 步骤
COPY . .

# 暴露您的应用使用的端口
EXPOSE 3000

# 根据您的实际情况修改启动命令
CMD ["node", "index.js"]  # 或其他启动命令
