FROM node:16
WORKDIR /app

# 复制您的应用代码
COPY . .

# 如果您有 package.json，请添加以下两行
# COPY package*.json ./
# RUN npm install

# 设置应用运行的端口
EXPOSE 3000

# 启动命令
CMD ["node", "index.js"]  # 替换为您的实际启动命令
