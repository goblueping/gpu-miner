FROM ubuntu:18.04

USER root

RUN apt-get update && \
    apt-get install -y --no-install-recommends gnupg2 apt-utils autoconf \
    automake build-essential curl wget git python3 python3-dev python3-pip python3-wheel \
    python3-numpy ca-certificates golang nano cmake libboost-all-dev libtool locales pkg-config unzip && \
    rm -rf /var/lib/apt/lists/*

RUN apt-key adv --fetch-keys http://developer.download.nvidia.com/compute/cuda/repos/ubuntu1804/x86_64/7fa2af80.pub && \
    sh -c 'echo "deb http://developer.download.nvidia.com/compute/cuda/repos/ubuntu1804/x86_64 /" > /etc/apt/sources.list.d/cuda.list' && \
    apt-get update && \
    apt-get install -y cuda-toolkit-11-0 && \
    rm -rf /var/lib/apt/lists/*

ENV BUILD_DIR=/tmp/gpu_build

# build grpc
RUN mkdir -p $BUILD_DIR && cd $BUILD_DIR && git clone --depth 1 -b v1.24.2 https://github.com/grpc/grpc && \
    cd grpc && git submodule update --init --recursive && \
    rm -rf .git && \
    cd $BUILD_DIR/grpc && mkdir -p build && cd build && cmake .. && \
    make grpc++_reflection grpc++_unsecure grpc grpc++ grpc_cronet grpc_plugin_support grpcpp_channelz gpr -j $(nproc)

RUN cd $BUILD_DIR && \
    git clone --depth 1 https://github.com/trick77/bcnode-gpu-docker.git && \
    git clone --depth 1 https://github.com/trick77/bc-src.git -b cuda-miner

ENV PATH=${BUILD_DIR}/grpc/build:${BUILD_DIR}/grpc/build/third_party/protobuf:/usr/local/cuda/bin:$PATH

COPY overline_cuda_miner_makerfile ${BUILD_DIR}/bc-src/cuda-miner/Makefile

RUN cd $BUILD_DIR/bc-src/cuda-miner/src && \
    make -f ../Makefile && cp miner $BUILD_DIR/
