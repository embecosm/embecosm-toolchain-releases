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

# Some tests require the user running testing to exist and have a home directory
# These values match what the Embecosm Buildbot builders are set up to use
RUN useradd -m -u 1002 builder
