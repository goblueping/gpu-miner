

### Build GPU miner binary

```
# build the docker image
docker build -t overline-gpu-miner:0.0.1 .

# COPY the miner binary out

docker run -d --rm --name gpu-miner-tmp overline-gpu-miner:0.0.1 sleep 30

docker cp gpu-miner-tmp:/tmp/gpu_build/miner /tmp/miner
```

