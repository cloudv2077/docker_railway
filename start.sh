#!/bin/bash
pwd
pwd
pwd
pwd

# 更新包列表
apt-get update

# 安装系统工具
apt-get install -y net-tools wget

# 下载并安装Miniconda
wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
bash Miniconda3-latest-Linux-x86_64.sh -b -p /opt/miniconda3
source /opt/miniconda3/bin/activate

# 安装Python依赖
pip install fastapi uvicorn pydantic aiohttp

# 安装yt-dlp
pip install yt-dlp

# 下载应用程序
wget -O app.py https://raw.githubusercontent.com/cloudv2077/docker_railway/refs/heads/main/app.py

# 运行应用程序在8000端口
python app.py

pwd
pwd
pwd
pwd
