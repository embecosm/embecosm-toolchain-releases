# Dockerfile for Ubuntu 24.04 builds
FROM ubuntu:24.04

LABEL maintainer simon.cook@embecosm.com

RUN apt-get -y update && \
    DEBIAN_FRONTEND=noninteractive \
    apt-get install -y flex bison build-essential dejagnu git python-is-python3 python3 texinfo wget libexpat-dev rsync file \
    gawk zlib1g-dev ninja-build pkg-config libglib2.0-dev python3-venv cmake

# Install fixed version of DejaGNU for more reliable test summary generation
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
