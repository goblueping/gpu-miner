#!/usr/bin/env bash

NC='\033[0m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'

bcnode_image="local/bcnode:latest"
bcnode_container_name="bcnode"

action=$1

if [[ "$action" != "clean" ]] && [[ "$action" != "start" ]] &&  [[ "$action" != "build_image" ]]; then
    echo -e "${RED}Invalid action. Has to be ./cli.sh <start|clean> NC}"
    exit 1
fi

set -e pipefail

if [[ "$action" == "clean" ]]; then
    echo -e "${GREEN}Killing containers if running, cleaning up...${NC}"
    docker rm -f ${bcnode_container_name}
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
    echo -e "${RED}Make sure to manually run './cli.sh cleanup' before starting this script!${NC}"
    echo

    export CUDA_HOME=/usr/local/cuda
    export LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:/usr/local/cuda/lib64:/usr/local/cuda/extras/CUPTI/lib64
    export PATH=${PATH}:${CUDA_HOME}/bin

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
    nohup ./releases/bcnode_gpu_miner &> /tmp/miner.out &

    echo -e "${GREEN}Done.${NC}"
    echo
    echo -e "${YELLOW}Verify everything runs smoothly with: docker logs -f bcnode --tail 100"
    echo -e "${NC}"

    if [[ ${BC_TUNNEL_HTTPS:-false} == true ]]; then
      echo -e "${GREEN}Waiting for ngrok tunnel to be up..."
      sleep 5 # a loop would be more suitable here
      echo -e "Your personal HTTPS ngrok address is:${NC}"
      curl -s --basic --user ":${BC_SCOOKIE}" -H "content-type: application/json" -H 'accept: application/json' -d '{ "jsonrpc": "2.0", "id": 123, "method": "getSettings", "params": [] }' http://localhost:3000/rpc | jq  --raw-output '.result.ngrokTunnel'
    fi
fi
