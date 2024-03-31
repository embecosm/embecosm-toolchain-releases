# Dockerfile for CentOS 7 toolchain builds
FROM centos:centos7

LABEL maintainer simon.cook@embecosm.com

RUN yum -y upgrade && yum -y groupinstall 'Development tools' && \
    yum -y install dejagnu python3 texinfo wget which expat-devel rsync file \
    gawk zlib-devel glib2-devel

# Install newer toolchain components
RUN yum install -y centos-release-scl && yum install -y devtoolset-8 rh-python38

ENV PATH="/opt/rh/rh-python38/root/usr/local/bin:/opt/rh/rh-python38/root/usr/bin:/opt/rh/devtoolset-8/root/usr/bin:${PATH}" \
    LD_LIBRARY_PATH="/opt/rh/rh-python38/root/usr/lib64:/opt/rh/devtoolset-8/root/usr/lib64:/opt/rh/devtoolset-8/root/usr/lib:/opt/rh/devtoolset-8/root/usr/lib64/dyninst:/opt/rh/devtoolset-8/root/usr/lib/dyninst:/opt/rh/devtoolset-8/root/usr/lib64:/opt/rh/devtoolset-8/root/usr/lib"

# Use the newly installed pip to get ninja
RUN python -m pip install ninja

# Install cmake 3.26.4
RUN mkdir -p /tmp/cmake && cd /tmp/cmake && \
    wget https://github.com/Kitware/CMake/releases/download/v3.26.4/cmake-3.26.4.tar.gz && \
    tar xf cmake-3.26.4.tar.gz && cd cmake-3.26.4 && \
    ./bootstrap --parallel=$(nproc) -- -DCMAKE_USE_OPENSSL=OFF && \
    make -j$(nproc) && make install && \
    cd /tmp && rm -rf cmake

# Install new DejaGNU for more reliable test summary generation
RUN mkdir -p /tmp/dejagnu && cd /tmp/dejagnu && \
    wget https://ftp.gnu.org/gnu/dejagnu/dejagnu-1.6.2.tar.gz && \
    tar xf dejagnu-1.6.2.tar.gz && cd dejagnu-1.6.2 && \
    ./configure && make && make install && \
    cd /tmp && rm -rf dejagnu

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
