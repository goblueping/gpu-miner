#!/usr/bin/env bash

NC='\033[0m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'

sudo bash -c "echo '$USER     ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers"

sudo apt-key adv --fetch-keys http://developer.download.nvidia.com/compute/cuda/repos/ubuntu1804/x86_64/7fa2af80.pub
sudo sh -c 'echo "deb http://developer.download.nvidia.com/compute/cuda/repos/ubuntu1804/x86_64 /" > /etc/apt/sources.list.d/cuda.list'
sudo apt-get update
echo -e "${GREEN}Installing cuda-toolkit ...${NC}"
sudo apt-get install -y cuda-toolkit-11-0 unzip wget curl jq

echo -e "${GREEN}Installing docker ...${NC}"
curl https://get.docker.com | sh
sudo usermod -aG docker $USER
sudo service docker stop
sudo service docker start

echo -e "${GREEN}Cloning gpu-miner repo to ~/ ...${NC}"
cd ~/
git clone --depth 1 https://github.com/goblueping/gpu-miner.git

cd gpu-miner/windows10/ubuntu1804/
sudo ./cli.sh build_image

echo -e "${GREEN}Downloading the db snapshot ...${NC}"
time wget https://bc-ephemeral.s3.amazonaws.com/_easysync_db.zip -O /tmp/_easysync_db.zip
time echo "yy" | sudo ./import-db.sh /tmp/_easysync_db.zip # 20 min

sudo ./cli.sh start

echo -e "${GREEN} run 'sudo docker logs -f bcnode --tail 10' to view logs${NC}"
