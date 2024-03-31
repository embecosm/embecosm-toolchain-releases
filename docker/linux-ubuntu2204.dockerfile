# Dockerfile for Ubuntu 22.04 builds
FROM ubuntu:22.04

LABEL maintainer simon.cook@embecosm.com

RUN apt-get -y update && \
    DEBIAN_FRONTEND=noninteractive \
    apt-get install -y flex bison build-essential dejagnu git python-is-python3 python3 python3-distutils texinfo wget libexpat-dev rsync file \
    gawk zlib1g-dev ninja-build pkg-config libglib2.0-dev python3-venv

# Install cmake 3.26.4
RUN mkdir -p /tmp/cmake && cd /tmp/cmake && \
    wget https://github.com/Kitware/CMake/releases/download/v3.26.4/cmake-3.26.4.tar.gz && \
    tar xf cmake-3.26.4.tar.gz && cd cmake-3.26.4 && \
    ./bootstrap --parallel=$(nproc) -- -DCMAKE_USE_OPENSSL=OFF && \
    make -j$(nproc) && make install && \
    cd /tmp && rm -rf cmake

# Create a user which matches the uid of the buildbot user.
# This is needed:
#   1. For some tests, which require a real user and real home directory
#   2. For running rustup to install a rust toolchain for gccrs
# Note UID 1002 matches the Embecosm Buildbot environment, but may need changing
# to run in other contexts.
RUN useradd -m -u 1002 builder
RUN wget -O /tmp/rustup.sh https://sh.rustup.rs && chmod +x /tmp/rustup.sh && \
    su builder -c '/tmp/rustup.sh -y --default-toolchain=1.72.0'
ENV PATH="/home/builder/.cargo/bin:${PATH}"
