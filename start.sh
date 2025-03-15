#!/bin/bash
pwd
pwd
pwd
pwd

# 更新包列表
apt-get update

# 安装系统工具
apt-get install -y net-tools wget

# 下载并安装指定版本的Miniconda (Python 3.12)
wget https://repo.anaconda.com/miniconda/Miniconda3-py312_25.1.1-2-Linux-x86_64.sh
bash Miniconda3-py312_25.1.1-2-Linux-x86_64.sh -b -p /opt/miniconda3
source /opt/miniconda3/bin/activate

# 安装指定版本的Python依赖
pip install fastapi==0.115.11 uvicorn==0.34.0 pydantic==2.10.3 aiohttp==3.11.13
pip install pydantic_core==2.27.1 typing_extensions==4.12.2 starlette==0.46.1 anyio==4.8.0
pip install sniffio==1.3.1 h11==0.14.0 idna==3.7 multidict==6.1.0 yarl==1.18.3
pip install frozenlist==1.5.0 aiosignal==1.3.2 attrs==25.3.0

# 安装yt-dlp（使用默认版本）
pip install yt-dlp

# 下载应用程序
wget -O app.py https://raw.githubusercontent.com/cloudv2077/docker_railway/refs/heads/main/app.py

# 运行应用程序在8000端口
python app.py

pwd
pwd
pwd
pwd
