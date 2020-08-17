# Dockerfile for CentOS 8 toolchain builds
FROM centos:centos8

LABEL maintainer simon.cook@embecosm.com

RUN dnf -y upgrade && dnf -y groupinstall 'Development tools' && \
    dnf config-manager --set-enabled PowerTools && \
    dnf -y install dejagnu python3 texinfo wget which expat-devel zlib-devel

# Install cmake 3.17
RUN mkdir -p /tmp/cmake && cd /tmp/cmake && \
    wget https://github.com/Kitware/CMake/releases/download/v3.17.3/cmake-3.17.3.tar.gz && \
    tar xf cmake-3.17.3.tar.gz && cd cmake-3.17.3 && \
    ./bootstrap --parallel=$(nproc) -- -DCMAKE_USE_OPENSSL=OFF && \
    make -j$(nproc) && make install && \
    cd /tmp && rm -rf cmake
