#!/usr/bin/env bash
set -euo pipefail

if [ $# -eq 0 ]
  then
    echo -e "Error: No arguments supplied".
    echo -e "Usage: $0 /path/to/bcnode-db-2029-11-12_13-14-15.tar.gz"
    echo -e "       $0 /path/to/_easysync_db.zip"
    exit 1
fi

database_location=$1
bcnode_container_name=bcnode
database_volume_name=db

if [ ! -f "${database_location}" ]; then
  echo -e "Error: Missing import file ${database_location}"
  exit 1
fi

echo -e "Preparing to import the blockchain database from ${database_location}..."
docker rm -f importdb > /dev/null 2>&1 || true

read -p "This will stop the container if ${bcnode_container_name} is currently running. Are you sure? " -n 1 -r
echo    # (optional) move to a new line
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    echo -e "This was a close call man!"
    exit 1
fi

if [ -f "./overline_gpu_miner" ]; then
    ./overline_gpu_miner stop
else
  echo -e "Stopping current ${bcnode_container_name} container if running..."
  docker rm -f ${bcnode_container_name} > /dev/null 2>&1 || true
fi

existing_volume=$(docker volume ls -q -f name=${database_volume_name} | grep -w ${database_volume_name}) || true
if [ -z ${existing_volume} ]; then
  echo -e "Warning: No named Docker volume \"${database_volume_name}\" found, creating it..."
  echo -e "Make sure it's going to be attached to the ${bcnode_container_name} container!"
  docker volume create ${database_volume_name}
else
  read -p "This will delete the local blockchain copy in Docker volume ${database_volume_name}. Are you sure? " -n 1 -r
  echo    # (optional) move to a new line
  if [[ ! $REPLY =~ ^[Yy]$ ]]
  then
      echo -e "This was a close call man!"
      exit 1
  fi
  docker volume rm ${database_volume_name}
fi

echo -e "Starting dummy container to access ${database_volume_name} volume..."
docker run -d --rm --name importdb -v ${database_volume_name}:/root alpine tail -f /dev/null

tmp_dir=`mktemp -d`
echo -e "Extracting database $1 to ${tmp_dir}"
if [ ${1: -3} == ".gz" ]; then
  tar -xf $1 -C ${tmp_dir}
else
  if [ ${1: -4} == ".zip" ]; then
    unzip $1 -d ${tmp_dir}
  fi
fi
rm ${tmp_dir}/_data/db/IDENTITY > /dev/null 2>&1 || true
rm ${tmp_dir}/_data/.chainstate.db > /dev/null 2>&1 || true

echo -e "Latest database timestamp:"
ls -Artls ${tmp_dir}/_data/db/*.sst | tail -n 1

echo -e "Copying database to volume..."
docker cp ${tmp_dir}/_data/* importdb:/root

echo -e "Cleaning up..."
docker rm -f importdb > /dev/null 2>&1
rm -rf ${tmp_dir}

echo -e "Done."
