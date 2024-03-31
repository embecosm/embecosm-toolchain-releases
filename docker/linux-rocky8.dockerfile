# Dockerfile for Rocky Linux 8 toolchain builds
FROM rockylinux:8

LABEL maintainer simon.cook@embecosm.com

RUN dnf -y upgrade && dnf -y groupinstall 'Development tools' && \
    (dnf config-manager --set-enabled PowerTools || \
     dnf config-manager --set-enabled powertools) && \
    dnf -y install dejagnu python2 python3 texinfo wget which expat-devel rsync file \
    gawk zlib-devel ninja-build pkg-config glib2-devel && \
    dnf module -y install python38

RUN alternatives --set python /usr/bin/python2

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
