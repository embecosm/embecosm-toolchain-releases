# Dockerfile for Ubuntu 22.04 builds
FROM ubuntu:22.04

LABEL maintainer simon.cook@embecosm.com

RUN apt-get -y update && \
    DEBIAN_FRONTEND=noninteractive \
    apt-get install -y cmake flex bison build-essential dejagnu git python-is-python3 python3 python3-distutils texinfo wget libexpat-dev

# Some tests require the user running testing to exist and have a home directory
# These values match what the Embecosm Buildbot builders are set up to use
RUN useradd -m -u 1002 builder
