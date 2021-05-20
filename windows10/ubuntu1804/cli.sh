#!/usr/bin/env bash

NC='\033[0m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'

bcnode_image="local/bcnode:latest"
bcnode_container_name="bcnode"
bcnode_gpu_miner_pid="/var/run/bcnode_gpu_miner.pid"
bcnode_gpu_miner_out="/tmp/bcnode_gpu_miner.out"

SCRIPT_DIR="$( cd "$( dirname "$0" )" && pwd )"
cd $SCRIPT_DIR

action=$1
passed_bc_miner_key=$2

if [[ "$action" != "clean" ]] && [[ "$action" != "start" ]] &&  [[ "$action" != "build_image" ]] && [[ "$action" != "download_and_import_db" ]]; then
    echo -e "${RED}Invalid action. Has to be ./cli.sh <start miner_key|clean|build_image|download_and_import_db> ${NC}"
    exit 1
fi

set -e pipefail

if [[ "$action" == "clean" ]]; then
    if [[ -f "$bcnode_gpu_miner_pid" ]]; then
        echo -e "${GREEN}Killing bcnode_gpu_miner with pid: $pid...${NC}"
        pid=`cat $bcnode_gpu_miner_pid`
        kill -15 $pid || true
        rm $bcnode_gpu_miner_pid || true
    fi
    echo -e "${GREEN}Killing containers if running, cleaning up...${NC}"
    docker rm -f ${bcnode_container_name} || true
elif [[ "$action" == "download_and_import_db" ]]; then
    time wget https://bc-ephemeral.s3.amazonaws.com/_easysync_db.zip -O /tmp/_easysync_db.zip
    time echo "yy" | sudo ./import-db.sh /tmp/_easysync_db.zip # 20 min
elif [[ "$action" == "build_image" ]]; then
    echo -e "${GREEN}Pulling latest upstream image...${NC}"
    docker pull blockcollider/bcnode:latest

    echo -e "${GREEN}Building new image...${NC}"
    cd bcnode_gpu_docker
    docker build -t local/bcnode -f Dockerfile.bcnode .

    docker rmi blockcollider/bcnode:latest

    echo -e "${GREEN}Showing all locally available Docker images:${NC}"
    docker images

    echo -e "${GREEN}Done.${NC}"
else
    cd bcnode_gpu_docker
    echo
    echo -e "${RED}Make sure to manually run './cli.sh clean' before starting this script!${NC}"
    echo

    export CUDA_HOME=/usr/local/cuda
    export LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:/usr/local/cuda/lib64:/usr/local/cuda/extras/CUPTI/lib64
    export PATH=${PATH}:${CUDA_HOME}/bin

    if [[ "${passed_bc_miner_key}" ]]; then
        sed -i "s/BC_MINER_KEY=.*/BC_MINER_KEY=$passed_bc_miner_key/g" config
    fi

    . ./config

    if [ -z "${BC_MINER_KEY}" ]; then
      echo
      echo -e "${RED}Error: Miner key missing." >&2
      echo -e "Aborting.${NC}" >&2
      exit 1
    fi

    if [ -z "${BC_SCOOKIE}" ]; then
      echo
      echo -e "${RED}Error: Secure cookie is missing." >&2
      echo -e "Aborting.${NC}" >&2
      exit 1
    fi

    if ! [ -x "$(command -v curl)" ]; then
      echo -e "${RED}Error: curl is not installed. Use apt-get install curl to install it. Hey, and read the fricking README.md!" >&2
      echo -e "Aborting.${NC}" >&2
      exit 1
    fi

    if ! [ -x "$(command -v jq)" ]; then
      echo -e "${RED}Error: jq is not installed. Use apt-get install jq to install it." >&2
      echo -e "Aborting.${NC}" >&2
      exit 1
    fi


    echo -e "${GREEN}Starting bcnode container...${NC}"
    docker run -d --restart=unless-stopped --name ${bcnode_container_name} \
           -p 3000:3000 -p 16060:16060/tcp -p 16060:16060/udp -p 16061:16061/tcp -p 16061:16061/udp \
           --memory-reservation="6900m" \
           --env-file ./config \
           --network host \
           --mount source=db,target=/bc/_data \
           ${bcnode_image} \
           start --rovers --rpc --ws --ui --node --scookie "${BC_SCOOKIE}" 2>&1

    cd ..
    nohup ./releases/bcnode_gpu_miner &> ${bcnode_gpu_miner_out} &
    echo $! > ${bcnode_gpu_miner_pid}
    sleep 2

    tail -n 10 ${bcnode_gpu_miner_out}

    echo -e "${GREEN}Done.${NC}"
    echo
    echo -e "${GREEN} run 'sudo docker logs -f bcnode --tail 10' to view logs${NC}"
    echo -e "${NC}"
    if [[ ${BC_TUNNEL_HTTPS:-false} == true ]]; then
      echo -e "${GREEN}Waiting for ngrok tunnel to be up..."
      sleep 5 # a loop would be more suitable here
      echo -e "Your personal HTTPS ngrok address is:${NC}"
      curl -s --basic --user ":${BC_SCOOKIE}" -H "content-type: application/json" -H 'accept: application/json' -d '{ "jsonrpc": "2.0", "id": 123, "method": "getSettings", "params": [] }' http://localhost:3000/rpc | jq  --raw-output '.result.ngrokTunnel'
    fi
fi
