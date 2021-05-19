#!/usr/bin/env bash
set -euo pipefail

NC='\033[0m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'

if [ $# -eq 0 ]
  then
    echo -e "${RED}Error: No arguments supplied".
    echo -e "Usage: $0 /path/to/bcnode-db-2029-11-12_13-14-15.tar.gz"
    echo -e "       $0 /path/to/_easysync_db.zip${NC}"
    exit 1
fi

database_location=$1
bcnode_container_name=bcnode
database_volume_name=db

if [ ! -f "${database_location}" ]; then
  echo -e "${RED}Error: Missing import file ${database_location}${NC}"
  exit 1
fi

echo -e "${GREEN}Preparing to import the blockchain database from ${database_location}...${NC}"
docker rm -f importdb > /dev/null 2>&1 || true

read -p "This will stop the container if ${bcnode_container_name} is currently running. Are you sure? " -n 1 -r
echo    # (optional) move to a new line
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    echo -e "${GREEN}This was a close call man!${NC}"
    exit 1
fi

if [ -f "./cli.sh" ]; then
    ./cli.sh clean
else
  echo -e "${GREEN}Stopping current ${bcnode_container_name} container if running...${NC}"
  docker rm -f ${bcnode_container_name} > /dev/null 2>&1 || true
fi

existing_volume=$(docker volume ls -q -f name=${database_volume_name} | grep -w ${database_volume_name}) || true
if [ -z ${existing_volume} ]; then
  echo -e "${YELLOW}Warning: No named Docker volume \"${database_volume_name}\" found, creating it..."
  echo -e "Make sure it's going to be attached to the ${bcnode_container_name} container!${NC}"
  docker volume create ${database_volume_name}
else
  read -p "This will delete the local blockchain copy in Docker volume ${database_volume_name}. Are you sure? " -n 1 -r
  echo    # (optional) move to a new line
  if [[ ! $REPLY =~ ^[Yy]$ ]]
  then
      echo -e "${GREEN}This was a close call man!${NC}"
      exit 1
  fi
  docker volume rm ${database_volume_name}
fi

echo -e "${GREEN}Starting dummy container to access ${database_volume_name} volume...${NC}"
docker run -d --rm --name importdb -v ${database_volume_name}:/root alpine tail -f /dev/null

tmp_dir=`mktemp -d`
echo -e "${GREEN}Extracting database $1 to ${tmp_dir}${NC}"
if [ ${1: -3} == ".gz" ]; then
  tar -xf $1 -C ${tmp_dir}
else
  if [ ${1: -4} == ".zip" ]; then
    unzip $1 -d ${tmp_dir}
  fi
fi
rm ${tmp_dir}/_data/db/IDENTITY > /dev/null 2>&1 || true
rm ${tmp_dir}/_data/.chainstate.db > /dev/null 2>&1 || true

echo -e "${GREEN}Latest database timestamp:"
ls -Artls ${tmp_dir}/_data/db/*.sst | tail -n 1

echo -e "${GREEN}Copying database to volume...${NC}"
docker cp ${tmp_dir}/_data/* importdb:/root

echo -e "${GREEN}Cleaning up...${NC}"
docker rm -f importdb > /dev/null 2>&1
rm -rf ${tmp_dir}

echo -e "${GREEN}Done."
