#!/usr/bin/env bash

set -e

NC='\033[0m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'

function install_docker {
    sudo usermod -aG docker $USER
    if [[ $(which docker) && $(docker --version) ]]; then
        echo "docker is already installed"
    else
        echo -e "${GREEN}Installing docker ...${NC}"
        curl https://get.docker.com | sh
        sudo service docker stop || sudo service docker start
    fi
}

function clone_gpu_miner_repo {
    cd ~/
    if [ ! -d "gpu-miner" ]; then
        echo -e "${GREEN}Cloning gpu-miner repo to ~/ ...${NC}"
        git clone --depth 1 https://github.com/goblueping/gpu-miner.git
    else
        echo -e "${GREEN}Pulling the latest repo ~/ ...${NC}"
        cd gpu-miner; git checkout . || git checkout main || git pull origin main
    fi
}

function build_image {
    echo -e "${GREEN}Building docker images ...${NC}"
    cd ~/gpu-miner/windows10/ubuntu1804/
    sudo ./cli.sh build_image
}

function seed_snapshot {
    cd ~/gpu-miner/windows10/ubuntu1804/
    echo -e "${GREEN}Downloading the db snapshot ...${NC}"
    time wget https://bc-ephemeral.s3.amazonaws.com/_easysync_db.zip -O /tmp/_easysync_db.zip
    time echo "yy" | sudo ./import-db.sh /tmp/_easysync_db.zip
}


function install_cuda {
    sudo apt-key adv --fetch-keys http://developer.download.nvidia.com/compute/cuda/repos/ubuntu1804/x86_64/7fa2af80.pub
    sudo sh -c 'echo "deb http://developer.download.nvidia.com/compute/cuda/repos/ubuntu1804/x86_64 /" > /etc/apt/sources.list.d/cuda.list'
    sudo apt-get update
    echo -e "${GREEN}Installing cuda-toolkit ...${NC}"
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y cuda-toolkit-11-0 unzip wget curl jq
}

sudo bash -c "echo '$USER     ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers"

install_cuda
install_docker
clone_gpu_miner_repo
build_image
seed_snapshot

echo -e "${GREEN}Done.${NC}"
